// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:el_saver/src/core/utils/app_colors.dart';
import 'package:el_saver/src/core/utils/app_strings.dart';
import 'package:el_saver/src/core/providers/language_provider.dart';
import '../../../../config/routes_manager.dart';
import '../widgets/downloader_Screen/downloader_screen_body.dart';
import '../widgets/downloader_Screen/downloader_screen_bottom_app_bar.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  Future<void> _handleDonation() async {
    try {
      _showDonationDialog();
    } catch (e) {
      // If dialog fails to show, show a snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to show donation: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showDonationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final cardColor = theme.cardColor;
        final fgColor = theme.textTheme.bodyMedium?.color ?? Colors.white;
        final mutedColor = isDark
            ? AppColors.mutedForegroundDark
            : AppColors.mutedForegroundLight;
        return Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryColor,
                            AppColors.accentViolet
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite,
                              color: Colors.white, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.supportDeveloper,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  AppStrings.helpKeepAppFree,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            AppStrings.scanQrisCode,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: fgColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            AppStrings.useIndonesianEWallet,
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),

                          // QRIS Image
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: isDark
                                      ? AppColors.borderDark
                                      : AppColors.borderLight,
                                  width: 2),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.asset(
                                'assets/donate/donate.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: isDark
                                        ? AppColors.inputDark
                                        : AppColors.inputLight,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error_outline,
                                            color: mutedColor, size: 40),
                                        const SizedBox(height: 10),
                                        Text(AppStrings.qrisImageNotFound,
                                            style:
                                                TextStyle(color: mutedColor)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Supported apps
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: [
                              _buildPaymentChip('GoPay', theme),
                              _buildPaymentChip('OVO', theme),
                              _buildPaymentChip('DANA', theme),
                              _buildPaymentChip('ShopeePay', theme),
                              _buildPaymentChip('LinkAja', theme),
                              _buildPaymentChip('Bank Apps', theme),
                            ],
                          ),

                          const SizedBox(height: 20),

                          Text(
                            AppStrings.thankYouSupport,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: mutedColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentChip(String name, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 10,
          color: AppColors.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const DownloaderScreenBody(),
      bottomNavigationBar: DownloaderBottomAppBar(
        onSharePressed: _handleDonation,
        onAccountsPressed: () {
          Navigator.of(context).pushNamed(Routes.accounts);
        },
        onStatusPressed: () {
          Navigator.of(context).pushNamed(Routes.whatsappStatus);
        },
      ),
    );
  }
}
