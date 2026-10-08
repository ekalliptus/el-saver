// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_strings.dart';
import '../../../../../core/common_widgets/fancy_loader.dart';

class ViewVideoScreen extends StatefulWidget {
  final String videoPath;
  const ViewVideoScreen({super.key, required this.videoPath});

  @override
  State<ViewVideoScreen> createState() => _ViewVideoScreenState();
}

class _ViewVideoScreenState extends State<ViewVideoScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final file = File(widget.videoPath);
      if (!file.existsSync()) {
        setState(() => _error = AppStrings.fileNotFound);
        return;
      }

      final vc = VideoPlayerController.file(file);
      await vc.initialize();

      if (!mounted) {
        vc.dispose();
        return;
      }

      final cc = ChewieController(
        videoPlayerController: vc,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primaryColor,
          handleColor: AppColors.primaryColor,
          backgroundColor: Colors.grey,
          bufferedColor: AppColors.primaryColor.withOpacity(0.3),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      setState(() {
        _videoController = vc;
        _chewieController = cc;
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppStrings.videoPlayFailed(e.toString()));
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.pause();
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          Center(child: _buildContent()),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: _buildCloseButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      );
    }

    if (!_isInitialized) {
      return const FancyLoader(size: 32);
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
