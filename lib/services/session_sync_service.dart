import 'dart:async';

import '../models/chat_message.dart';
import '../models/connection_state.dart';
import '../models/session_meta.dart';
import '../models/ws_message.dart';
import 'chat_database.dart';
import 'connection_manager.dart';

/// Workspace info pushed by the desktop when mobile connects.
class WorkspaceInfo {
  final String workspaceName;
  final String workspacePath;
  final String? activeSessionId;
  final int sessionCount;

  const WorkspaceInfo({
    required this.workspaceName,
    required this.workspacePath,
    this.activeSessionId,
    required this.sessionCount,
  });
}

/// Singleton service that syncs session data from the desktop wzxClaw IDE.
///
/// Follows the [ProjectStore] pattern: subscribes to
/// [ConnectionManager.messageStream], exposes reactive streams, and
/// caches data locally in SQLite via [ChatDatabase].
class SessionSyncService {
  // -- Singleton --
  static final SessionSyncService _instance = SessionSyncService._();
  static SessionSyncService get instance => _instance;
  SessionSyncService._() {
    _init();
  }

  // -- Reactive state streams --
  final _sessionsController =
      StreamController<List<SessionMeta>>.broadcast();
  Stream<List<SessionMeta>> get sessionsStream => _sessionsController.stream;

  final _activeSessionController = StreamController<String?>.broadcast();
  Stream<String?> get activeSessionStream => _activeSessionController.stream;

  final _workspaceInfoController =
      StreamController<WorkspaceInfo?>.broadcast();
  Stream<WorkspaceInfo?> get workspaceInfoStream =>
      _workspaceInfoController.stream;

  final _loadingController = StreamController<bool>.broadcast();
  Stream<bool> get loadingStream => _loadingController.stream;

  // -- Internal state --
  List<SessionMeta> _sessions = [];
  String? _activeSessionId;
  WorkspaceInfo? _workspaceInfo;
  bool _isLoading = false;
  StreamSubscription<WsMessage>? _wsSubscription;
  StreamSubscription<WsConnectionState>? _stateSub;
  int _requestCounter = 0;
  final Map<String, Completer<dynamic>> _pendingRequests = {};

  List<SessionMeta> get sessions => List.unmodifiable(_sessions);
  String? get activeSessionId => _activeSessionId;
  WorkspaceInfo? get workspaceInfo => _workspaceInfo;
  bool get isLoading => _isLoading;

  void _init() {
    _wsSubscription =
        ConnectionManager.instance.messageStream.listen(_handleWsMessage);
    _stateSub =
        ConnectionManager.instance.stateStream.listen(_handleConnectionState);
    _loadCachedSessions();
  }

  // -- Connection state handler --
  void _handleConnectionState(WsConnectionState state) {
    if (state == WsConnectionState.connected) {
      // Small delay to let identity exchange happen first
      Future.delayed(const Duration(milliseconds: 800), () {
        if (ConnectionManager.instance.state == WsConnectionState.connected) {
          fetchSessions();
        }
      });
    }
  }

  // -- WS message router --
  void _handleWsMessage(WsMessage msg) {
    switch (msg.event) {
      case WsEvents.sessionListResponse:
        _handleSessionListResponse(msg.data);
        break;
      case WsEvents.sessionLoadResponse:
        _handleSessionLoadResponse(msg.data);
        break;
      case WsEvents.sessionWorkspaceInfo:
        _handleWorkspaceInfo(msg.data);
        break;
      case WsEvents.sessionActive:
        _handleSessionActive(msg.data);
        break;
      case WsEvents.sessionError:
        _handleSessionError(msg.data);
        break;
    }
  }

  // -- Response handlers --

  void _handleSessionListResponse(dynamic data) {
    if (data is! Map) return;
    final requestId = data['requestId'] as String? ?? '';
    final workspacePath = data['workspacePath'] as String? ?? '';
    final workspaceName = data['workspaceName'] as String? ?? '';
    final rawSessions = data['sessions'] as List? ?? [];

    final sessions = rawSessions
        .whereType<Map>()
        .map((s) => SessionMeta.fromDesktopJson(
              Map<String, dynamic>.from(s),
              workspacePath,
              workspaceName,
            ))
        .toList();

    _sessions = sessions;
    _isLoading = false;
    _sessionsController.add(List.unmodifiable(_sessions));
    _loadingController.add(false);

    // Cache to local DB
    ChatDatabase.instance.upsertSessions(sessions);

    // Resolve pending request if any
    _completePending(requestId, sessions);
  }

  void _handleSessionLoadResponse(dynamic data) {
    if (data is! Map) return;
    final requestId = data['requestId'] as String? ?? '';
    final sessionId = data['sessionId'] as String? ?? '';
    final rawMessages = data['messages'] as List? ?? [];
    final total = data['total'] as int? ?? 0;
    final offset = data['offset'] as int? ?? 0;
    final hasMore = data['hasMore'] as bool? ?? false;

    // Transform desktop messages to ChatMessage
    final messages = <ChatMessage>[];
    for (final raw in rawMessages) {
      if (raw is Map) {
        messages.add(_fromDesktopMessage(Map<String, dynamic>.from(raw)));
      }
    }

    // Cache messages locally
    if (offset == 0) {
      // First page: clear existing and insert fresh
      ChatDatabase.instance.clearSessionMessages(sessionId).then((_) {
        ChatDatabase.instance.insertSessionMessages(sessionId, messages);
        if (!hasMore) {
          ChatDatabase.instance.markSessionSynced(sessionId);
        }
      });
    } else {
      // Subsequent pages: append
      ChatDatabase.instance.insertSessionMessages(sessionId, messages);
      if (!hasMore) {
        ChatDatabase.instance.markSessionSynced(sessionId);
      }
    }

    _completePending(requestId, {
      'messages': messages,
      'total': total,
      'offset': offset,
      'hasMore': hasMore,
    });
  }

  void _handleWorkspaceInfo(dynamic data) {
    if (data is! Map) return;
    _workspaceInfo = WorkspaceInfo(
      workspaceName: data['workspaceName'] as String? ?? '',
      workspacePath: data['workspacePath'] as String? ?? '',
      activeSessionId: data['activeSessionId'] as String?,
      sessionCount: data['sessionCount'] as int? ?? 0,
    );
    _workspaceInfoController.add(_workspaceInfo);

    // Auto-fetch sessions when we know the workspace
    if (_sessions.isEmpty) {
      fetchSessions();
    }
  }

  void _handleSessionActive(dynamic data) {
    if (data is! Map) return;
    final sessionId = data['sessionId'] as String?;
    if (sessionId != null) {
      _activeSessionId = sessionId;
      _activeSessionController.add(_activeSessionId);
    }
  }

  void _handleSessionError(dynamic data) {
    if (data is! Map) return;
    final requestId = data['requestId'] as String? ?? '';
    final error = data['error'] as String? ?? 'Unknown error';
    _isLoading = false;
    _loadingController.add(false);
    _completePending(requestId, null, error: error);
  }

  // -- Public API --

  /// Request session list from the connected desktop.
  void fetchSessions() {
    if (ConnectionManager.instance.state != WsConnectionState.connected) {
      return;
    }
    _isLoading = true;
    _loadingController.add(true);
    final requestId = _nextRequestId();
    ConnectionManager.instance.send(WsMessage(
      event: WsEvents.sessionListRequest,
      data: {'requestId': requestId},
    ));
    // Timeout
    Future.delayed(const Duration(seconds: 5), () {
      if (_isLoading) {
        _isLoading = false;
        _loadingController.add(false);
        _completePending(requestId, null, error: 'Timeout');
      }
    });
  }

  /// Load messages for a session from the desktop (with pagination).
  ///
  /// Returns a map with keys: messages, total, offset, hasMore.
  /// If cached locally and [forceRefresh] is false, returns from cache.
  Future<Map<String, dynamic>> loadSessionMessages(
    String sessionId, {
    int offset = 0,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    // Check local cache first (only for first page and when not forcing)
    if (offset == 0 && !forceRefresh) {
      final cached = _sessions.where((s) => s.id == sessionId).toList();
      if (cached.isNotEmpty && cached.first.isSynced) {
        final messages =
            await ChatDatabase.instance.getSessionMessages(sessionId);
        return {
          'messages': messages,
          'total': messages.length,
          'offset': 0,
          'hasMore': false,
        };
      }
    }

    // Request from desktop
    if (ConnectionManager.instance.state != WsConnectionState.connected) {
      // Fallback to whatever is cached
      final messages =
          await ChatDatabase.instance.getSessionMessages(sessionId);
      return {
        'messages': messages,
        'total': messages.length,
        'offset': 0,
        'hasMore': false,
      };
    }

    final requestId = _nextRequestId();
    final completer = Completer<dynamic>();
    _pendingRequests[requestId] = completer;

    ConnectionManager.instance.send(WsMessage(
      event: WsEvents.sessionLoadRequest,
      data: {
        'requestId': requestId,
        'sessionId': sessionId,
        'offset': offset,
        'limit': limit,
      },
    ));

    // Timeout
    Future.delayed(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        _pendingRequests.remove(requestId);
        completer.completeError('Timeout loading session messages');
      }
    });

    final result = await completer.future;
    if (result is Map<String, dynamic>) {
      return result;
    }
    return {'messages': <ChatMessage>[], 'total': 0, 'offset': 0, 'hasMore': false};
  }

  /// Set the active session ID (when user taps a session).
  void setActiveSession(String? sessionId) {
    _activeSessionId = sessionId;
    _activeSessionController.add(_activeSessionId);
  }

  // -- Local cache --
  Future<void> _loadCachedSessions() async {
    final cached = await ChatDatabase.instance.getSessions();
    if (cached.isNotEmpty && _sessions.isEmpty) {
      _sessions = cached;
      _sessionsController.add(List.unmodifiable(_sessions));
    }
  }

  // -- Helpers --

  String _nextRequestId() {
    _requestCounter++;
    return 'req_${DateTime.now().millisecondsSinceEpoch}_$_requestCounter';
  }

  void _completePending(String requestId, dynamic result, {String? error}) {
    final completer = _pendingRequests.remove(requestId);
    if (completer != null && !completer.isCompleted) {
      if (error != null) {
        completer.completeError(error);
      } else {
        completer.complete(result);
      }
    }
  }

  /// Transform a desktop JSONL message to a mobile [ChatMessage].
  ChatMessage _fromDesktopMessage(Map<String, dynamic> json) {
    final role = json['role'] as String? ?? 'assistant';
    MessageRole messageRole;
    switch (role) {
      case 'user':
        messageRole = MessageRole.user;
        break;
      case 'tool_result':
        messageRole = MessageRole.tool;
        break;
      default:
        messageRole = MessageRole.assistant;
    }

    // Handle tool calls embedded in assistant messages
    List<ToolCallInfo>? toolCalls;
    if (json['toolCalls'] is List) {
      toolCalls = (json['toolCalls'] as List)
          .whereType<Map>()
          .map((tc) {
        final tcMap = Map<String, dynamic>.from(tc);
        return ToolCallInfo(
          toolCallId: tcMap['id'] as String? ?? '',
          toolName: tcMap['name'] as String? ?? '',
          inputSummary: _summarizeToolInput(
              tcMap['name'] as String?, tcMap['input']),
          status: ToolCallStatus.done,
        );
      }).toList();
    }

    TokenUsage? usage;
    if (json['usage'] is Map) {
      final u = Map<String, dynamic>.from(json['usage'] as Map);
      usage = TokenUsage(
        inputTokens: u['inputTokens'] as int? ?? 0,
        outputTokens: u['outputTokens'] as int? ?? 0,
      );
    }

    final timestamp = json['timestamp'] as int? ??
        DateTime.now().millisecondsSinceEpoch;

    return ChatMessage(
      role: messageRole,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
      toolCalls: toolCalls,
      usage: usage,
      toolCallId: json['toolCallId'] as String?,
      toolName: role == 'tool_result' ? (json['toolName'] as String?) : null,
      toolInput: null,
      toolOutput: role == 'tool_result' ? (json['content'] as String?) : null,
      toolStatus: role == 'tool_result'
          ? (json['isError'] == true
              ? ToolCallStatus.error
              : ToolCallStatus.done)
          : null,
    );
  }

  String? _summarizeToolInput(String? toolName, dynamic input) {
    if (input == null) return null;
    if (input is! Map) return input.toString();
    final map = Map<String, dynamic>.from(input);
    switch (toolName) {
      case 'Bash':
        return map['command'] as String?;
      case 'Read':
        return map['file_path'] as String?;
      case 'Write':
        return map['file_path'] as String?;
      case 'Edit':
        return map['file_path'] as String?;
      case 'Grep':
        return map['pattern'] as String?;
      case 'Glob':
        return map['pattern'] as String?;
      default:
        return map.keys.take(2).join(', ');
    }
  }

  void dispose() {
    _wsSubscription?.cancel();
    _stateSub?.cancel();
    _sessionsController.close();
    _activeSessionController.close();
    _workspaceInfoController.close();
    _loadingController.close();
  }
}
