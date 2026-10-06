part of 'downloader_bloc.dart';

abstract class DownloaderState extends Equatable {
  const DownloaderState();
}

class DownloaderInitial extends DownloaderState {
  @override
  List<Object> get props => [];
}

class DownloaderGetVideoLoading extends DownloaderState {
  const DownloaderGetVideoLoading();

  @override
  List<Object?> get props => [];
}

class DownloaderGetVideoSuccess extends DownloaderState {
  final Video video;

  const DownloaderGetVideoSuccess(this.video);

  @override
  List<Object?> get props => [video];
}

class DownloaderAuthRequired extends DownloaderState {
  final SocialPlatform platform;
  final String sourceUrl;
  final String message;

  const DownloaderAuthRequired({
    required this.platform,
    required this.sourceUrl,
    required this.message,
  });

  @override
  List<Object?> get props => [platform, sourceUrl, message];
}

class DownloaderGetVideoFailure extends DownloaderState {
  final String message;

  const DownloaderGetVideoFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class DownloaderSaveVideoLoading extends DownloaderState {
  const DownloaderSaveVideoLoading();

  @override
  List<Object?> get props => [];
}

class DownloaderSaveVideoProgress extends DownloaderState {
  final double progress;
  final String path;

  const DownloaderSaveVideoProgress(
      {required this.progress, required this.path});

  @override
  List<Object?> get props => [progress, path];
}

class DownloaderSaveVideoSuccess extends DownloaderState {
  final String message;
  final String path;

  const DownloaderSaveVideoSuccess({required this.message, required this.path});

  @override
  List<Object?> get props => [message, path];
}

class DownloaderSaveVideoFailure extends DownloaderState {
  final String message;

  const DownloaderSaveVideoFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class OldDownloadsLoading extends DownloaderState {
  const OldDownloadsLoading();

  @override
  List<Object?> get props => [];
}

class OldDownloadsLoadingSuccess extends DownloaderState {
  final List<VideoItem> downloads;

  const OldDownloadsLoadingSuccess({required this.downloads});

  @override
  List<Object?> get props => [downloads];
}

class OldDownloadsLoadingFailure extends DownloaderState {
  final String message;

  const OldDownloadsLoadingFailure(this.message);

  @override
  List<Object?> get props => [message];
}

// New states for download history and controls
class DownloadHistoryLoaded extends DownloaderState {
  final List<DownloadItem> downloads;

  const DownloadHistoryLoaded({required this.downloads});

  @override
  List<Object?> get props => [downloads];
}

class DownloaderVideoPaused extends DownloaderState {
  final String path;

  const DownloaderVideoPaused({required this.path});

  @override
  List<Object?> get props => [path];
}

class DownloaderVideoDeleted extends DownloaderState {
  final String path;

  const DownloaderVideoDeleted({required this.path});

  @override
  List<Object?> get props => [path];
}
