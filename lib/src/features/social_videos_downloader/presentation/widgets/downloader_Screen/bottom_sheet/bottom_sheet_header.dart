import 'package:flutter/material.dart';

import '../../../../../../core/utils/app_strings.dart';
import '../../../../domain/entities/video.dart';

class BottomSheetHeader extends StatelessWidget {
  final Video videoData;

  const BottomSheetHeader({super.key, required this.videoData});

  bool _isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return false;
    }

    try {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
        return false;
      }
      return ['http', 'https'].contains(uri.scheme.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Video thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 120,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
            child: _isValidImageUrl(videoData.picture)
                ? Image.network(
                    videoData.picture!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.video_library,
                          size: 40,
                          color: Colors.grey,
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.video_library,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Video title
        Text(
          videoData.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        // Quality options info
        Text(
          AppStrings.qualityOptionsAvailable(videoData.videoLinks.length),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
