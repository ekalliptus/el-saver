// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:el_saver/src/core/media_query.dart';

import '../../../../../core/utils/app_colors.dart';
import 'animated_toggle_button.dart';

class DownloaderBottomAppBar extends StatelessWidget {
  final VoidCallback? onAccountsPressed;
  final VoidCallback? onStatusPressed;

  const DownloaderBottomAppBar({
    super.key,
    this.onAccountsPressed,
    this.onStatusPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        width: context.width * 0.9,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.scaffoldBackgroundColorDark.withOpacity(0.95),
                    AppColors.scaffoldBackgroundColorDark.withOpacity(0.85),
                  ]
                : [
                    AppColors.white.withOpacity(0.95),
                    AppColors.white.withOpacity(0.85),
                  ],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: AppColors.primaryColor.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BuildActionButton(
                icon: Icons.motion_photos_on_rounded,
                onPressed: onStatusPressed ?? () {},
                isDark: isDark,
                tooltip: 'Status WhatsApp',
                isSecondary: true,
              ),
              const Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: AnimatedToggleButton(),
                ),
              ),
              _BuildActionButton(
                icon: Icons.person_rounded,
                onPressed: onAccountsPressed ?? () {},
                isDark: isDark,
                tooltip: 'Accounts',
                isSecondary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDark;
  final String? tooltip;
  final bool isSecondary;

  const _BuildActionButton({
    required this.icon,
    required this.onPressed,
    required this.isDark,
    this.tooltip,
    required this.isSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: isSecondary ? 40 : 48,
          height: isSecondary ? 40 : 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isSecondary
                  ? [
                      AppColors.primaryColor.withOpacity(0.08),
                      AppColors.primaryColor.withOpacity(0.05),
                    ]
                  : [
                      AppColors.primaryColor.withOpacity(0.15),
                      AppColors.primaryColor.withOpacity(0.08),
                    ],
            ),
            border: Border.all(
              color:
                  AppColors.primaryColor.withOpacity(isSecondary ? 0.15 : 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.1),
                blurRadius: isSecondary ? 4 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: AppColors.primaryColor,
            size: isSecondary ? 18 : 22,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
