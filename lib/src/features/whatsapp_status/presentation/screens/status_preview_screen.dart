import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:el_saver/src/core/utils/app_colors.dart';

/// Fullscreen preview for a WhatsApp status image or video.
class StatusPreviewScreen extends StatefulWidget {
  final String path;
  final bool isVideo;

  const StatusPreviewScreen({
    super.key,
    required this.path,
    required this.isVideo,
  });

  @override
  State<StatusPreviewScreen> createState() => _StatusPreviewScreenState();
}

class _StatusPreviewScreenState extends State<StatusPreviewScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    final vc = VideoPlayerController.file(File(widget.path));
    await vc.initialize();
    final cc = ChewieController(
      videoPlayerController: vc,
      autoPlay: true,
      looping: true,
      aspectRatio: vc.value.aspectRatio,
    );
    if (!mounted) {
      vc.dispose();
      return;
    }
    setState(() {
      _videoController = vc;
      _chewieController = cc;
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: widget.isVideo
            ? (_chewieController != null
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                  ))
            : InteractiveViewer(
                maxScale: 4,
                child: Image.file(File(widget.path), fit: BoxFit.contain),
              ),
      ),
    );
  }
}
