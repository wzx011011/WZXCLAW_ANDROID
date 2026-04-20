import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../models/connection_state.dart';
import '../models/ws_message.dart';

/// Singleton WebSocket connection manager for wzxClaw Android.
///
/// Manages a single WebSocket connection to the wzxClaw desktop IDE with:
/// - Connection state machine (disconnected/connecting/connected/reconnecting)
/// - Application-level heartbeat (ping/pong) with timeout detection
/// - Idle monitor (force-reconnect after 60s of no messages)
/// - Exponential backoff reconnection with jitter
/// - Send queue that buffers messages during disconnection
/// - App lifecycle handling (pause stops heartbeat, resume force-reconnects)
/// - Connection sequence guard to prevent stale callback processing
///
/// This is the sole owner of the WebSocket connection. All pages subscribe
/// to [stateStream] and [messageStream] but never create connections directly.
class ConnectionManager with WidgetsBindingObserver {
  // -- Singleton --
  static final ConnectionManager _instance = ConnectionManager._();
  static ConnectionManager get instance => _instance;
  ConnectionManager._() {
    WidgetsBinding.instance.addObserver(this);
  }

  // -- Public state streams --
  final StreamController<WsConnectionState> _stateController =
      StreamController<WsConnectionState>.broadcast();
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  final StreamController<WsMessage> _messageController =
      StreamController<WsMessage>.broadcast();
  Stream<WsMessage> get messageStream => _messageController.stream;

  // -- Last error stream --
  String? _lastError;
  String? get lastError => _lastError;
  final StreamController<String?> _errorController =
      StreamController<String?>.broadcast();
  Stream<String?> get errorStream => _errorController.stream;

  // -- Desktop identity stream --
  String? _desktopIdentity;
  String? get desktopIdentity => _desktopIdentity;
  final StreamController<String?> _desktopIdentityController =
      StreamController<String?>.broadcast();
  Stream<String?> get desktopIdentityStream => _desktopIdentityController.stream;

  // -- Desktop online state (relay reports desktop presence) --
  bool _desktopOnline = false;
  bool get desktopOnline => _desktopOnline;
  final StreamController<bool> _desktopOnlineController =
      StreamController<bool>.broadcast();
  Stream<bool> get desktopOnlineStream => _desktopOnlineController.stream;

  // -- Internal state --
  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  WebSocketChannel? _channel;
  String? _url;
  int _reconnectAttempt = 0;

  // Timers
  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeoutTimer;
  Timer? _idleTimer;
  Timer? _reconnectTimer;

  DateTime? _lastMessageTime;

  /// Connection sequence number -- incremented on each new connect() call.
  /// Stale stream listeners check this value and bail out if it doesn't match.
  int _connSeq = 0;

  /// Send queue -- holds JSON strings of messages queued during disconnection.
  final List<String> _sendQueue = [];

  /// Tracks whether we are expecting a pong (heartbeat sent, awaiting reply).
  bool _waitingForPong = false;

  /// Set to true when the app enters [AppLifecycleState.paused].
  /// Used to skip the reconnect probe when only [inactive] was triggered.
  bool _wasPaused = false;

  // ============================================================
  // Public API
  // ============================================================

  /// Connect to the given WebSocket URL.
  ///
  /// [url] should be like `ws://192.168.1.100:3000/?token=xxx`.
  /// If already connected or connecting, this will force-close the old
  /// connection first (via disconnect), then open a fresh one.
  void connect(String url) {
    // If there is an existing connection, tear it down first.
    if (_state != WsConnectionState.disconnected) {
      disconnect();
    }

    _url = url;
    final seq = ++_connSeq;

    _setState(WsConnectionState.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
    } catch (e) {
      // Invalid URL or connection failure -- schedule reconnect.
      _setError('连接失败: $e');
      _scheduleReconnect();
      return;
    }

    _channel!.stream.listen(
      (data) {
        if (seq != _connSeq) return; // stale connection, ignore
        _onMessage(data);
      },
      onDone: () {
        if (seq != _connSeq) return;
        _onChannelDone();
      },
      onError: (error) {
        if (seq != _connSeq) return;
        _onChannelError(error);
      },
    );

    // Mark connected when WebSocket handshake completes.
    // Do not wait for a message -- relay does not send anything on connect.
    _channel!.ready.then((_) {
      if (seq == _connSeq && _state == WsConnectionState.connecting) {
        _setError(null); // Clear error on successful connection
        _setState(WsConnectionState.connected);
        _startHeartbeat();
        _startIdleMonitor();
        _flushQueue();
        // Announce mobile identity to desktop
        _rawSend(jsonEncode({
          'event': WsEvents.identityMobileAnnounce,
          'data': {'name': 'wzxClaw Android', 'platform': 'android'},
        }),);
      }
    }).catchError((error) {
      if (seq == _connSeq) {
        _setError('握手失败: $error');
        _onChannelError(error);
      }
    });
  }

  /// Clean disconnect.
  ///
  /// Cancels all timers, closes the channel, resets reconnect attempt counter,
  /// and clears the send queue.
  void disconnect() {
    _cancelAllTimers();
    _sendQueue.clear();
    _waitingForPong = false;
    _desktopIdentity = null;
    _desktopIdentityController.add(null);
    _desktopOnline = false;
    _desktopOnlineController.add(false);

    if (_channel != null) {
      try {
        _channel!.sink.close(1000, 'client disconnect');
      } catch (_) {
        // Channel may already be closed.
      }
      _channel = null;
    }

    _setState(WsConnectionState.disconnected);
  }

  /// Send a message over the WebSocket.
  ///
  /// If connected and heartbeat is healthy, sends immediately.
  /// Otherwise, queues the message for delivery on reconnect.
  void send(WsMessage message) {
    final json = message.toJsonString();

    if (_state == WsConnectionState.connected && !_waitingForPong) {
      _rawSend(json);
    } else {
      if (_sendQueue.length >= AppConfig.maxQueueSize) {
        // Discard the oldest message to stay within limit.
        _sendQueue.removeAt(0);
      }
      _sendQueue.add(json);
    }
  }

  // ============================================================
  // Lifecycle handling (WidgetsBindingObserver)
  // ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.paused:
        // Full background — heartbeat timers are useless, stop them.
        _wasPaused = true;
        _stopHeartbeat();
        _stopIdleMonitor();
        break;

      case AppLifecycleState.inactive:
        // Transient state (notification shade, volume overlay, etc.).
        // Do NOT interrupt the connection — this fires far too often.
        break;

      case AppLifecycleState.resumed:
        // Only act if the app was truly backgrounded (paused), not just
        // briefly inactive.  This prevents constant reconnect flicker.
        if (_wasPaused) {
          _wasPaused = false;
          if (_url != null) _resumeCheck();
        }
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Probe the existing connection on app resume instead of blindly
  /// force-reconnecting.  If the WS is still alive (pong within 4 s),
  /// simply restart heartbeat timers.  Only force-reconnect on timeout.
  void _resumeCheck() {
    if (_state == WsConnectionState.connected && !_waitingForPong) {
      _waitingForPong = true;
      _rawSend(jsonEncode({'event': WsEvents.ping}));
      _heartbeatTimeoutTimer?.cancel();
      _heartbeatTimeoutTimer = Timer(const Duration(seconds: 4), () {
        if (_waitingForPong) {
          _forceReconnect('resume probe timeout');
        } else {
          // Connection survived — restart normal heartbeat/idle timers.
          _startHeartbeat();
          _startIdleMonitor();
        }
      });
    } else {
      // Already disconnected or in intermediate state — reconnect normally.
      _forceReconnect('app resumed from pause');
    }
  }

  // ============================================================
  // Message handling
  // ============================================================

  void _onMessage(dynamic data) {
    if (data is! String) return; // ignore binary frames

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final event = json['event'] as String? ?? '';
      _lastMessageTime = DateTime.now();

      if (event == WsEvents.pong) {
        // Pong received -- connection is verified bidirectional.
        // Reset backoff only after real proof the connection works.
        _waitingForPong = false;
        _heartbeatTimeoutTimer?.cancel();
        _reconnectAttempt = 0;
        return;
      }

      // Handle desktop identity announcement
      if (event == WsEvents.identityAnnounce) {
        final d = json['data'];
        if (d is Map<String, dynamic>) {
          _desktopIdentity = d['name'] as String? ?? 'wzxClaw';
        } else if (d is String) {
          _desktopIdentity = d;
        }
        _desktopIdentityController.add(_desktopIdentity);
        // Identity announcement implies desktop is online
        if (!_desktopOnline) {
          _desktopOnline = true;
          _desktopOnlineController.add(true);
        }
        return;
      }

      // System events from relay — don't broadcast to chat
      if (event.startsWith('system:')) {
        if (event == WsEvents.systemDesktopConnected) {
          if (!_desktopOnline) {
            _desktopOnline = true;
            _desktopOnlineController.add(true);
          }
        } else if (event == WsEvents.systemDesktopDisconnected) {
          _desktopOnline = false;
          _desktopOnlineController.add(false);
          _desktopIdentity = null;
          _desktopIdentityController.add(null);
        }
        return;
      }

      // Broadcast all other messages to subscribers.
      final message = WsMessage.fromJson(json);
      _messageController.add(message);
    } catch (_) {
      // Malformed JSON -- ignore silently (T-01-02 mitigation).
      // Do not crash on invalid data.
    }
  }

  // ============================================================
  // Heartbeat
  // ============================================================

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(AppConfig.heartbeatInterval, (_) {
      if (_state != WsConnectionState.connected) return;

      // Send application-level ping.
      _waitingForPong = true;
      _rawSend(jsonEncode({'event': WsEvents.ping}));

      // Start timeout -- if no pong within 8 seconds, connection is dead.
      _heartbeatTimeoutTimer = Timer(AppConfig.heartbeatTimeout, () {
        if (_waitingForPong) {
          _forceReconnect('heartbeat timeout');
        }
      });
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;
    _waitingForPong = false;
  }

  // ============================================================
  // Idle monitor
  // ============================================================

  void _startIdleMonitor() {
    _stopIdleMonitor();
    _lastMessageTime = DateTime.now();

    // Check every 10 seconds whether the connection has gone idle.
    _idleTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_state != WsConnectionState.connected) return;
      if (_lastMessageTime == null) return;

      final elapsed = DateTime.now().difference(_lastMessageTime!);
      if (elapsed > AppConfig.maxIdleTime) {
        _forceReconnect('idle timeout (${elapsed.inSeconds}s)');
      }
    });
  }

  void _stopIdleMonitor() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  // ============================================================
  // Reconnection
  // ============================================================

  void _forceReconnect(String reason) {
    // Cancel all timers first.
    _cancelAllTimers();

    // Increment sequence to invalidate stale onDone/onError callbacks
    // from the channel we are about to close.
    _connSeq++;

    // Close the channel with an abnormal close code.
    if (_channel != null) {
      try {
        _channel!.sink.close(4000, reason);
      } catch (_) {
        // Channel may already be closed.
      }
      _channel = null;
    }

    _setState(WsConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    // Exponential backoff: min(30s, base * 2^attempt) + jitter(0-500ms)
    final baseMs = AppConfig.reconnectBaseDelay.inMilliseconds;
    final maxMs = AppConfig.reconnectMaxDelay.inMilliseconds;
    final delayMs = (baseMs * (1 << _reconnectAttempt)).clamp(0, maxMs);
    final jitter = Random().nextInt(AppConfig.jitterMaxMs);
    final totalDelay = Duration(milliseconds: delayMs + jitter);

    _reconnectAttempt++;

    _reconnectTimer = Timer(totalDelay, () {
      if (_url != null) {
        connect(_url!);
      }
    });

    if (_state != WsConnectionState.disconnected) {
      _setState(WsConnectionState.reconnecting);
    }
  }

  // ============================================================
  // Channel events
  // ============================================================

  void _onChannelDone() {
    _stopHeartbeat();
    _stopIdleMonitor();

    if (_state != WsConnectionState.disconnected) {
      // Not an intentional disconnect -- schedule reconnect.
      _setState(WsConnectionState.reconnecting);
      _scheduleReconnect();
    }
  }

  void _onChannelError(Object error) {
    _stopHeartbeat();
    _stopIdleMonitor();
    _setError('$error');

    if (_state != WsConnectionState.disconnected) {
      _setState(WsConnectionState.reconnecting);
      _scheduleReconnect();
    }
  }

  // ============================================================
  // Send queue
  // ============================================================

  void _flushQueue() {
    while (_sendQueue.isNotEmpty) {
      final json = _sendQueue.removeAt(0);
      _rawSend(json);
    }
  }

  // ============================================================
  // Helpers
  // ============================================================

  void _setState(WsConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  void _setError(String? error) {
    _lastError = error;
    _errorController.add(error);
  }

  void _rawSend(String json) {
    if (_channel != null) {
      try {
        _channel!.sink.add(json);
      } catch (_) {
        // Channel might be closed -- ignore.
      }
    }
  }

  void _cancelAllTimers() {
    _stopHeartbeat();
    _stopIdleMonitor();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // ============================================================
  // Cleanup (call when app is shutting down)
  // ============================================================

  /// Dispose all resources. Call only when the app is being destroyed.
  void dispose() {
    disconnect();
    WidgetsBinding.instance.removeObserver(this);
    _stateController.close();
    _messageController.close();
    _errorController.close();
  }
}
