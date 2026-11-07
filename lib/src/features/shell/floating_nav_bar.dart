import 'package:flutter/material.dart';

import '../../core/utils/app_colors.dart';

/// Shown at the bottom of the main shell — the active tab gets a pill
/// highlight with a label, the rest stay icon-only but always visible.
class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (icon: Icons.home_rounded, label: 'Beranda'),
    (icon: Icons.download_rounded, label: 'Unduhan'),
    (icon: Icons.photo_library_rounded, label: 'Status'),
    (icon: Icons.person_rounded, label: 'Akun'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveIcon =
        isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.45);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: AppColors.primaryColor.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final active = i == currentIndex;
            final item = _items[i];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  height: 44,
                  margin: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryColor
                            .withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon is ALWAYS visible; only its colour/size animate.
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          item.icon,
                          size: active ? 22 : 20,
                          color: active
                              ? AppColors.primaryColor
                              : inactiveIcon,
                        ),
                      ),
                      // Label only occupies space when active, so the
                      // pill grows around icon+text and icons never vanish.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: active
                            ? Padding(
                                padding:
                                    const EdgeInsets.only(left: 6),
                                child: Text(
                                  item.label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              )
                            : const SizedBox(width: 0),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
