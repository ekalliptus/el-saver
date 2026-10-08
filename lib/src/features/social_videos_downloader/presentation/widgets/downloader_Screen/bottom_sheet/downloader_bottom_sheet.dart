import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:el_saver/src/features/social_videos_downloader/domain/entities/video.dart';
import 'package:el_saver/src/features/social_videos_downloader/domain/entities/video_link.dart';

import '../../../../../../core/common_widgets/custom_elevated_button.dart';
import '../../../../../../core/common_widgets/skeleton_loader.dart';
import '../../../../../../core/utils/app_strings.dart';
import '../../../../../../config/routes_manager.dart';
import '../../../bloc/downloader_bloc/downloader_bloc.dart';
import 'bottom_sheet_header.dart';
import 'count_view.dart';

/// Opens a single bottom sheet that shows a shimmer skeleton while the fetch
/// is in flight, then swaps to the quality picker when the video resolves.
/// Using one sheet driven by the bloc avoids the pop/push race that made the
/// quality picker flash and disappear.
Future<void> openDownloadSheet(BuildContext context) {
  final bloc = context.read<DownloaderBloc>();
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: const _DownloadSheet(),
    ),
  );
}

class _DownloadSheet extends StatefulWidget {
  const _DownloadSheet();

  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  // Once a quality list is shown we keep it, so a stray GetVideoLoading (e.g. a
  // duplicate fetch) can't rebuild the sheet back into the skeleton and yank
  // the Download button out from under the user's tap.
  Video? _video;

  @override
  Widget build(BuildContext context) {
    return BlocListener<DownloaderBloc, DownloaderState>(
      listenWhen: (_, s) =>
          s is DownloaderGetVideoFailure ||
          s is DownloaderAuthRequired ||
          s is DownloaderSaveVideoLoading ||
          (s is DownloaderGetVideoSuccess && s.video.videoLinks.isEmpty) ||
          (s is DownloaderGetVideoSuccess && s.video.videoLinks.isNotEmpty),
      listener: (context, state) {
        if (state is DownloaderGetVideoSuccess &&
            state.video.videoLinks.isNotEmpty) {
          // First real quality list wins; ignore later re-fetches.
          if (_video == null) setState(() => _video = state.video);
          return;
        }
        // Failure / auth / download-started / empty -> close the sheet.
        Navigator.of(context).pop();
      },
      child: _video == null
          ? const DownloadSheetSkeleton()
          : _QualityPicker(video: _video!),
    );
  }
}

class _QualityPicker extends StatefulWidget {
  final Video video;
  const _QualityPicker({required this.video});

  @override
  State<_QualityPicker> createState() => _QualityPickerState();
}

class _QualityPickerState extends State<_QualityPicker> {
  late VideoLink _selected = widget.video.videoLinks.firstWhere(
    (link) => !link.isAudio,
    orElse: () => widget.video.videoLinks.first,
  );

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // Cap the height and make the content scrollable so the Download button
      // is always reachable (tall thumbnails/titles previously pushed it off
      // screen, so taps never landed on it).
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              BottomSheetHeader(videoData: video),
              const SizedBox(height: 12),
              BottomSheetCountItems(
                videoData: video,
                onChanged: (link) => _selected = link,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: CustomElevatedBtn(
                  label: AppStrings.download,
                  onPressed: () {
                    // Capture references before the sheet (and this context) is
                    // disposed by pop(), then close the sheet, dispatch the save
                    // event and navigate to the downloads screen.
                    final bloc = context.read<DownloaderBloc>();
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    bloc.add(DownloaderSaveVideo(
                      video: video,
                      selectedLink: _selected,
                    ));
                    navigator.pushNamed(Routes.downloads);
                  },
                ),
              ),
              const SizedBox(height: 10),
              // On-demand audio-only (MP3): resolved via yt-dlp when tapped.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: Colors.white70),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: const Icon(Icons.music_note, color: Colors.white),
                  label: Text(
                    AppStrings.audioMp3,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    final bloc = context.read<DownloaderBloc>();
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    bloc.add(DownloaderGetAudio(video: video));
                    navigator.pushNamed(Routes.downloads);
                  },
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
