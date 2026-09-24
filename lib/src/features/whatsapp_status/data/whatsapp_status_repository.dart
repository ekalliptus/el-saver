import 'dart:io';

import '../../../core/helpers/dir_helper.dart';

/// One WhatsApp status entry found on disk (image or video).
class StatusFile {
  final String path;
  final bool isVideo;
  final DateTime modified;

  const StatusFile({
    required this.path,
    required this.isVideo,
    required this.modified,
  });
}

/// Scans WhatsApp's internal status cache directories and exposes statuses
/// as saveable media. Works on the modern `/Android/media/` layout (WA and
/// WA Business) and the legacy pre-Android-11 root layout.
class WhatsappStatusRepository {
  static const _statusDirs = [
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp/Media/.Statuses',
    '/storage/emulated/0/WhatsApp/Media/.Statuses',
  ];

  static const _videoExtensions = ['.mp4'];
  static const _imageExtensions = ['.jpg', '.jpeg', '.png', '.webp'];

  /// Returns all visible statuses, newest first. Empty list when WhatsApp is
  /// not installed or no status has been viewed yet (the folders are hidden
  /// or absent).
  Future<List<StatusFile>> scan() async {
    final results = <StatusFile>[];
    for (final dirPath in _statusDirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      try {
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          final name = entity.path.split(Platform.pathSeparator).last;
          final lower = name.toLowerCase();
          if (name.startsWith('.')) continue;
          final isVideo =
              _videoExtensions.any((e) => lower.endsWith(e));
          final isImage =
              _imageExtensions.any((e) => lower.endsWith(e));
          if (!isVideo && !isImage) continue;
          try {
            final stat = entity.statSync();
            if (stat.size == 0) continue;
            results.add(StatusFile(
              path: entity.path,
              isVideo: isVideo,
              modified: stat.modified,
            ));
          } on FileSystemException {
            continue;
          }
        }
      } on FileSystemException {
        // Access issue on this dir; try the next one.
        continue;
      }
    }
    results.sort((a, b) => b.modified.compareTo(a.modified));
    return results;
  }

  /// Saves one status into the device gallery (EL-Saver album).
  /// [DirHelper.saveMediaToGallery] handles type detection + permissions.
  Future<void> save(String filePath) =>
      DirHelper.saveMediaToGallery(filePath);
}
