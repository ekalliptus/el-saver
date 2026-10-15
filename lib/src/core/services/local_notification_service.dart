
import 'dart:io';


import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/app_strings.dart';
import 'package:flutter/widgets.dart';

/// System-tray notifications for in-app events (download progress/complete,
/// update available). Independent of FCM — works fully offline.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Tray notifications are for when the user is NOT looking at the app.
  /// In the foreground the UI already shows a toast/dialog for the same
  /// event — posting both is double-reporting.
  bool get _userCanSeeApp =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      if (Platform.isAndroid) {
        // Best-effort Android 13+ prompt; the first-launch setup flow and
        // FCM already asked, so this is normally an instant no-op.
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestNotificationsPermission();
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[LocalNotif] init failed: $e');
      // Notifications are best-effort; never block startup.
    }
  }

  int _id(String key) => key.hashCode & 0x7fffffff;

  Future<void> _show(
    String key,
    String title,
    String body,
    AndroidNotificationDetails details,
  ) async {
    if (!_initialized) {
      debugPrint('[LocalNotif] show skipped: not initialized');
      return;
    }
    try {
      await _plugin.show(_id(key), title, body,
          NotificationDetails(android: details));
    } catch (e) {
      debugPrint("[LocalNotif] show failed [$title]: $e");
    }
  }

  /// Ongoing download notification with a live progress bar. Repeat calls
  /// with the same [key] update the bar instead of stacking new entries.
  Future<void> downloadProgress(String key, String title, int percent) async {
    await _show(
      key,
      '${AppStrings.notifDownloading} · $title',
      '$percent%',
      AndroidNotificationDetails(
        'downloads',
        AppStrings.notifDownloading,
        channelDescription: 'Progres dan hasil unduhan',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: 100,
        progress: percent.clamp(0, 100),
        onlyAlertOnce: true,
        silent: true,
        ongoing: true,
        // If the process dies mid-download this clears the "stuck at x%"
        // notification instead of leaving it pinned forever.
        timeoutAfter: const Duration(minutes: 30).inMilliseconds,
        channelShowBadge: false,
      ),
    );
  }

  /// Replaces the progress entry with a self-dismissing completion notice.
  Future<void> downloadCompleted(String key, String title) async {
    if (!_userCanSeeApp) return;
    await _show(
      key,
      AppStrings.notifDownloadComplete,
      title,
      AndroidNotificationDetails(
        // Separate channel: importance is pinned at channel creation on
        // Android, so reusing the silent progress channel ('downloads')
        // kept completion notices mute forever.
        'downloads_done',
        AppStrings.notifDownloadComplete,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        autoCancel: true,
        timeoutAfter: 8000,
      ),
    );
  }

  Future<void> downloadFailed(String key, String title, String reason) async {
    if (!_userCanSeeApp) return;
    await _show(
      key,
      AppStrings.notifDownloadFailed,
      title.isNotEmpty ? title : reason,
      AndroidNotificationDetails(
        'downloads_done',
        AppStrings.notifDownloadFailed,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        autoCancel: true,
        timeoutAfter: 8000,
      ),
    );
  }

  /// Removes a download notification (pause/delete) without a final state.
  Future<void> cancelDownload(String key) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_id(key));
    } catch (_) {}
  }

  /// One-shot tray notification that a newer version is available (shown
  /// once per version; the in-app dialog handles the actual update UX).
  Future<void> showUpdateAvailable(String version) async {
    await _show(
      'update:$version',
      AppStrings.notifUpdateAvailable,
      AppStrings.notifUpdateBody(version),
      const AndroidNotificationDetails(
        'updates',
        'Pembaruan',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
      ),
    );
  }
}
