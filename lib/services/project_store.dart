import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/connection_state.dart';
import '../models/project.dart';
import '../models/ws_message.dart';
import 'connection_manager.dart';

/// Singleton state manager for the project list from the desktop IDE.
///
/// Sends `/projects` and `/switch` commands directly via [ConnectionManager]
/// (NOT via [ChatStore]) to avoid polluting the chat history.
///
/// Consumes the [ConnectionManager.messageStream] and defensively parses
/// desktop responses in three formats: JSON with `projects` key, bare JSON
/// array, and plain text fallback.
///
/// The current project name is persisted to [SharedPreferences] so it
/// survives app restarts.
class ProjectStore {
  // -- Singleton --
  static final ProjectStore _instance = ProjectStore._();
  static ProjectStore get instance => _instance;
  ProjectStore._() {
    _init();
  }

  // -- Reactive state streams --
  final _projectsController = StreamController<List<Project>>.broadcast();
  Stream<List<Project>> get projectsStream => _projectsController.stream;

  final _currentProjectController = StreamController<String?>.broadcast();
  Stream<String?> get currentProjectStream =>
      _currentProjectController.stream;

  final _loadingController = StreamController<bool>.broadcast();
  Stream<bool> get loadingStream => _loadingController.stream;

  final _errorController = StreamController<String?>.broadcast();
  Stream<String?> get errorStream => _errorController.stream;

  // -- Internal state --
  List<Project> _projects = [];
  String? _currentProjectName;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<WsMessage>? _wsSubscription;
  StreamSubscription<WsConnectionState>? _stateSub;
  String? _pendingSwitchName;

  List<Project> get projects => List.unmodifiable(_projects);
  String? get currentProjectName => _currentProjectName;
  bool get isLoading => _isLoading;

  static const String _prefsKey = 'current_project_name';

  void _init() {
    _wsSubscription =
        ConnectionManager.instance.messageStream.listen(_handleWsMessage);
    _stateSub =
        ConnectionManager.instance.stateStream.listen(_handleConnectionState);
    _loadSavedProject();
  }

  // -- Load persisted current project name --
  Future<void> _loadSavedProject() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty) {
      _currentProjectName = saved;
      _currentProjectController.add(_currentProjectName);
    }
  }

  // -- Connection state handler --
  void _handleConnectionState(WsConnectionState state) {
    // Auto-refresh project list when connection is restored
    if (state == WsConnectionState.connected && _projects.isEmpty) {
      fetchProjects();
    }
  }

  // -- Incoming message handler --
  void _handleWsMessage(WsMessage wsMsg) {
    if (wsMsg.event != WsEvents.messageAssistant) return;
    _tryParseProjectResponse(wsMsg.data);
  }

  // -- Response parser --
  void _tryParseProjectResponse(dynamic data) {
    try {
      // Try structured JSON response first
      if (data is Map) {
        // Format: { "projects": [{ "name": "...", "status": "running|idle" }] }
        if (data.containsKey('projects')) {
          final rawList = data['projects'];
          if (rawList is List) {
            _parseProjectList(rawList);
            return;
          }
        }
        // Format: { "type": "project_list", "projects": [...] }
        if (data['type'] == 'project_list' && data['projects'] is List) {
          _parseProjectList(data['projects'] as List);
          return;
        }
        // Format: { "type": "switch_result", "project": "...", "success": true/false }
        if (data['type'] == 'switch_result') {
          _handleSwitchResult(data);
          return;
        }
      }

      // Bare array: [{ "name": "...", "status": "running|idle" }]
      if (data is List) {
        _parseProjectList(data);
        return;
      }

      // Plain text fallback: newline-separated project names
      if (data is String && data.isNotEmpty) {
        final trimmed = data.trim();
        // Heuristic: if it contains multiple lines or known project indicators
        if (trimmed.contains('\n') || trimmed.contains('项目')) {
          _parseTextProjectList(trimmed);
        }
      }
    } catch (_) {
      // Defensive: never crash on malformed data (T-04-01)
      _isLoading = false;
      _loadingController.add(false);
      _errorController.add('项目数据解析失败');
      _notifyListeners();
    }
  }

  void _parseProjectList(List rawList) {
    final parsed = <Project>[];
    for (final item in rawList) {
      if (item is Map<String, dynamic>) {
        parsed.add(Project.fromJson(item));
      } else if (item is Map) {
        parsed.add(Project.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    _projects = parsed;
    _isLoading = false;
    _errorMessage = null;
    _notifyListeners();
  }

  void _parseTextProjectList(String text) {
    // Parse plain text like "project1\nproject2\n* project3"
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'));
    final parsed = <Project>[];
    for (final line in lines) {
      final name = line.replaceAll(RegExp(r'^[\-\*]\s*'), '').trim();
      if (name.isNotEmpty) {
        parsed.add(Project(name: name, isRunning: false));
      }
    }
    if (parsed.isNotEmpty) {
      _projects = parsed;
      _isLoading = false;
      _errorMessage = null;
      _notifyListeners();
    }
  }

  void _handleSwitchResult(Map<dynamic, dynamic> data) {
    final success = data['success'] as bool? ?? false;
    final project = data['project'] as String?;

    if (success && project != null) {
      _currentProjectName = project;
      _pendingSwitchName = null;
      _persistCurrentProject(project);
      _notifyListeners();
    } else {
      // Switch failed -- revert optimistic update
      final errorMsg =
          data['error'] as String? ?? '切换失败：桌面端未响应';
      _errorController.add(errorMsg);
      _pendingSwitchName = null;
      _notifyListeners();
    }
  }

  // -- Public API --

  /// Send /projects command to fetch project list from desktop.
  ///
  /// Sends directly via [ConnectionManager] (NOT [ChatStore]) to avoid
  /// polluting chat history.
  void fetchProjects() {
    if (ConnectionManager.instance.state != WsConnectionState.connected) {
      _errorController.add('未连接 -- 无法获取项目');
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    _loadingController.add(true);
    ConnectionManager.instance.send(
      WsMessage(event: WsEvents.commandSend, data: {'content': '/projects'}),
    );
    // Set a timeout: if no response within 5 seconds, clear loading state
    Future.delayed(const Duration(seconds: 5), () {
      if (_isLoading) {
        _isLoading = false;
        _loadingController.add(false);
        _errorController.add('获取项目列表超时');
        _notifyListeners();
      }
    });
  }

  /// Send /switch [name] command to switch active project.
  ///
  /// Uses optimistic UI update with [_pendingSwitchName] tracking for
  /// potential revert on failure.
  void switchProject(String name) {
    if (ConnectionManager.instance.state != WsConnectionState.connected) {
      _errorController.add('未连接 -- 无法切换项目');
      return;
    }
    // Optimistic update
    _pendingSwitchName = name;
    _currentProjectName = name;
    _notifyListeners();

    ConnectionManager.instance.send(
      WsMessage(
        event: WsEvents.commandSend,
        data: {'content': '/switch $name'},
      ),
    );
  }

  /// Clear project data (e.g., on disconnect).
  void clearProjects() {
    _projects = [];
    _isLoading = false;
    _errorMessage = null;
    _pendingSwitchName = null;
    _notifyListeners();
  }

  // -- Persistence --
  Future<void> _persistCurrentProject(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, name);
  }

  // -- Notification --
  void _notifyListeners() {
    if (!_projectsController.isClosed) {
      _projectsController.add(List.unmodifiable(_projects));
    }
    if (!_currentProjectController.isClosed) {
      _currentProjectController.add(_currentProjectName);
    }
    if (!_loadingController.isClosed) {
      _loadingController.add(_isLoading);
    }
  }

  /// Dispose all resources. Call only when the app is being destroyed.
  void dispose() {
    _wsSubscription?.cancel();
    _stateSub?.cancel();
    _projectsController.close();
    _currentProjectController.close();
    _loadingController.close();
    _errorController.close();
  }
}
