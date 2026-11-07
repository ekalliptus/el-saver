import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:el_saver/src/core/media_query.dart';
import '../../../../../core/common_widgets/container_with_shadows.dart';
import '../../../../../core/services/language_service.dart';
import '../../../../../core/providers/language_provider.dart';
import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_strings.dart';
import '../../../../../core/utils/styles_manager.dart';

class LanguageSwitcher extends StatefulWidget {
  const LanguageSwitcher({super.key});

  @override
  State<LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<LanguageSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return ContainerWithShadows(
          widthMultiplier: 0.9,
          heightMultiplier: 0.15,
          applyGradient: false,
          child: Padding(
            padding: EdgeInsets.all(context.height * 0.015),
            child: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    AppStrings.language,
                    textAlign: TextAlign.center,
                    style: getTitleStyle(
                      fontSize: context.width * 0.045,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: SupportedLanguage.values.map((language) {
                      return _buildLanguageOption(
                          language, languageProvider.currentLanguage);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
      SupportedLanguage language, SupportedLanguage currentLanguage) {
    final isSelected = currentLanguage == language;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onLanguageTap(language),
        onTapDown: (_) => _animationController.forward(),
        onTapUp: (_) => _animationController.reverse(),
        onTapCancel: () => _animationController.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isSelected ? 1.0 : _scaleAnimation.value,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: context.width * 0.01),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryColor
                        : Colors.grey.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                // scaleDown: on short screens flag+name exceed the fixed
                // option height and would overflow — shrink to fit instead.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        language.flag,
                        style: TextStyle(
                          fontSize: context.width * 0.08,
                        ),
                      ),
                      SizedBox(height: context.height * 0.005),
                      Text(
                        language.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: context.width * 0.025,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? AppColors.primaryColor
                              : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onLanguageTap(SupportedLanguage language) async {
    final currentLanguage = context.read<LanguageProvider>().currentLanguage;
    if (currentLanguage == language) return;

    // Haptic feedback
    HapticFeedback.selectionClick();

    try {
      // Change language using provider
      await context.read<LanguageProvider>().changeLanguage(language);

      // UI will be updated automatically by Consumer
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(language.flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    language == SupportedLanguage.indonesian
                        ? 'Bahasa berhasil diubah ke ${language.name}'
                        : 'Language changed to ${language.name}',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primaryColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      // Error handling
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language == SupportedLanguage.indonesian
                  ? 'Gagal mengubah bahasa. Silakan coba lagi.'
                  : 'Failed to change language. Please try again.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
