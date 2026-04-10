import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/chat_message.dart';
import '../models/ws_message.dart';
import 'chat_database.dart';
import 'connection_manager.dart';

class ChatStore {
  static final ChatStore _instance = ChatStore._();
  static ChatStore get instance => _instance;
  ChatStore._() {
    _init();
  }

  // -- Reactive state --
  final _messagesController = StreamController<List<ChatMessage>>.broadcast();
  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;

  final _streamingController = StreamController<bool>.broadcast();
  Stream<bool> get streamingStream => _streamingController.stream;

  // -- Internal state --
  final List<ChatMessage> _messages = [];
  ChatMessage? _streamingMessage;
  bool _isStreaming = false;
  StreamSubscription<WsMessage>? _wsSubscription;

  bool get isStreaming => _isStreaming;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  List<ChatMessage> get displayMessages {
    if (_streamingMessage != null) {
      return [..._messages, _streamingMessage!];
    }
    return List.unmodifiable(_messages);
  }

  void _init() {
    _wsSubscription =
        ConnectionManager.instance.messageStream.listen(_handleWsMessage);
  }

  void _handleWsMessage(WsMessage wsMsg) {
    try {
      switch (wsMsg.event) {
        case WsEvents.streamTextDelta:
          _handleTextDelta(wsMsg.data);
          break;
        case WsEvents.streamToolUseStart:
          _handleToolUseStart(wsMsg.data);
          break;
        case WsEvents.streamDone:
          _handleStreamDone();
          break;
        case WsEvents.streamError:
          _handleStreamError(wsMsg.data);
          break;
        case WsEvents.messageAssistant:
          _handleAssistantMessage(wsMsg.data);
          break;
        case WsEvents.messageUser:
          // Echo of our own message — ignore
          break;
        case WsEvents.sessionMessages:
          _handleSessionMessages(wsMsg.data);
          break;
      }
    } catch (e) {
      // One bad message must not break the stream (T-03-01)
      _notifyListeners();
    }
  }

  void _handleTextDelta(dynamic data) {
    final delta = data is Map ? data['content'] as String? ?? '' : data.toString();
    if (_streamingMessage == null) {
      _streamingMessage = ChatMessage(
        role: MessageRole.assistant,
        content: delta,
        createdAt: DateTime.now(),
        isStreaming: true,
      );
      _isStreaming = true;
    } else {
      _streamingMessage = _streamingMessage!.copyWith(
        content: _streamingMessage!.content + delta,
      );
    }
    _notifyListeners();
  }

  void _handleToolUseStart(dynamic data) {
    // Finalize any in-progress streaming text
    if (_streamingMessage != null) {
      _messages.add(_streamingMessage!.copyWith(isStreaming: false));
      ChatDatabase.instance.insertMessage(_messages.last);
      _streamingMessage = null;
    }

    final toolName = data is Map ? data['name'] as String? : data.toString();
    final toolMsg = ChatMessage(
      role: MessageRole.tool,
      content: toolName ?? 'Unknown',
      toolName: toolName,
      toolStatus: ToolCallStatus.running,
      createdAt: DateTime.now(),
    );
    _messages.add(toolMsg);
    ChatDatabase.instance.insertMessage(toolMsg);
    _notifyListeners();
  }

  void _handleStreamDone() {
    if (_streamingMessage != null) {
      final completed = _streamingMessage!.copyWith(isStreaming: false);
      _messages.add(completed);
      ChatDatabase.instance.insertMessage(completed);
      _streamingMessage = null;
    }
    _isStreaming = false;
    _notifyListeners();
  }

  void _handleStreamError(dynamic data) {
    final errorText =
        data is Map ? data['error'] as String? ?? '' : data.toString();
    if (_streamingMessage != null) {
      final completed = _streamingMessage!.copyWith(
        content: _streamingMessage!.content +
            (errorText.isNotEmpty ? '\n\nError: $errorText' : ''),
        isStreaming: false,
      );
      _messages.add(completed);
      ChatDatabase.instance.insertMessage(completed);
      _streamingMessage = null;
    }
    _isStreaming = false;
    _notifyListeners();
  }

  void _handleAssistantMessage(dynamic data) {
    if (_isStreaming) return; // Ignore if already streaming
    final content =
        data is Map ? data['content'] as String? ?? '' : data.toString();
    if (content.isEmpty) return;
    final msg = ChatMessage(
      role: MessageRole.assistant,
      content: content,
      createdAt: DateTime.now(),
    );
    _messages.add(msg);
    ChatDatabase.instance.insertMessage(msg);
    _notifyListeners();
  }

  void _handleSessionMessages(dynamic data) {
    // Bulk history sync — clear and rebuild from server
    if (data is! List) return;
    _messages.clear();
    _streamingMessage = null;
    _isStreaming = false;
    ChatDatabase.instance.clearAll();
    for (final item in data) {
      if (item is! Map) continue;
      final role = item['role'] == 'user'
          ? MessageRole.user
          : MessageRole.assistant;
      final content = item['content'] as String? ?? '';
      if (content.isEmpty) continue;
      final msg = ChatMessage(
        role: role,
        content: content,
        createdAt: DateTime.now(),
      );
      _messages.add(msg);
      ChatDatabase.instance.insertMessage(msg);
    }
    _notifyListeners();
  }

  /// Send a user message and persist it locally.
  Future<void> sendMessage(String text) async {
    final msg = ChatMessage(
      role: MessageRole.user,
      content: text,
      createdAt: DateTime.now(),
    );
    _messages.add(msg);
    await ChatDatabase.instance.insertMessage(msg);
    ConnectionManager.instance.send(
      WsMessage(event: WsEvents.commandSend, data: {'content': text}),
    );
    _notifyListeners();
  }

  /// Stop the current generation.
  void stopGeneration() {
    ConnectionManager.instance
        .send(WsMessage(event: WsEvents.commandStop));
    if (_streamingMessage != null) {
      final completed = _streamingMessage!.copyWith(isStreaming: false);
      _messages.add(completed);
      ChatDatabase.instance.insertMessage(completed);
      _streamingMessage = null;
    }
    _isStreaming = false;
    _notifyListeners();
  }

  /// Clear the entire session (D-10).
  Future<void> clearSession() async {
    await ChatDatabase.instance.clearAll();
    _messages.clear();
    _streamingMessage = null;
    _isStreaming = false;
    _notifyListeners();
  }

  /// Load last 100 messages from SQLite (D-11).
  Future<void> loadHistory() async {
    _messages.clear();
    _messages.addAll(await ChatDatabase.instance.getMessages(limit: 100));
    _notifyListeners();
  }

  /// Load older messages for infinite scroll (D-11).
  Future<void> loadMoreMessages() async {
    final older = await ChatDatabase.instance.getMessages(
      limit: 100,
      offset: _messages.length,
    );
    if (older.isEmpty) return;
    _messages.insertAll(0, older);
    _notifyListeners();
  }

  void _notifyListeners() {
    if (!_messagesController.isClosed) {
      _messagesController.add(displayMessages);
    }
    if (!_streamingController.isClosed) {
      _streamingController.add(_isStreaming);
    }
  }

  void dispose() {
    _wsSubscription?.cancel();
    _messagesController.close();
    _streamingController.close();
  }
}
