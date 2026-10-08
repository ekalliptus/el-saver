// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/helpers/dir_helper.dart';
import '../../../../../core/utils/app_strings.dart';

enum _SaveState { saving, success, error }

class SaveToGalleryDialog extends StatefulWidget {
  final String filePath;
  const SaveToGalleryDialog({super.key, required this.filePath});

  static void show(BuildContext context, String filePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => SaveToGalleryDialog(filePath: filePath),
    );
  }

  @override
  State<SaveToGalleryDialog> createState() => _SaveToGalleryDialogState();
}

class _SaveToGalleryDialogState extends State<SaveToGalleryDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleIn;
  _SaveState _state = _SaveState.saving;
  String _errorMsg = "";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleIn = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
    _doSave();
  }

  Future<void> _doSave() async {
    try {
      await DirHelper.saveMediaToGallery(widget.filePath);
      if (mounted) setState(() => _state = _SaveState.success);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _SaveState.error;
          _errorMsg = e.toString().replaceAll("Exception: ", "");
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleIn,
      child: Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: _buildIcon(),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _label,
                  key: ValueKey(_state),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_state == _SaveState.saving) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (_state) {
      case _SaveState.saving:
        return SizedBox(
          key: const ValueKey("saving"),
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primaryColor.withOpacity(0.8),
            ),
          ),
        );
      case _SaveState.success:
        return Container(
          key: const ValueKey("success"),
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
        );
      case _SaveState.error:
        return Container(
          key: const ValueKey("error"),
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
        );
    }
  }

  String get _label {
    switch (_state) {
      case _SaveState.saving:
        return AppStrings.savingToGallery;
      case _SaveState.success:
        return AppStrings.savedToGallery;
      case _SaveState.error:
        return _errorMsg;
    }
  }
}
