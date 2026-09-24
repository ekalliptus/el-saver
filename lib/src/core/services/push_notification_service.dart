import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../common_widgets/toast.dart';
import '../utils/app_enums.dart';

/// Handler for background/terminated FCM messages. Must be a top-level
/// function annotated for AOT keep-alive.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('Background push: ${message.notification?.title}',
      name: 'PushNotification');
}

/// Firebase Cloud Messaging: registers the device, subscribes to the
/// broadcast topic, and surfaces foreground messages as toasts.
/// Background/terminated notification pushes are shown by the system tray.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;

      // Android 13+ runtime permission (also granted via app settings flow).
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((message) {
        final title = message.notification?.title;
        final body = message.notification?.body;
        if (title != null || body != null) {
          buildToast(
            msg: '${title ?? 'EL-Saver'}: ${body ?? ''}'.trim(),
            type: ToastType.info,
          );
        }
      });

      await messaging.subscribeToTopic('all-users');
      final token = await messaging.getToken();
      if (kDebugMode && token != null) {
        developer.log('FCM token: $token', name: 'PushNotification');
      }
      messaging.onTokenRefresh.listen((_) {});
      _initialized = true;
      developer.log('FCM initialized', name: 'PushNotification');
    } catch (e) {
      // Push is best-effort: never block startup.
      developer.log('FCM init failed: $e', name: 'PushNotification');
    }
  }
}
