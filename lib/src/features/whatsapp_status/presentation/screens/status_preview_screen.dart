import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:el_saver/src/core/utils/app_strings.dart';
import '../../../../core/common_widgets/fancy_loader.dart';

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
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    final vc = VideoPlayerController.file(File(widget.path));
    try {
      await vc.initialize();
    } catch (_) {
      vc.dispose();
      if (mounted) setState(() => _failed = true);
      return;
    }
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
        child: _failed
            ? Text(
                AppStrings.cannotPlayMedia,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              )
            : widget.isVideo
                ? (_chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : const FancyLoader(size: 36))
                : InteractiveViewer(
                    maxScale: 4,
                    child: Image.file(File(widget.path), fit: BoxFit.contain),
                  ),
      ),
    );
  }
}
