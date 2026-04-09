import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/connection_state.dart';
import '../models/ws_message.dart';
import 'connection_manager.dart';

/// Top-level background message handler for FCM.
/// MUST be a top-level function, NOT a class method.
/// Runs in a separate Dart isolate on Android.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await plugin.initialize(initSettings);

  final title = message.data['title'] ?? 'wzxClaw';
  final body = message.data['body'] ?? 'Task completed';
  final channelId = message.data['channel'] ?? 'task_complete';

  final androidDetails = AndroidNotificationDetails(
    channelId,
    channelId == 'error' ? 'Errors' : 'Task Complete',
    channelDescription: channelId == 'error'
        ? 'High priority error notifications'
        : 'Notifications when AI tasks complete',
    importance: channelId == 'error' ? Importance.high : Importance.defaultImportance,
    priority: Priority.high,
  );
  const iosDetails = null;
  final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  await plugin.show(
    message.hashCode,
    title,
    body,
    details,
  );
}

/// Singleton service managing FCM push notifications.
///
/// Follows the established singleton pattern from ConnectionManager/ChatStore.
/// Handles:
/// - FCM initialization and token management
/// - Local notification display for foreground/background data messages
/// - Foreground suppression (no notification when app is visible)
/// - Notification tap -> navigation to home page
/// - FCM token registration with relay server via WebSocket
class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();
  String? _fcmToken;
  bool _isForeground = true;
  bool _initialized = false;
  StreamSubscription<WsConnectionState>? _connectSub;

  /// Global navigator key for notification tap navigation.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  bool get isInitialized => _initialized;

  /// Initialize FCM and local notifications.
  /// Call from main() after WidgetsFlutterBinding.ensureInitialized().
  Future<void> init() async {
    try {
      await Firebase.initializeApp();

      // Setup local notification channels.
      await _setupLocalNotifications();

      // Request notification permission (Android 13+).
      await _requestPermission();

      // Get FCM token.
      _fcmToken = await FirebaseMessaging.instance.getToken();

      // Setup FCM listeners.
      _setupFCMListeners();

      // Register token with relay on connection.
      _registerTokenOnConnect();

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
      // Non-fatal: app works without push notifications.
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels.
    final androidPlugin = _localPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      const taskChannel = AndroidNotificationChannel(
        'task_complete',
        'Task Complete',
        description: 'Notifications when AI tasks complete',
        importance: Importance.defaultImportance,
      );
      const errorChannel = AndroidNotificationChannel(
        'error',
        'Errors',
        description: 'High priority error notifications',
        importance: Importance.high,
      );
      await androidPlugin.createNotificationChannel(taskChannel);
      await androidPlugin.createNotificationChannel(errorChannel);
    }
  }

  Future<void> _requestPermission() async {
    if (!Platform.isAndroid) return;
    // firebase_messaging handles the permission request internally.
    await FirebaseMessaging.instance.requestPermission();
  }

  void _setupFCMListeners() {
    // Foreground messages: suppress if app is visible.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (_isForeground) {
        // App is visible -- do NOT show notification.
        // The chat UI renders messages via WebSocket directly.
        return;
      }
      _showLocalNotification(message);
    });

    // Notification tap when app was in background (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateToHome();
    });

    // Background message handler (top-level function).
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // Token refresh.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _sendTokenToRelay(newToken);
    });
  }

  void _showLocalNotification(RemoteMessage message) {
    final title = message.data['title'] ?? 'wzxClaw';
    final body = message.data['body'] ?? 'Task completed';
    final channelId = message.data['channel'] ?? 'task_complete';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'error' ? 'Errors' : 'Task Complete',
      channelDescription: channelId == 'error'
          ? 'High priority error notifications'
          : 'Notifications when AI tasks complete',
      importance: channelId == 'error' ? Importance.high : Importance.defaultImportance,
      priority: Priority.high,
    );
    const iosDetails = null;
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    _localPlugin.show(
      message.hashCode,
      title,
      body,
      details,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    _navigateToHome();
  }

  void _navigateToHome() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  /// Send FCM token to relay on each successful WebSocket connection.
  /// Handles the race condition where token is obtained before WebSocket connects.
  void _registerTokenOnConnect() {
    _connectSub = ConnectionManager.instance.stateStream.listen((state) {
      if (state == WsConnectionState.connected && _fcmToken != null) {
        _sendTokenToRelay(_fcmToken!);
      }
    });
  }

  void _sendTokenToRelay(String token) {
    ConnectionManager.instance.send(
      WsMessage(event: WsEvents.fcmRegister, data: {'token': token}),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
  }

  void dispose() {
    _connectSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
