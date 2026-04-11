import 'dart:async';
import 'dart:convert';

import '../models/chat_message.dart';
import '../models/ws_message.dart';
import 'chat_database.dart';
import 'connection_manager.dart';

/// Permission request from the desktop agent.
class PermissionRequest {
  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> input;

  const PermissionRequest({
    required this.toolCallId,
    required this.toolName,
    required this.input,
  });
}

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

  final _permissionController =
      StreamController<PermissionRequest?>.broadcast();
  Stream<PermissionRequest?> get permissionStream =>
      _permissionController.stream;

  // -- Internal state --
  final List<ChatMessage> _messages = [];
  ChatMessage? _streamingMessage;
  bool _isStreaming = false;
  StreamSubscription<WsMessage>? _wsSubscription;
  String? _currentSessionId;
  bool _isBrowsingHistory = false; // true when viewing a historical session
  String? _lastErrorText;
  DateTime? _lastErrorTime;

  bool get isStreaming => _isStreaming;
  String? get currentSessionId => _currentSessionId;
  bool get isBrowsingHistory => _isBrowsingHistory;

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
        // -- New stream:agent:* format --
        case WsEvents.agentText:
          _handleAgentText(wsMsg.data);
          break;
        case WsEvents.agentToolCall:
          _handleAgentToolCall(wsMsg.data);
          break;
        case WsEvents.agentToolResult:
          _handleAgentToolResult(wsMsg.data);
          break;
        case WsEvents.agentDone:
          _handleAgentDone(wsMsg.data);
          break;
        case WsEvents.agentError:
          _handleAgentError(wsMsg.data);
          break;
        case WsEvents.agentCompacted:
          _handleAgentCompacted(wsMsg.data);
          break;
        case WsEvents.agentPermissionRequest:
          _handlePermissionRequest(wsMsg.data);
          break;

        // -- Legacy format (backward compat) --
        case WsEvents.streamTextDelta:
          _handleAgentText(wsMsg.data);
          break;
        case WsEvents.streamToolUseStart:
          _handleLegacyToolUseStart(wsMsg.data);
          break;
        case WsEvents.streamDone:
          _handleAgentDone(wsMsg.data);
          break;
        case WsEvents.streamError:
          _handleAgentError(wsMsg.data);
          break;

        // -- Message-level events --
        case WsEvents.messageAssistant:
          _handleAssistantMessage(wsMsg.data);
          break;
        case WsEvents.messageUser:
          break; // Echo of our own message
        case WsEvents.sessionMessages:
          _handleSessionMessages(wsMsg.data);
          break;
      }
    } catch (e) {
      _notifyListeners();
    }
  }

  // ── stream:agent:text ──────────────────────────────────────────────
  void _handleAgentText(dynamic data) {
    final content = _extractContent(data);
    if (_streamingMessage == null) {
      _streamingMessage = ChatMessage(
        role: MessageRole.assistant,
        content: content,
        createdAt: DateTime.now(),
        isStreaming: true,
      );
      _isStreaming = true;
    } else {
      _streamingMessage = _streamingMessage!.copyWith(
        content: _streamingMessage!.content + content,
      );
    }
    _notifyListeners();
  }

  // ── stream:agent:tool_call ─────────────────────────────────────────
  void _handleAgentToolCall(dynamic data) {
    // Finalize any in-progress streaming text
    _finalizeStreamingMessage();

    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final toolCallId = map['toolCallId'] as String? ?? '';
    final toolName = map['toolName'] as String? ?? 'Unknown';
    final input = map['input'] as Map<String, dynamic>?;

    // Build a human-readable input summary
    String? inputSummary;
    if (input != null) {
      inputSummary = _summarizeToolInput(toolName, input);
    }

    final toolMsg = ChatMessage(
      role: MessageRole.tool,
      content: toolName,
      toolName: toolName,
      toolStatus: ToolCallStatus.running,
      toolCallId: toolCallId,
      toolInput: inputSummary,
      createdAt: DateTime.now(),
    );
    _messages.add(toolMsg);
    ChatDatabase.instance.insertMessage(toolMsg);
    _notifyListeners();
  }

  // ── stream:agent:tool_result ───────────────────────────────────────
  void _handleAgentToolResult(dynamic data) {
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final toolCallId = map['toolCallId'] as String? ?? '';
    final output = map['output'] as String? ?? '';
    final isError = map['isError'] as bool? ?? false;

    // Find the matching tool message and update it
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == MessageRole.tool &&
          _messages[i].toolCallId == toolCallId) {
        final truncatedOutput =
            output.length > 500 ? '${output.substring(0, 500)}…' : output;
        _messages[i] = _messages[i].copyWith(
          toolStatus: isError ? ToolCallStatus.error : ToolCallStatus.done,
          toolOutput: truncatedOutput,
        );
        ChatDatabase.instance.updateMessage(_messages[i]);
        break;
      }
    }
    _notifyListeners();
  }

  // ── stream:agent:done ──────────────────────────────────────────────
  void _handleAgentDone(dynamic data) {
    _finalizeStreamingMessage();

    // Extract token usage if available
    if (data is Map<String, dynamic>) {
      final usageMap = data['usage'] as Map<String, dynamic>?;
      if (usageMap != null && _messages.isNotEmpty) {
        final usage = TokenUsage(
          inputTokens: usageMap['inputTokens'] as int? ?? 0,
          outputTokens: usageMap['outputTokens'] as int? ?? 0,
        );
        // Attach usage to the last assistant message
        for (int i = _messages.length - 1; i >= 0; i--) {
          if (_messages[i].role == MessageRole.assistant) {
            _messages[i] = _messages[i].copyWith(usage: usage);
            ChatDatabase.instance.updateMessage(_messages[i]);
            break;
          }
        }
      }
    }

    // Mark any remaining "running" tools as done
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == MessageRole.tool &&
          _messages[i].toolStatus == ToolCallStatus.running) {
        _messages[i] = _messages[i].copyWith(toolStatus: ToolCallStatus.done);
        ChatDatabase.instance.updateMessage(_messages[i]);
      }
    }

    _isStreaming = false;
    _notifyListeners();
  }

  // ── stream:agent:error ─────────────────────────────────────────────
  void _handleAgentError(dynamic data) {
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final errorText = map['error'] as String? ?? data.toString();
    final recoverable = map['recoverable'] as bool? ?? false;

    // Skip recoverable errors silently
    if (recoverable && _streamingMessage == null) return;

    // Dedup: skip identical errors within 5 seconds
    final now = DateTime.now();
    if (_lastErrorText == errorText &&
        _lastErrorTime != null &&
        now.difference(_lastErrorTime!).inSeconds < 5) {
      return;
    }
    _lastErrorText = errorText;
    _lastErrorTime = now;

    if (_streamingMessage != null) {
      final completed = _streamingMessage!.copyWith(
        content: _streamingMessage!.content +
            (errorText.isNotEmpty ? '\n\n⚠ Error: $errorText' : ''),
        isStreaming: false,
      );
      _messages.add(completed);
      ChatDatabase.instance.insertMessage(completed);
      _streamingMessage = null;
    } else {
      // Standalone error — show but don't persist to avoid clutter on restart
      final errorMsg = ChatMessage(
        role: MessageRole.assistant,
        content: '⚠ Error: $errorText',
        createdAt: DateTime.now(),
      );
      _messages.add(errorMsg);
    }
    _isStreaming = false;
    _notifyListeners();
  }

  // ── stream:agent:compacted ─────────────────────────────────────────
  void _handleAgentCompacted(dynamic data) {
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final before = map['beforeTokens'] as int? ?? 0;
    final after = map['afterTokens'] as int? ?? 0;
    final auto = map['auto'] as bool? ?? false;

    final msg = ChatMessage(
      role: MessageRole.assistant,
      content:
          '🗜 Context compacted: $before → $after tokens${auto ? ' (auto)' : ''}',
      createdAt: DateTime.now(),
    );
    _messages.add(msg);
    ChatDatabase.instance.insertMessage(msg);
    _notifyListeners();
  }

  // ── stream:agent:permission_request ────────────────────────────────
  void _handlePermissionRequest(dynamic data) {
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final request = PermissionRequest(
      toolCallId: map['toolCallId'] as String? ?? '',
      toolName: map['toolName'] as String? ?? '',
      input: map['input'] as Map<String, dynamic>? ?? {},
    );
    if (!_permissionController.isClosed) {
      _permissionController.add(request);
    }
  }

  /// Send a permission response back to the desktop.
  void respondToPermission(String toolCallId, bool approved) {
    ConnectionManager.instance.send(WsMessage(
      event: WsEvents.permissionResponse,
      data: {'toolCallId': toolCallId, 'approved': approved},
    ));
    if (!_permissionController.isClosed) {
      _permissionController.add(null); // Clear the request
    }
  }

  // ── Legacy: stream:tool_use_start ──────────────────────────────────
  void _handleLegacyToolUseStart(dynamic data) {
    _finalizeStreamingMessage();

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

  // ── message:assistant ──────────────────────────────────────────────
  void _handleAssistantMessage(dynamic data) {
    if (_isStreaming) return;
    final content = _extractContent(data);
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

  // ── session:messages ───────────────────────────────────────────────
  void _handleSessionMessages(dynamic data) {
    if (data is! List) return;
    _messages.clear();
    _streamingMessage = null;
    _isStreaming = false;
    ChatDatabase.instance.clearAll();
    for (final item in data) {
      if (item is! Map) continue;
      final role =
          item['role'] == 'user' ? MessageRole.user : MessageRole.assistant;
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

  // ── Public API ─────────────────────────────────────────────────────

  /// Switch to a specific session (for browsing history).
  /// Pass null to return to the live/default chat.
  Future<void> switchToSession(String? sessionId) async {
    if (sessionId == _currentSessionId) return;

    // Finalize any in-progress streaming before switching
    if (_isStreaming && sessionId != _currentSessionId) {
      _finalizeStreamingMessage();
    }

    _currentSessionId = sessionId;
    _messages.clear();
    _streamingMessage = null;

    if (sessionId != null) {
      _isBrowsingHistory = true;
      final messages = await ChatDatabase.instance.getSessionMessages(
        sessionId,
        limit: 100,
      );
      _messages.addAll(messages);
    } else {
      _isBrowsingHistory = false;
      _messages.addAll(await ChatDatabase.instance.getMessages(limit: 100));
    }
    _notifyListeners();
  }

  /// Load messages fetched from desktop into the current view.
  void loadFetchedMessages(List<ChatMessage> messages) {
    _messages.clear();
    _messages.addAll(messages);
    _notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    // If browsing history, switch back to live mode
    if (_isBrowsingHistory) {
      _isBrowsingHistory = false;
      // Don't clear messages — they'll be updated by streaming events
    }

    final msg = ChatMessage(
      role: MessageRole.user,
      content: text,
      createdAt: DateTime.now(),
    );
    _messages.add(msg);
    await ChatDatabase.instance.insertMessage(msg, sessionId: _currentSessionId);
    ConnectionManager.instance.send(
      WsMessage(event: WsEvents.commandSend, data: {
        'content': text,
        if (_currentSessionId != null) 'sessionId': _currentSessionId,
      }),
    );
    _notifyListeners();
  }

  void stopGeneration() {
    ConnectionManager.instance.send(WsMessage(event: WsEvents.commandStop));
    _finalizeStreamingMessage();
    _isStreaming = false;
    _notifyListeners();
  }

  Future<void> clearSession() async {
    await ChatDatabase.instance.clearAll();
    _messages.clear();
    _streamingMessage = null;
    _isStreaming = false;
    _notifyListeners();
  }

  Future<void> loadHistory() async {
    _messages.clear();
    _messages.addAll(await ChatDatabase.instance.getMessages(limit: 100));
    _notifyListeners();
  }

  Future<void> loadMoreMessages() async {
    final older = await ChatDatabase.instance.getMessages(
      limit: 100,
      offset: _messages.length,
    );
    if (older.isEmpty) return;
    _messages.insertAll(0, older);
    _notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────

  void _finalizeStreamingMessage() {
    if (_streamingMessage != null) {
      final completed = _streamingMessage!.copyWith(isStreaming: false);
      _messages.add(completed);
      ChatDatabase.instance.insertMessage(completed);
      _streamingMessage = null;
    }
  }

  String _extractContent(dynamic data) {
    if (data is Map) return data['content'] as String? ?? '';
    return data?.toString() ?? '';
  }

  /// Build a human-readable one-line summary of tool input.
  String _summarizeToolInput(String toolName, Map<String, dynamic> input) {
    switch (toolName) {
      case 'Bash':
        return input['command'] as String? ?? '';
      case 'Read':
      case 'file-read':
        return input['file_path'] as String? ?? input['filePath'] as String? ?? '';
      case 'Write':
      case 'file-write':
        final path = input['file_path'] as String? ?? input['filePath'] as String? ?? '';
        return path;
      case 'Edit':
      case 'file-edit':
        return input['file_path'] as String? ?? input['filePath'] as String? ?? '';
      case 'Glob':
        return input['pattern'] as String? ?? '';
      case 'Grep':
        return input['pattern'] as String? ?? '';
      case 'WebSearch':
      case 'web-search':
        return input['query'] as String? ?? '';
      case 'WebFetch':
      case 'web-fetch':
        return input['url'] as String? ?? '';
      default:
        // Generic: show first string value
        for (final v in input.values) {
          if (v is String && v.isNotEmpty) {
            return v.length > 100 ? '${v.substring(0, 100)}…' : v;
          }
        }
        return jsonEncode(input).length > 100
            ? '${jsonEncode(input).substring(0, 100)}…'
            : jsonEncode(input);
    }
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
    _permissionController.close();
  }
}
