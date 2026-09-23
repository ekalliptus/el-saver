import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Video frame extraction via the native `video_thumbnail` method channel
/// (MediaMetadataRetriever on Android, implemented in MainActivity).
/// Replaces the unmaintained `video_thumbnail` pub package whose Android
/// build script (jcenter) no longer works with Gradle 9.
class VideoThumbnail {
  static const _channel = MethodChannel('video_thumbnail');

  static Future<String?> thumbnailFile({
    required String video,
    String? thumbnailPath,
    int quality = 50,
    int maxWidth = 0,
  }) async {
    try {
      final dir = thumbnailPath ?? (await getTemporaryDirectory()).path;
      final result = await _channel.invokeMethod<String>('thumbnailFile', {
        'video': video,
        'maxWidth': maxWidth,
        'quality': quality,
      });
      if (result == null) return null;
      return File(result).parent.path == File(result).path
          ? result
          : _moveInto(result, dir);
    } on PlatformException {
      return null;
    }
  }

  static String? _moveInto(String generatedPath, String targetDir) {
    if (File(generatedPath).parent.path == targetDir) return generatedPath;
    final target = File(
      '$targetDir/${File(generatedPath).uri.pathSegments.last}',
    );
    try {
      return File(generatedPath).renameSync(target.path).path;
    } on FileSystemException {
      return generatedPath;
    }
  }
}
