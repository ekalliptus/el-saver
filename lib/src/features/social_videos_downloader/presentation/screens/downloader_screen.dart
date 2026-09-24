// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../../config/routes_manager.dart';
import '../widgets/downloader_Screen/downloader_screen_body.dart';
import '../widgets/downloader_Screen/downloader_screen_bottom_app_bar.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const DownloaderScreenBody(),
      bottomNavigationBar: DownloaderBottomAppBar(
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
