import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:el_saver/src/features/social_videos_downloader/domain/entities/video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/helpers/video_thumbnail.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/helpers/dir_helper.dart';
import '../../../../../core/helpers/media_file_utils.dart';
import '../../../../../core/utils/app_enums.dart';
import '../../../../../core/utils/app_constants.dart';
import '../../../../../core/utils/app_strings.dart';
import '../../../domain/entities/download_item.dart';
import '../../../domain/entities/video_item.dart';
import '../../../domain/entities/video_link.dart';
import '../../../domain/usecase/get_video_usecase.dart';
import '../../../domain/usecase/get_audio_url_usecase.dart';
import '../../../domain/usecase/resolve_media_usecase.dart';
import '../../../domain/usecase/save_video_usecase.dart';

part 'downloader_event.dart';

part 'downloader_state.dart';

class DownloaderBloc extends Bloc<DownloaderEvent, DownloaderState> {
  final GetVideoUseCase getVideoUseCase;
  final GetAudioUrlUseCase getAudioUrlUseCase;
  final ResolveMediaUseCase resolveMediaUseCase;
  final SaveVideoUseCase saveVideoUseCase;
  static const String _downloadHistoryKey = 'download_history';

  DownloaderBloc({
    required this.getVideoUseCase,
    required this.getAudioUrlUseCase,
    required this.resolveMediaUseCase,
    required this.saveVideoUseCase,
  }) : super(DownloaderInitial()) {
    on<LoadOldDownloads>(_loadOldDownloads);
    on<LoadDownloadHistory>(_loadDownloadHistory);
    on<DownloaderGetVideo>(_getVideo);
    on<DownloaderGetAudio>(_getAudio);
    on<DownloaderSaveVideo>(_saveVideo);
    on<DownloaderPauseVideo>(_pauseVideo);
    on<DownloaderResumeVideo>(_resumeVideo);
    on<DownloaderDeleteDownload>(_deleteDownload);
    on<DownloaderRetryDownload>(_retryDownload);

    add(LoadDownloadHistory());
  }

  List<DownloadItem> newDownloads = [];

  // CancelToken per download path - used for actual HTTP cancellation
  final Map<String, CancelToken> _cancelTokens = {};

  Future<void> _getVideo(
    DownloaderGetVideo event,
    Emitter<DownloaderState> emit,
  ) async {
    emit(const DownloaderGetVideoLoading());
    final result = await getVideoUseCase(event.videoLink);
    result.fold(
      (failure) {
        if (failure is AuthRequiredFailure) {
          emit(DownloaderAuthRequired(
            platform: failure.platform,
            sourceUrl: event.videoLink,
            message: failure.message,
          ));
        } else {
          emit(DownloaderGetVideoFailure(failure.message));
        }
      },
      (right) => emit(DownloaderGetVideoSuccess(right)),
    );
  }

  Future<void> _getAudio(
    DownloaderGetAudio event,
    Emitter<DownloaderState> emit,
  ) async {
    emit(const DownloaderGetVideoLoading());
    final result = await getAudioUrlUseCase(event.video.srcUrl);
    result.fold(
      (left) => emit(DownloaderGetVideoFailure(left.message)),
      (audioUrl) {
        // Attach the resolved MP3 link and hand off to the normal save flow.
        const audioQuality = "🎵 Audio (MP3)";
        final withAudio = Video(
          success: event.video.success,
          message: event.video.message,
          srcUrl: event.video.srcUrl,
          ogUrl: event.video.ogUrl,
          title: event.video.title,
          picture: event.video.picture,
          images: event.video.images,
          timeTaken: event.video.timeTaken,
          rId: event.video.rId,
          videoLinks: [
            VideoLink(
              quality: audioQuality,
              link: audioUrl,
              isAudio: true,
              mode: 'audio',
            ),
          ],
          stats: event.video.stats,
        );
        add(DownloaderSaveVideo(
          video: withAudio,
          selectedLink: withAudio.videoLinks.single,
        ));
      },
    );
  }

  Future<void> _saveVideo(
    DownloaderSaveVideo event,
    Emitter<DownloaderState> emit,
  ) async {
    final selectedVideoLink = event.selectedLink;
    final resolution = await resolveMediaUseCase(ResolveMediaParams(
      sourceUrl: event.video.srcUrl,
      option: selectedVideoLink,
    ));
    String? resolutionError;
    dynamic resolved;
    resolution.fold(
      (failure) => resolutionError = failure.message,
      (media) => resolved = media,
    );
    if (resolved == null) {
      emit(DownloaderSaveVideoFailure(
          resolutionError ?? 'Gagal menyiapkan media'));
      return;
    }
    final selectedLink = resolved.url as String;
    final path = await _getPathById(
      event.video.rId,
      optionId: selectedVideoLink.id,
      quality: selectedVideoLink.quality,
      extension: resolved.extension as String,
    );

    final platform = DownloadItem.detectPlatform(event.video.srcUrl);
    final videoTitle = _extractVideoTitle(event.video.title);

    // Reject a duplicate tap on the same file while its download is active;
    // a second CancelToken would orphan the first request.
    if (_cancelTokens.containsKey(path)) return;

    DownloadItem item = DownloadItem(
      video: event.video,
      selectedLink: selectedLink,
      selectedLinkId: selectedVideoLink.id,
      status: DownloadStatus.downloading,
      path: path,
      progress: 0.0,
      platform: platform,
      videoTitle: videoTitle,
      downloadTime: DateTime.now(),
    );

    _upsertItemByPath(item);
    await _saveDownloadHistory();
    emit(const DownloaderSaveVideoLoading());

    // Create CancelToken for this download
    final cancelToken = CancelToken();
    _cancelTokens[path] = cancelToken;

    // Progress callback - no broken checks, just throttle by time
    DateTime? lastProgressUpdate;
    void onProgressUpdate(int received, int total) {
      if (total > 0) {
        final now = DateTime.now();
        if (lastProgressUpdate != null &&
            now.difference(lastProgressUpdate!).inMilliseconds < 200) {
          return;
        }
        lastProgressUpdate = now;

        double progress = (received / total) * 100;
        progress = progress.clamp(1.0, 99.0);

        // Look the item up by path every time: the list can be reloaded or
        // mutated (history reload, delete) while this download runs, so a
        // captured index would go stale.
        _patchItemByPath(
          path,
          (d) => d.copyWith(
            status: DownloadStatus.downloading,
            progress: progress,
          ),
        );

        if (progress % 10 < 1) {
          _saveDownloadHistory();
        }

        emit(DownloaderSaveVideoProgress(progress: progress, path: path));
      }
    }

    SaveVideoParams params = SaveVideoParams(
      savePath: path,
      videoLink: selectedLink,
      cancelToken: cancelToken,
      onReceiveProgress: onProgressUpdate,
    );

    final result = await saveVideoUseCase.call(params);
    _cancelTokens.remove(path);

    result.fold(
      (failure) {
        // Don't mark as error if it was cancelled (paused)
        if (cancelToken.isCancelled) return;

        _patchItemByPath(
          path,
          (d) => d.copyWith(
            status: DownloadStatus.error,
            progress: 0.0,
          ),
        );
        _saveDownloadHistory();
        emit(DownloaderSaveVideoFailure(failure.message));
      },
      (right) async {
        // Mark success immediately so the item appears without waiting on the
        // (slow) thumbnail generation, then backfill the thumbnail after.
        _patchItemByPath(
          path,
          (d) => d.copyWith(
            status: DownloadStatus.success,
            progress: 100.0,
          ),
        );
        _saveDownloadHistory();
        emit(DownloaderSaveVideoSuccess(message: right, path: path));

        if (_isVideoPath(path)) {
          final thumbPath = await _generateThumbnail(path);
          if (thumbPath != null) {
            final i = newDownloads.indexWhere((d) => d.path == path);
            if (i != -1) {
              newDownloads[i] =
                  newDownloads[i].copyWith(thumbnailPath: thumbPath);
              await _saveDownloadHistory();
              // Refresh via a fresh event (not emit) — this callback runs after
              // the handler's emitter has completed, so emitting here throws.
              add(LoadDownloadHistory());
            }
          }
        }
      },
    );
  }

  Future<String?> _generateThumbnail(String videoPath) async {
    try {
      final thumb = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        quality: 50,
        maxWidth: 200,
      );
      return thumb;
    } catch (_) {
      return null;
    }
  }

  Future<String> _getPathById(
    String id, {
    required String quality,
    required String extension,
    String optionId = '',
  }) async {
    final appPath = await DirHelper.getAppPath();
    final suffix = (optionId.isNotEmpty ? optionId : quality)
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final ext = extension.startsWith('.') ? extension : '.$extension';
    return '$appPath/${MediaFileUtils.filename(id, suffix, ext)}';
  }

  bool _isVideoPath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv');
  }

  bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  bool _isSupportedMediaPath(String path) {
    final lower = path.toLowerCase();
    return _isVideoPath(lower) ||
        _isImagePath(lower) ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.ogg');
  }

  void _patchItemByPath(
    String path,
    DownloadItem Function(DownloadItem) transform,
  ) {
    final i = newDownloads.indexWhere((d) => d.path == path);
    if (i != -1) {
      newDownloads[i] = transform(newDownloads[i]);
    }
  }

  void _upsertItemByPath(DownloadItem item) {
    final i = newDownloads.indexWhere((d) => d.path == item.path);
    if (i == -1) {
      newDownloads.add(item);
    } else {
      newDownloads[i] = item;
    }
  }

  List<VideoItem> oldDownloads = [];

  Future<void> _loadOldDownloads(
    LoadOldDownloads event,
    Emitter<DownloaderState> emit,
  ) async {
    emit(const OldDownloadsLoading());
    oldDownloads.clear();
    final path = await DirHelper.getAppPath();
    final directory = Directory(path);
    final files = await directory.list().toList();
    final newDownloadedVideosPaths = newDownloads.map((e) => e.path);
    for (final file in files) {
      if (file is File && _isSupportedMediaPath(file.path)) {
        final mediaPath = file.path;
        if (newDownloadedVideosPaths.contains(mediaPath)) continue;
        String? thumbnailPath;
        if (_isVideoPath(mediaPath)) {
          thumbnailPath = await VideoThumbnail.thumbnailFile(
            video: mediaPath,
            thumbnailPath: (await getTemporaryDirectory()).path,
            quality: 30,
          );
        } else if (_isImagePath(mediaPath)) {
          thumbnailPath = mediaPath;
        }
        oldDownloads
            .add(VideoItem(path: mediaPath)..thumbnailPath = thumbnailPath);
      }
    }
    emit(OldDownloadsLoadingSuccess(downloads: oldDownloads));
  }

  String _extractVideoTitle(String title) {
    if (title.isEmpty) return AppStrings.downloadedVideo;
    // Only strip URLs, keep everything else (hashtags, mentions are part of title)
    String clean = title.replaceAll(RegExp(r'https?://\S+'), '').trim();
    return clean.isNotEmpty ? clean : AppStrings.downloadedVideo;
  }

  Future<void> _loadDownloadHistory(
    LoadDownloadHistory event,
    Emitter<DownloaderState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_downloadHistoryKey);

      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        // Parse per-item: one corrupt entry must not wipe the whole history.
        final parsed = <DownloadItem>[];
        for (final raw in historyList) {
          try {
            parsed.add(DownloadItem.fromJson(raw));
          } catch (_) {
            // skip unreadable entry
          }
        }
        newDownloads = parsed;

        for (int i = 0; i < newDownloads.length; i++) {
          final file = File(newDownloads[i].path);
          if (!file.existsSync()) {
            newDownloads[i] =
                newDownloads[i].copyWith(status: DownloadStatus.error);
          } else if (newDownloads[i].status == DownloadStatus.downloading) {
            newDownloads[i] =
                newDownloads[i].copyWith(status: DownloadStatus.paused);
          }
        }

        await _saveDownloadHistory();
        emit(DownloadHistoryLoaded(downloads: newDownloads));
      }
    } catch (e) {
      // Keep the in-memory list untouched; wiping it here would erase the
      // user's history on a single prefs read failure.
    }
  }

  Future<void> _saveDownloadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson =
          json.encode(newDownloads.map((item) => item.toJson()).toList());
      await prefs.setString(_downloadHistoryKey, historyJson);
    } catch (e) {
      // Silent
    }
  }

  Future<void> _pauseVideo(
    DownloaderPauseVideo event,
    Emitter<DownloaderState> emit,
  ) async {
    final index = newDownloads.indexWhere((item) => item.path == event.path);
    if (index != -1 &&
        newDownloads[index].status == DownloadStatus.downloading) {
      // Cancel the actual HTTP request
      _cancelTokens[event.path]?.cancel("Paused by user");
      _cancelTokens.remove(event.path);

      _patchItemByPath(
          event.path, (d) => d.copyWith(status: DownloadStatus.paused));
      await _saveDownloadHistory();
      emit(DownloaderVideoPaused(path: event.path));
    }
  }

  /// Re-pick the quality option for a stored item; null when the source
  /// video no longer carries any link (stale/partial entry).
  VideoLink? _resolveStoredOption(DownloadItem item) {
    if (item.video.videoLinks.isEmpty) return null;
    return item.video.videoLinks.firstWhere(
      (link) => link.id == item.selectedLinkId,
      orElse: () => item.video.videoLinks.firstWhere(
        (link) => link.link == item.selectedLink,
        orElse: () => item.video.videoLinks.first,
      ),
    );
  }

  Future<void> _resumeVideo(
    DownloaderResumeVideo event,
    Emitter<DownloaderState> emit,
  ) async {
    final index = newDownloads.indexWhere((item) => item.path == event.path);
    if (index != -1 && newDownloads[index].status == DownloadStatus.paused) {
      final item = newDownloads[index];
      final option = _resolveStoredOption(item);
      if (option == null) {
        _patchItemByPath(
            event.path, (d) => d.copyWith(status: DownloadStatus.error));
        await _saveDownloadHistory();
        emit(DownloaderSaveVideoFailure(
            AppStrings.sourceNoLongerAvailable));
        return;
      }
      add(DownloaderSaveVideo(video: item.video, selectedLink: option));
    }
  }

  Future<void> _deleteDownload(
    DownloaderDeleteDownload event,
    Emitter<DownloaderState> emit,
  ) async {
    try {
      final index = newDownloads.indexWhere((item) => item.path == event.path);
      if (index != -1) {
        final item = newDownloads[index];

        // Cancel active download if running
        if (item.status == DownloadStatus.downloading) {
          _cancelTokens[event.path]?.cancel("Deleted by user");
          _cancelTokens.remove(event.path);
        }

        newDownloads.removeAt(index);

        if (event.deleteFile) {
          final file = File(event.path);
          if (file.existsSync()) {
            await file.delete();
          }
        }

        await _saveDownloadHistory();
        emit(DownloaderVideoDeleted(path: event.path));
      }
    } catch (e) {
      emit(DownloaderSaveVideoFailure(
          "Failed to delete download: ${e.toString()}"));
    }
  }

  Future<void> _retryDownload(
    DownloaderRetryDownload event,
    Emitter<DownloaderState> emit,
  ) async {
    final index = newDownloads.indexWhere((item) => item.path == event.path);
    if (index != -1) {
      final item = newDownloads[index];
      final option = _resolveStoredOption(item);
      if (option == null) {
        emit(DownloaderSaveVideoFailure(
            AppStrings.sourceNoLongerAvailable));
        return;
      }

      _patchItemByPath(event.path,
          (d) => d.copyWith(status: DownloadStatus.downloading, progress: 0.0));
      await _saveDownloadHistory();

      add(DownloaderSaveVideo(video: item.video, selectedLink: option));
    }
  }
}
