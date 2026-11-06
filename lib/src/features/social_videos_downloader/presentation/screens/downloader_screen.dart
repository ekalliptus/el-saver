// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../../config/routes_manager.dart';
import '../widgets/downloader_Screen/downloader_screen_body.dart';
import '../widgets/downloader_Screen/downloader_screen_bottom_app_bar.dart';

class DownloaderScreen extends StatefulWidget {
  /// When embedded in MainShellScreen the shell owns the bottom nav;
  /// standalone (old entry points) keeps this screen's floating bar.
  final bool embedded;
  const DownloaderScreen({super.key, this.embedded = false});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const DownloaderScreenBody(),
      bottomNavigationBar: widget.embedded
          ? null
          : DownloaderBottomAppBar(
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
