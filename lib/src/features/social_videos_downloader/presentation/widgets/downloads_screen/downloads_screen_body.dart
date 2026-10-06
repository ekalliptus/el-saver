import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../../../core/utils/app_strings.dart';
import '../../screens/downloads_screen.dart';
import '../../bloc/downloader_bloc/downloader_bloc.dart';
import 'new_downloads_section.dart';
import 'old_downloads_section.dart';

class DownloadsScreenBody extends StatelessWidget {
  final SortOption selectedSort;
  final SocialPlatform? selectedPlatform;

  const DownloadsScreenBody({
    super.key,
    required this.selectedSort,
    required this.selectedPlatform,
  });

  @override
  Widget build(BuildContext context) {
    // Rebuild on any bloc state so the empty state tracks live list changes.
    return BlocBuilder<DownloaderBloc, DownloaderState>(
      builder: (context, _) {
        final bloc = context.read<DownloaderBloc>();
        final hasNew = bloc.newDownloads.isNotEmpty;
        // Old (untracked) files cannot be matched to a platform, so a
        // platform filter hides that section entirely.
        final showOld = selectedPlatform == null;
        final hasOld = showOld && bloc.oldDownloads.isNotEmpty;

        if (!hasNew && !hasOld) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_done_outlined,
                    size: 64,
                    color: AppColors.primaryColor.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text(AppStrings.noDownloadsYet,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              NewDownloadsSection(
                selectedSort: selectedSort,
                selectedPlatform: selectedPlatform,
              ),
              if (showOld)
                const Divider(
                    color: AppColors.primaryColor, thickness: .1, height: 10),
              if (showOld)
                OldDownloadsSection(
                  selectedSort: selectedSort,
                  selectedPlatform: selectedPlatform,
                ),
            ],
          ),
        );
      },
    );
  }
}
