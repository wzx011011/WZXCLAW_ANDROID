import 'dart:async';
import 'dart:math';

import '../models/task_model.dart';
import '../models/ws_message.dart';
import 'connection_manager.dart';

/// Singleton service for task management via WebSocket.
///
/// Handles requesting, creating, updating, and deleting tasks on the desktop.
/// Exposes reactive streams for the task list and active task.
class TaskService {
  // -- Singleton --
  static final TaskService _instance = TaskService._();
  static TaskService get instance => _instance;
  TaskService._() {
    _init();
  }

  // -- Reactive state --
  final _tasksController = StreamController<List<TaskModel>>.broadcast();
  Stream<List<TaskModel>> get tasksStream => _tasksController.stream;

  final _loadingController = StreamController<bool>.broadcast();
  Stream<bool> get loadingStream => _loadingController.stream;

  String? _activeTaskId;
  String? get activeTaskId => _activeTaskId;
  final _activeTaskIdController = StreamController<String?>.broadcast();
  Stream<String?> get activeTaskIdStream => _activeTaskIdController.stream;

  List<TaskModel> _tasks = [];
  List<TaskModel> get tasks => List.unmodifiable(_tasks);

  StreamSubscription<WsMessage>? _wsSub;
  final _random = Random.secure();

  /// Generate a unique request ID to correlate WS responses.
  String _newRequestId() =>
      '${DateTime.now().millisecondsSinceEpoch}-${_random.nextInt(1000000)}';

  void _init() {
    _wsSub = ConnectionManager.instance.messageStream.listen(
      _onMessage,
      // Keep subscription alive even if upstream emits an error.
      onError: (Object err, StackTrace st) {},
      cancelOnError: false,
    );
  }

  void _onMessage(WsMessage msg) {
    switch (msg.event) {
      case WsEvents.taskListResponse:
        if (!_loadingController.isClosed) _loadingController.add(false);
        final data = msg.data;
        if (data is! Map<String, dynamic>) break; // skip malformed frame
        final tasksList = data['tasks'] as List<dynamic>? ?? [];
        _tasks = tasksList
            .whereType<Map<String, dynamic>>()
            .map(TaskModel.fromJson)
            .toList();
        _tasksController.add(_tasks);
        break;

      case WsEvents.taskCreateResponse:
      case WsEvents.taskUpdateResponse:
      case WsEvents.taskDeleteResponse:
        // Refresh after any mutation
        requestTaskList();
        break;

      case WsEvents.taskError:
        if (!_loadingController.isClosed) _loadingController.add(false);
        break;
    }
  }

  /// Request the full task list from desktop.
  void requestTaskList() {
    if (!_loadingController.isClosed) _loadingController.add(true);
    ConnectionManager.instance.send(WsMessage(
      event: WsEvents.taskListRequest,
      data: {'requestId': _newRequestId()},
    ),);
  }

  /// Set the active task (local state only, also notifies desktop via command).
  void setActiveTask(String? taskId) {
    _activeTaskId = taskId;
    _activeTaskIdController.add(_activeTaskId);
  }

  /// Create a new task with the given title.
  void createTask(String title) {
    ConnectionManager.instance.send(WsMessage(
      event: WsEvents.taskCreateRequest,
      data: {
        'requestId': _newRequestId(),
        'title': title,
      },
    ),);
  }

  /// Archive a task.
  void archiveTask(String taskId) {
    ConnectionManager.instance.send(WsMessage(
      event: WsEvents.taskUpdateRequest,
      data: {
        'requestId': _newRequestId(),
        'taskId': taskId,
        'updates': {'archived': true},
      },
    ),);
  }

  /// Delete a task.
  void deleteTask(String taskId) {
    ConnectionManager.instance.send(WsMessage(
      event: WsEvents.taskDeleteRequest,
      data: {
        'requestId': _newRequestId(),
        'taskId': taskId,
      },
    ),);
  }

  void dispose() {
    _wsSub?.cancel();
    _tasksController.close();
    _loadingController.close();
    _activeTaskIdController.close();
  }
}
