// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:developer' as developer;

class PermissionService {
  static const String _permissionsGrantedKey = 'permissions_granted';
  static const String _firstLaunchKey = 'first_launch_completed';

  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // Check if this is the first launch
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_firstLaunchKey) ?? false);
  }

  // Mark first launch as completed
  Future<void> markFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, true);
  }

  // Check if all permissions are granted
  Future<bool> areAllPermissionsGranted() async {
    // Real runtime state, not just the stored flag: users upgrading from
    // older versions already have the flag set but never granted the newer
    // permissions (media / all-files), so they must be re-offered setup.
    return await hasMediaAccess() && await hasAllFilesAccess();
  }

  // Mark all permissions as granted
  Future<void> markPermissionsGranted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsGrantedKey, true);
  }

  // Show permission dialog and request all necessary permissions
  Future<bool?> requestAllPermissions(BuildContext context) async {
    if (!Platform.isAndroid) {
      // For non-Android platforms, mark as granted
      await markPermissionsGranted();
      return true;
    }

    try {
      // Show welcome dialog first
      final shouldContinue = await _showWelcomeDialog(context);
      if (!shouldContinue) {
        // User pressed Back - return null to indicate cancellation
        return null;
      }

      // Media access (read) — needed for the WhatsApp status saver and
      // for browsing saved media on legacy Android versions.
      await _ensureMediaAccess(context);

      // All-files access — WhatsApp stores statuses in a hidden folder that
      // scoped-storage media permissions cannot list on Android 11+.
      await _ensureAllFilesAccess(context);

      // Notifications (Android 13+) — optional, for update/announcement push.
      await _ensureNotificationAccess(context);

      // Request install unknown apps permission (needed for the system
      // installer popup during in-app updates)
      bool installGranted = await _requestInstallPermission(context);
      if (!installGranted) return false;

      // Mark all permissions as granted
      await markPermissionsGranted();
      await markFirstLaunchCompleted();

      // Show completion dialog
      await _showCompletionDialog(context);

      // Permission setup completed

      developer.log('All permissions setup completed',
          name: 'PermissionService');
      return true;
    } catch (e) {
      developer.log('Error requesting permissions: $e',
          name: 'PermissionService');
      return false;
    }
  }

  // --- Real runtime checks (permission_handler) -----------------------------

  /// Media read access: granular media permissions on Android 13+, the
  /// classic storage permission below that.
  Future<bool> hasMediaAccess() async {
    if (!Platform.isAndroid) return true;
    final videos = await Permission.videos.isGranted;
    final images = await Permission.photos.isGranted;
    if (videos || images) return true;
    // Android <=12 fallback / partial access accepted too
    final partial = await Permission.videos.isLimited ||
        await Permission.photos.isLimited;
    if (partial) return true;
    final legacy = await Permission.storage.isGranted;
    return legacy;
  }

  Future<bool> ensureMediaAccess() async {
    if (!Platform.isAndroid) return true;
    if (await hasMediaAccess()) return true;
    final results = await [
      Permission.videos,
      Permission.photos,
    ].request();
    final ok = results.values
        .any((s) => s.isGranted || s.isLimited);
    if (!ok) {
      // Android <=12: single storage permission covers both
      final legacy = await Permission.storage.request();
      return legacy.isGranted;
    }
    return ok;
  }

  /// All-files access — required to list WhatsApp's hidden `.Statuses`
  /// folder on Android 11+. Opens the system "All files access" page.
  Future<bool> hasAllFilesAccess() async {
    if (!Platform.isAndroid) return true;
    return await Permission.manageExternalStorage.isGranted;
  }

  Future<bool> ensureAllFilesAccess() async {
    if (!Platform.isAndroid) return true;
    if (await hasAllFilesAccess()) return true;
    final result = await Permission.manageExternalStorage.request();
    return result.isGranted;
  }

  /// Notification permission (Android 13+). Older versions are always-on.
  Future<bool> hasNotificationAccess() async {
    if (!Platform.isAndroid) return true;
    return await Permission.notification.isGranted;
  }

  Future<bool> ensureNotificationAccess() async {
    if (!Platform.isAndroid) return true;
    if (await hasNotificationAccess()) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// True when any critical runtime permission is still missing — used to
  /// re-offer the setup flow to users who upgraded from older versions.
  Future<bool> hasMissingCriticalPermissions() async {
    if (!Platform.isAndroid) return false;
    return !(await hasMediaAccess()) || !(await hasAllFilesAccess());
  }

  Future<void> _ensureMediaAccess(BuildContext context) async {
    await _showPermissionDialog(
      context,
      icon: Icons.photo_library_outlined,
      title: 'Akses Media',
      description:
          'Dibutuhkan untuk fitur Simpan Status WhatsApp dan menyimpan media '
          'ke galeri. Izinkan akses foto & video saat diminta.',
      onRequest: ensureMediaAccess,
    );
  }

  Future<void> _ensureAllFilesAccess(BuildContext context) async {
    await _showPermissionDialog(
      context,
      icon: Icons.folder_open,
      title: 'Akses File Lengkap',
      description:
          'Status WhatsApp tersimpan di folder tersembunyi yang hanya bisa '
          'dibaca dengan izin "All files access". Aktifkan pada halaman '
          'pengaturan yang terbuka.',
      onRequest: ensureAllFilesAccess,
    );
  }

  Future<void> _ensureNotificationAccess(BuildContext context) async {
    await _showPermissionDialog(
      context,
      icon: Icons.notifications_active_outlined,
      title: 'Notifikasi',
      description:
          'Untuk menerima info update dan pengumuman penting dari EL-Saver. '
          '(Opsional)',
      isOptional: true,
      onRequest: ensureNotificationAccess,
    );
  }

  // Welcome dialog
  Future<bool> _showWelcomeDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E), // Dark background
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF333333)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.video_library, color: Color(0xFF9B6CFB), size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Welcome to EL-Saver!',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To provide the best experience, we need to set up some permissions:',
                    style: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
                  ),
                  SizedBox(height: 16),
                  _PermissionItem(
                    icon: Icons.folder,
                    title: 'Gallery Access',
                    description: 'Save downloaded media to your gallery',
                  ),
                  _PermissionItem(
                    icon: Icons.install_mobile,
                    title: 'Install Apps',
                    description:
                        'Auto-update the app when new versions are available',
                  ),
                  _PermissionItem(
                    icon: Icons.picture_in_picture,
                    title: 'Picture-in-Picture',
                    description: 'Continue watching while using other apps',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'This will only take a moment and is required for the app to work properly.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFB0B0B0)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB0B0B0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // Request install permission
  Future<bool> _requestInstallPermission(BuildContext context) async {
    return await _showPermissionDialog(
      context,
      icon: Icons.install_mobile,
      title: 'Install Unknown Apps',
      description:
          'Allow EL-Saver to install app updates automatically for seamless updates.',
      onRequest: () async {
        try {
          // Open install unknown apps settings
          const intent = AndroidIntent(
            action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES',
            data: 'package:com.ekalliptus.saver',
          );

          await intent.launch();

          // Show instruction dialog
          await _showInstructionDialog(
            context,
            title: 'Enable Install Permission',
            instruction:
                'Please toggle ON "Allow from this source" in the settings that just opened, then return to the app.',
          );

          return true; // Assume granted after instruction
        } catch (e) {
          developer.log('Failed to open install settings: $e',
              name: 'PermissionService');
          return false;
        }
      },
    );
  }

  // Request PIP permission

  // Generic permission dialog
  Future<bool> _showPermissionDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Future<bool> Function() onRequest,
    bool isOptional = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E), // Dark background
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF333333)),
              ),
              title: Row(
                children: [
                  Icon(icon, color: const Color(0xFF9B6CFB), size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    description,
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
                  ),
                  if (isOptional) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '(This permission is optional)',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB0B0B0)),
                    ),
                  ],
                ],
              ),
              actions: [
                if (isOptional)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade400,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    child: const Text(
                      'Skip',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    final granted = await onRequest();
                    Navigator.of(context).pop(granted);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Grant Permission',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // Instruction dialog
  Future<void> _showInstructionDialog(
    BuildContext context, {
    required String title,
    required String instruction,
  }) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E), // Dark background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF333333)),
          ),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            instruction,
            style: const TextStyle(color: Color(0xFFB0B0B0)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 2,
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Completion dialog
  Future<void> _showCompletionDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E), // Dark background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF333333)),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Setup Complete!',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
          content: const Text(
            'All permissions have been configured. You can now enjoy all features of EL-Saver!',
            style: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 2,
              ),
              child: const Text(
                'Start Using App',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Widget for permission items
class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF9B6CFB)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB0B0B0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
