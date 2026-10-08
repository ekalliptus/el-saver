import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/app_colors.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/styles_manager.dart';
import '../../../../core/utils/app_strings.dart';
import '../../../../core/providers/language_provider.dart';
import '../widgets/downloads_screen/downloads_screen_body.dart';
import '../bloc/downloader_bloc/downloader_bloc.dart';
import '../../domain/entities/download_item.dart';

enum SortOption { newest, oldest, platform }

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  SortOption selectedSort = SortOption.newest;
  SocialPlatform? selectedPlatform;

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              AppStrings.downloads,
              textAlign: TextAlign.center,
              style: getTitleStyle(
                color: AppColors.white,
              ),
            ),
            actions: [
              BlocBuilder<DownloaderBloc, DownloaderState>(
                builder: (context, state) {
                  final newDownloads =
                      context.read<DownloaderBloc>().newDownloads;
                  final oldDownloads =
                      context.read<DownloaderBloc>().oldDownloads;

                  // Apply filters
                  final filteredNewDownloads = _applyFilters(newDownloads);
                  final totalDownloads =
                      filteredNewDownloads.length + oldDownloads.length;

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        IconButton(
                          onPressed: () {
                            _showFilterBottomSheet(context);
                          },
                          icon: const Icon(
                            Icons.filter_list,
                            color: AppColors.white,
                          ),
                          tooltip: AppStrings.filterSort,
                        ),
                        if (totalDownloads > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                totalDownloads.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: DownloadsScreenBody(
            selectedSort: selectedSort,
            selectedPlatform: selectedPlatform,
          ),
        );
      },
    );
  }

  List<DownloadItem> _applyFilters(List<DownloadItem> downloads) {
    List<DownloadItem> filtered = List.from(downloads);

    // Apply platform filter
    if (selectedPlatform != null) {
      filtered =
          filtered.where((item) => item.platform == selectedPlatform).toList();
    }

    // Apply sorting
    switch (selectedSort) {
      case SortOption.newest:
        filtered.sort((a, b) => b.downloadTime.compareTo(a.downloadTime));
        break;
      case SortOption.oldest:
        filtered.sort((a, b) => a.downloadTime.compareTo(b.downloadTime));
        break;
      case SortOption.platform:
        filtered.sort((a, b) => a.platformName.compareTo(b.platformName));
        break;
    }

    return filtered;
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          minHeight: 200,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        AppStrings.filterSortDownloads,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sort Options
                    Text(
                      AppStrings.sortBy,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...SortOption.values.map((sort) => _buildSortOption(sort)),

                    const SizedBox(height: 20),

                    // Platform Filter
                    Text(
                      AppStrings.filterByPlatform,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildPlatformOption(null, AppStrings.allPlatforms),
                    ...SocialPlatform.values.map((platform) =>
                        _buildPlatformOption(
                            platform, _getPlatformName(platform))),

                    // Bottom padding for safe area
                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(SortOption sort) {
    final isSelected = selectedSort == sort;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? AppColors.primaryColor : Colors.grey,
      ),
      title: Text(_getSortLabel(sort)),
      onTap: () {
        setState(() {
          selectedSort = sort;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildPlatformOption(SocialPlatform? platform, String label) {
    final isSelected = selectedPlatform == platform;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? AppColors.primaryColor : Colors.grey,
      ),
      title: Text(label),
      onTap: () {
        setState(() {
          selectedPlatform = platform;
        });
        Navigator.pop(context);
      },
    );
  }

  String _getSortLabel(SortOption sort) {
    switch (sort) {
      case SortOption.newest:
        return AppStrings.newestFirst;
      case SortOption.oldest:
        return AppStrings.oldestFirst;
      case SortOption.platform:
        return AppStrings.byPlatform;
    }
  }

  String _getPlatformName(SocialPlatform platform) {
    return DownloadItem.platformNameOf(platform);
  }
}
