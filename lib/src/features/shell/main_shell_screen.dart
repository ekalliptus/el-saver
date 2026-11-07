import 'package:flutter/material.dart';

import 'package:el_saver/src/config/routes_manager.dart';
import 'package:el_saver/src/features/social_videos_downloader/presentation/screens/downloads_screen.dart';
import 'package:el_saver/src/features/social_videos_downloader/presentation/screens/downloader_screen.dart';
import 'package:el_saver/src/features/whatsapp_status/presentation/screens/whatsapp_status_screen.dart';

import 'floating_nav_bar.dart';

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
