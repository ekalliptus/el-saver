// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:el_saver/src/container_injector.dart' show sl;
import 'package:el_saver/src/core/media_query.dart';
import 'package:el_saver/src/core/services/premium_service.dart';
import 'package:el_saver/src/core/widgets/premium_dialog.dart';
import 'package:el_saver/src/features/social_videos_downloader/presentation/widgets/downloader_Screen/downloader_screen_supported_platforms.dart';
import 'package:el_saver/src/features/social_videos_downloader/presentation/widgets/downloader_Screen/language_switcher.dart';

import '../../../../../config/routes_manager.dart';
import '../../../../../core/common_widgets/app_background.dart';
import '../../../../../core/common_widgets/toast.dart';
import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_enums.dart';
import '../../../../../core/utils/app_strings.dart';
import '../../../../../core/providers/language_provider.dart';
import '../../../domain/entities/download_item.dart';
import '../../bloc/downloader_bloc/downloader_bloc.dart';
import 'downloader_screen_input_field.dart';
import 'appbar_downloader.dart';

class DownloaderScreenBody extends StatefulWidget {
  const DownloaderScreenBody({super.key});

  @override
  State<DownloaderScreenBody> createState() => _DownloaderScreenBodyState();
}

class _DownloaderScreenBodyState extends State<DownloaderScreenBody> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController videoLinkController = TextEditingController();
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    if (!sl<PremiumService>().isPremium) _loadBannerAd();
  }

  Future<void> _showLoginRequired(
      BuildContext context, DownloaderAuthRequired state) async {
    final platformName = DownloadItem.platformNameOf(state.platform);
    final login = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.lock_person_outlined, size: 40),
        title: Text('Login dulu ke $platformName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$platformName menolak video diambil tanpa sesi login. '
              'Ini aturan platformnya (konten private atau pembatasan bot), '
              'bukan gangguan di aplikasi.',
            ),
            const SizedBox(height: 12),
            Text(
              'Login sekali lewat situs resmi $platformName di aplikasi ini. '
              'Sesinya dipakai khusus untuk mengambil video, dan kamu bisa '
              'logout kapan saja.',
            ),
            const SizedBox(height: 12),
            Text(state.message,
                style: Theme.of(dialogContext).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Nanti'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.login, size: 18),
            label: Text('Login ke $platformName'),
          ),
        ],
      ),
    );
    if (login != true || !context.mounted) return;
    final success = await Navigator.of(context).pushNamed(
      Routes.webviewLogin,
      arguments: state.platform,
    );
    if (success == true && context.mounted) {
      context.read<DownloaderBloc>().add(DownloaderGetVideo(state.sourceUrl));
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-9374589831001594/1262943956',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: context.width,
          height: context.height / 2.2,
          decoration: const BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
        ),
        SafeArea(
          child: BlocConsumer<DownloaderBloc, DownloaderState>(
            listener: (context, state) {
              // The download bottom sheet (opened from the input field) owns the
              // skeleton + quality picker lifecycle and listens to the bloc
              // itself. Here we only handle toasts and login.
              if (state is DownloaderGetVideoFailure) {
                buildToast(msg: state.message, type: ToastType.error);
              }
              if (state is DownloaderAuthRequired) {
                _showLoginRequired(context, state);
              }
              if (state is DownloaderGetVideoSuccess &&
                  state.video.videoLinks.isEmpty) {
                buildToast(msg: state.video.message!, type: ToastType.error);
              }
              if (state is DownloaderSaveVideoSuccess) {
                buildToast(msg: state.message, type: ToastType.success);
              }
              if (state is DownloaderSaveVideoFailure) {
                buildToast(msg: state.message, type: ToastType.error);
              }
            },
            builder: (context, state) {
              return Stack(
                children: [
                  const AppBackground(heightRatio: 1.5),
                  // Use Consumer to rebuild when language changes
                  Consumer<LanguageProvider>(
                    builder: (context, _, __) {
                      return Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  SizedBox(height: context.height * 0.02),
                                  AppBarWithLogo(
                                    action: _PremiumButton(
                                      isPremium:
                                          sl<PremiumService>().isPremium,
                                      onPressed: () =>
                                          showPremiumDialog(
                                        context,
                                        premium: sl<PremiumService>(),
                                        isPremium:
                                            sl<PremiumService>().isPremium,
                                        onPremiumChanged: () {
                                          setState(() {
                                            _bannerAd?.dispose();
                                            _bannerAd = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: context.height * 0.03),
                                  DownloaderScreenInputField(
                                    videoLinkController: videoLinkController,
                                    formKey: formKey,
                                  ),
                                  SizedBox(height: context.height * 0.03),
                                  const DownloaderScreenSupportedPlatforms(),
                                  SizedBox(height: context.height * 0.025),
                                  _RecentDownloadsSection(
                                    downloads: context
                                        .read<DownloaderBloc>()
                                        .newDownloads,
                                  ),
                                  SizedBox(height: context.height * 0.015),
                                  // AdMob Banner
                                  if (_bannerAd != null)
                                    Container(
                                      alignment: Alignment.center,
                                      width: _bannerAd!.size.width.toDouble(),
                                      height: _bannerAd!.size.height.toDouble(),
                                      child: AdWidget(ad: _bannerAd!),
                                    ),
                                  SizedBox(height: context.height * 0.015),
                                ],
                              ),
                            ),
                          ),
                          // Language switcher always at bottom
                          const LanguageSwitcher(),
                          SizedBox(height: context.height * 0.01),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentDownloadsSection extends StatelessWidget {
  final List<DownloadItem> downloads;
  const _RecentDownloadsSection({required this.downloads});

  @override
  Widget build(BuildContext context) {
    // Newest first, capped at 3: a new download shows on top and pushes the
    // oldest of the three off the list.
    final sorted = [...downloads]
      ..sort((a, b) => b.downloadTime.compareTo(a.downloadTime));
    final recent = sorted.take(3).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.width * 0.05),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.recentDownloads,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed(Routes.downloads),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.viewAll,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                AppStrings.noDownloadsYet,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 13),
              ),
            )
          else
            ...recent.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _RecentTile(item: item),
                )),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final DownloadItem item;
  const _RecentTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(Routes.downloads),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(_icon, color: _color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.videoTitle.isNotEmpty ? item.videoTitle : item.video.title,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.platformName,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    switch (item.status) {
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.success:
        return Icons.check_circle;
      case DownloadStatus.error:
        return Icons.error;
      case DownloadStatus.paused:
        return Icons.pause_circle;
    }
  }

  Color get _color {
    switch (item.status) {
      case DownloadStatus.downloading:
        return AppColors.primaryColor;
      case DownloadStatus.success:
        return AppColors.green;
      case DownloadStatus.error:
        return AppColors.red;
      case DownloadStatus.paused:
        return Colors.orange;
    }
  }
}

/// Crown chip in the app bar; shows Premium state and opens the paywall.
class _PremiumButton extends StatelessWidget {
  final bool isPremium;
  final VoidCallback onPressed;

  const _PremiumButton({required this.isPremium, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (isPremium) {
      return Tooltip(
        message: 'Premium aktif',
        child: Icon(Icons.verified_rounded,
            color: AppColors.green, size: 26),
      );
    }
    return Tooltip(
      message: 'Beli Premium - tanpa iklan',
      child: IconButton(
        onPressed: onPressed,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.workspace_premium,
                color: Colors.white, size: 26),
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
