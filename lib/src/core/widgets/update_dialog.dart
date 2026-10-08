// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../common_widgets/fancy_loader.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final UpdateService updateService;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.updateService,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum _Phase { info, downloading, waitingInstaller, error }

class _UpdateDialogState extends State<UpdateDialog> {
  _Phase _phase = _Phase.info;
  double _progress = 0;
  String _errorMsg = "";
  String? _apkPath;
  Future<void> _startDownload() async {
    setState(() => _phase = _Phase.downloading);

    final path = await widget.updateService.downloadUpdate(
      widget.updateInfo.downloadUrl,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;

    if (path == null) {
      setState(() {
        _phase = _Phase.error;
        _errorMsg = AppStrings.downloadFailedRetry;
      });
      return;
    }

    _apkPath = path;
    // Manual install only: hand the APK to the system package installer and
    // wait for the user to finish the popup flow.
    setState(() => _phase = _Phase.waitingInstaller);
    final opened = await widget.updateService.installUpdateManual(path);

    if (!mounted) return;
    if (!opened) {
      setState(() {
        _phase = _Phase.error;
        _errorMsg = AppStrings.cannotOpenSystemInstaller;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final fgColor = theme.textTheme.bodyMedium?.color ?? Colors.white;
    final mutedColor =
        isDark ? AppColors.mutedForegroundDark : AppColors.mutedForegroundLight;

    return Dialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(),
            const SizedBox(height: 16),
            _buildTitle(fgColor),
            const SizedBox(height: 8),
            _buildSubtitle(mutedColor),
            const SizedBox(height: 16),
            _buildBody(mutedColor),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (_phase) {
      case _Phase.info:
        return const Icon(Icons.system_update,
            color: AppColors.primaryColor, size: 48);
      case _Phase.downloading:
        return const FancyLoader(size: 40);
      case _Phase.waitingInstaller:
        return const FancyLoader(size: 40, color: Colors.orange);
      case _Phase.error:
        return Container(
          width: 48,
          height: 48,
          decoration:
              const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
          child: const Icon(Icons.close, color: Colors.white, size: 28),
        );
    }
  }

  Widget _buildTitle(Color fgColor) {
    final titles = {
      _Phase.info: AppStrings.updateAvailable,
      _Phase.downloading: AppStrings.downloadingUpdate,
      _Phase.waitingInstaller: AppStrings.waitingForInstaller,
      _Phase.error: AppStrings.failed,
    };
    return Text(
      titles[_phase]!,
      style:
          TextStyle(color: fgColor, fontSize: 18, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildSubtitle(Color mutedColor) {
    final info = widget.updateInfo;
    if (_phase == _Phase.downloading) {
      return Text(
        "${(_progress * 100).toInt()}%",
        style: TextStyle(
            color: AppColors.primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w700),
      );
    }
    if (_phase == _Phase.error) {
      return Text(_errorMsg,
          textAlign: TextAlign.center,
          style: TextStyle(color: mutedColor, fontSize: 13));
    }
    if (_phase == _Phase.waitingInstaller) {
      return Text(
        AppStrings.installerPopupInstruction,
        textAlign: TextAlign.center,
        style: TextStyle(color: mutedColor, fontSize: 13),
      );
    }
    return Text(
      AppStrings.versionUpgrade(info.currentVersionName, info.versionName),
      style: TextStyle(color: mutedColor, fontSize: 13),
    );
  }

  Widget _buildBody(Color mutedColor) {
    final info = widget.updateInfo;

    switch (_phase) {
      case _Phase.info:
        return Column(
          children: [
            if (info.changelog.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mutedColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(info.changelog,
                    style: TextStyle(color: mutedColor, fontSize: 12)),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(AppStrings.downloadAndInstall),
              ),
            ),
            if (!info.isForced) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  widget.updateService.dismiss(info.versionName);
                  Navigator.pop(context);
                },
                child:
                    Text(AppStrings.later, style: TextStyle(color: mutedColor)),
              ),
            ],
          ],
        );

      case _Phase.downloading:
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 6,
                backgroundColor: mutedColor.withOpacity(0.1),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.doNotCloseThisDialog,
              style: TextStyle(color: mutedColor, fontSize: 11),
            ),
          ],
        );

      case _Phase.waitingInstaller:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _openSystemInstaller,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryColor,
                  side: BorderSide(
                      color: AppColors.primaryColor.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(AppStrings.reopenInstaller),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text(AppStrings.close, style: TextStyle(color: mutedColor)),
            ),
          ],
        );

      case _Phase.error:
        return Column(
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _phase = _Phase.info),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryColor,
                      side: BorderSide(
                          color: AppColors.primaryColor.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(AppStrings.tryAgain),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: _openSystemInstaller,
                    child: Text(AppStrings.installManually,
                        style: TextStyle(color: mutedColor)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Always leave an exit: a broken download URL must never trap
            // the user in this dialog.
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.close, style: TextStyle(color: mutedColor)),
            ),
          ],
        );
    }
  }

  /// Re-open the system installer if the user dismissed the popup.
  Future<void> _openSystemInstaller() async {
    final path = _apkPath;
    if (path == null || !await File(path).exists()) return;
    try {
      await widget.updateService.installUpdateManual(path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.cannotOpenInstaller)),
        );
      }
    }
  }
}
