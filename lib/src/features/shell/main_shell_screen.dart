import 'package:flutter/material.dart';

import 'package:el_saver/src/config/routes_manager.dart';
import 'package:el_saver/src/features/social_videos_downloader/presentation/screens/downloads_screen.dart';
import 'package:el_saver/src/features/social_videos_downloader/presentation/screens/downloader_screen.dart';
import 'package:el_saver/src/features/whatsapp_status/presentation/screens/whatsapp_status_screen.dart';

import '../../core/utils/app_colors.dart';

/// Shown at the bottom of the main shell — the active tab gets a pill
/// highlight with a label, the rest stay icon-only.
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
              color: Colors.black.withValues(
                  alpha: isDark ? 0.4 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                  margin:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryColor.withValues(alpha: 0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: active ? 22 : 20,
                        color: active
                            ? AppColors.primaryColor
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.45)),
                      ),
                      const SizedBox(height: 2),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: active ? 1.0 : 0.0,
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryColor,
                          ),
                        ),
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

/// Main shell with an IndexedStack of the four main tabs — a single
/// scaffold keeps every tab's scroll position & state alive while the
/// floating nav swaps the visible page.
class MainShellScreen extends StatefulWidget {
  final int initialTab;
  const MainShellScreen({super.key, this.initialTab = 0});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _current = widget.initialTab;

  static final List<Widget> _pages = [
    // Home downloader tab (shell owns the bottom nav).
    _Embed(child: const DownloaderScreen(embedded: true)),
    DownloadsScreen(),
    WhatsappStatusScreen(),
    // Akun tab.
    const _AccountsEmbed(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _current, children: _pages),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _current,
        onTap: (i) => setState(() => _current = i),
      ),
    );
  }
}

/// Keep pages const where they are self-contained.
class _Embed extends StatelessWidget {
  final Widget child;
  const _Embed({required this.child});

  @override
  Widget build(BuildContext context) => child;
}

class _AccountsEmbed extends StatelessWidget {
  const _AccountsEmbed();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) => AppRounter.getRoute(
          const RouteSettings(name: Routes.accounts)),
    );
  }
}
