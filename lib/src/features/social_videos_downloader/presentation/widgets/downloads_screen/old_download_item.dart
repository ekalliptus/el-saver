// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;

import '../../../../../core/helpers/dir_helper.dart';
import '../../../../../core/utils/app_assets.dart';
import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_strings.dart';
import '../../../domain/entities/video_item.dart';
import '../../bloc/downloader_bloc/downloader_bloc.dart';
import 'media_actions.dart';
import 'save_to_gallery_dialog.dart';

class OldDownloadItem extends StatelessWidget {
  final VideoItem videoItem;

  const OldDownloadItem({super.key, required this.videoItem});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: _buildThumbnail(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced title extraction
                Text(
                  _extractTitleFromFilename(videoItem.path),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // File info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "● ${AppStrings.downloaded}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getFileModifiedTime(videoItem.path),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _getFileSize(videoItem.path),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Action buttons similar to new downloads success state
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.open_in_new_rounded,
                        color: AppColors.primaryColor,
                        tooltip: AppStrings.openDownloadedFile,
                        onPressed: () =>
                            openDownloadedMedia(context, videoItem.path),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.save_alt_rounded,
                        color: AppColors.green,
                        onPressed: () =>
                            _saveToGallery(context, videoItem.path),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.delete,
                        color: AppColors.red,
                        tooltip: AppStrings.deleteFile,
                        onPressed: () =>
                            _confirmDelete(context, videoItem.path),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    final type = DirHelper.mediaTypeOf(videoItem.path);
    if (type == MediaFileType.image && File(videoItem.path).existsSync()) {
      return Image.file(
        File(videoItem.path),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (type == MediaFileType.video &&
        videoItem.thumbnailPath != null &&
        File(videoItem.thumbnailPath!).existsSync()) {
      return Image.file(
        File(videoItem.thumbnailPath!),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (type == MediaFileType.audio) {
      return const Icon(Icons.audio_file_rounded, size: 36);
    }
    if (type == MediaFileType.unsupported) {
      return const Icon(Icons.insert_drive_file_rounded, size: 36);
    }
    return _placeholder();
  }

  Widget _placeholder() => Image.asset(
        AppAssets.noInternetImage,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      );

  String _extractTitleFromFilename(String filePath) {
    try {
      // Get filename without extension
      String filename = path.basenameWithoutExtension(filePath);

      // Remove timestamp patterns (if any)
      filename = filename.replaceAll(
          RegExp(r'_\d{13}'), ''); // Remove 13-digit timestamps
      filename = filename.replaceAll(
          RegExp(r'_\d{10}'), ''); // Remove 10-digit timestamps

      // Handle special filename patterns
      if (filename.contains('Image_')) {
        return "RedNote ${filename.replaceAll('_', ' ')}";
      }

      // Replace underscores with spaces and clean up
      filename = filename.replaceAll('_', ' ');

      // Limit length
      if (filename.length > 50) {
        filename = "${filename.substring(0, 47)}...";
      }

      return filename.isNotEmpty ? filename : AppStrings.downloadedVideo;
    } catch (e) {
      return AppStrings.downloadedVideo;
    }
  }

  String _getFileSize(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        if (bytes < 1073741824) {
          return '${(bytes / 1048576).toStringAsFixed(1)} MB';
        }
        return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
      }
    } catch (e) {
      // Handle error
    }
    return AppStrings.unknownSize;
  }

  String _getFileModifiedTime(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        final lastModified = file.lastModifiedSync();
        return '${lastModified.toString().split(' ')[0]} ${lastModified.toString().split(' ')[1].substring(0, 5)}';
      }
    } catch (e) {
      // Handle error
    }
    return AppStrings.unknownTime;
  }

  void _saveToGallery(BuildContext context, String videoPath) {
    SaveToGalleryDialog.show(context, videoPath);
  }

  void _confirmDelete(BuildContext context, String filePath) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.deleteFile),
        content: Text(AppStrings.deleteFilePermanentlyMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteFile(context, filePath);
            },
            child: Text(AppStrings.delete,
                style: const TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteFile(BuildContext context, String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
    // Refresh the old-downloads list from disk.
    context.read<DownloaderBloc>().add(LoadOldDownloads());
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
