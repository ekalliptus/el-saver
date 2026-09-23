import 'package:el_saver/src/features/social_videos_downloader/data/models/video_model.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import '../../../../core/error/failure.dart';
import '../../../../core/helpers/dio_helper.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/app_strings.dart';
import '../../../../core/utils/api_config.dart';
import '../../domain/entities/resolved_media.dart';
import '../../domain/entities/video_link.dart';
import 'download_error_classifier.dart';

abstract class VideoBaseRemoteDataSource {
  Future<VideoModel> getVideo(String videoLink);

  /// Resolve an audio-only (MP3) download URL for [videoLink] on demand.
  Future<String> getAudioUrl(String videoLink);

  Future<ResolvedMedia> resolveMedia(String sourceUrl, VideoLink option);

  Future<String> saveVideo({
    required String videoLink,
    required String savePath,
    CancelToken? cancelToken,
    Function(int received, int total)? onReceiveProgress,
  });
}

class TiktokVideoRemoteDataSource implements VideoBaseRemoteDataSource {
  final DioHelper dioHelper;

  TiktokVideoRemoteDataSource({required this.dioHelper});

  @override
  Future<VideoModel> getVideo(String videoLink) async {
    // Collect the first meaningful failure so the final error is useful.
    Object? relevantFailure;
    AuthRequiredFailure? authFailure;
    void recordFailure(Object e) {
      relevantFailure ??= e;
      final classified =
          DownloadErrorClassifier.classify(e.toString(), videoLink);
      if (classified is AuthRequiredFailure) authFailure ??= classified;
    }

    // Build the extractor candidates in an order tuned to the platform, so we
    // hit the most-likely-to-succeed source first instead of always paying the
    // yt-dlp /info leg. Each candidate is an async task returning a VideoModel.
    final tasks = _extractorsFor(videoLink);

    // 1) Primary extractor first (fast, platform-specific).
    try {
      final result = await tasks.first();
      if (result.success && result.videoLinks.isNotEmpty) return result;
    } catch (e) {
      recordFailure(e);
      developer.log('Primary extractor failed: $e', name: 'VideoAPI');
    }

    // 2) Race the rest in parallel — take the first that returns a usable
    //    result. This turns the old ~sequential worst-case (minutes) into
    //    roughly a single slow request.
    final rest = tasks.skip(1).toList();
    if (rest.isNotEmpty) {
      try {
        final result = await _raceExtractors(rest, recordFailure);
        if (result != null) return result;
      } catch (e) {
        recordFailure(e);
      }
    }

    if (authFailure != null) throw authFailure!;
    if (relevantFailure != null) {
      developer.log('Final extractor failure: $relevantFailure',
          name: 'VideoAPI');
    }
    return VideoModel(
      success: false,
      message: ApiConfig.allApisFailed,
      srcUrl: videoLink,
      ogUrl: "",
      title: "Download Failed",
      picture: "",
      images: const [],
      timeTaken: DateTime.now().toString(),
      rId: DateTime.now().millisecondsSinceEpoch.toString(),
      videoLinks: const [],
    );
  }

  /// Ordered extractor tasks tuned per platform. The first entry is the primary
  /// (run alone, fast); the remainder are raced in parallel as fallbacks.
  List<Future<VideoModel> Function()> _extractorsFor(String url) {
    Future<VideoModel> tikwm() => _tryGetVideoFromTikwm(url);
    Future<VideoModel> ytInfo() => _tryGetVideoInfoFromYtdlp(url);
    Future<VideoModel> ytFull() => _tryGetVideoFromYtdlp(url);
    final cobalt = <Future<VideoModel> Function()>[
      for (final instance in ApiConfig.cobaltInstances)
        () => _tryGetVideoFromCobalt(instance, url),
    ];

    if (_isTikTokUrl(url) && ApiConfig.useTikwmFallback) {
      // TikTok: TikWM is fastest & watermark-free; fall back to cobalt/yt-dlp.
      return [tikwm, ...cobalt, ytInfo, ytFull];
    }
    if (_isYoutubeUrl(url)) {
      // YouTube: yt-dlp /info gives real qualities; cobalt as backup.
      return [ytInfo, ...cobalt, ytFull];
    }
    if (_isLoginGatedUrl(url)) {
      // Stories / private content: Cobalt returns link.invalid, only yt-dlp
      // with synced cookies can extract these. Try yt-dlp first.
      return [ytInfo, ytFull, ...cobalt];
    }
    // Instagram/Threads/Twitter/X/Facebook/Bilibili.tv: cobalt (with synced
    // cookies) first, then yt-dlp. Primary = first cobalt instance.
    return [...cobalt, ytInfo, ytFull];
  }

  /// Runs [tasks] concurrently and completes with the first usable result.
  /// Individual failures are recorded but don't abort the race; returns null
  /// only when every task fails or yields no media.
  Future<VideoModel?> _raceExtractors(
    List<Future<VideoModel> Function()> tasks,
    void Function(Object) onFailure,
  ) {
    final completer = Completer<VideoModel?>();
    var remaining = tasks.length;

    for (final task in tasks) {
      task().then((result) {
        if (completer.isCompleted) return;
        if (result.success && result.videoLinks.isNotEmpty) {
          completer.complete(result);
        } else {
          if (--remaining == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      }).catchError((Object e) {
        onFailure(e);
        if (--remaining == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    return completer.future;
  }

  bool _isYoutubeUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains("youtube.com") ||
        lower.contains("youtu.be") ||
        lower.contains("youtube-nocookie.com");
  }

  /// Login-gated content (stories, private posts) that Cobalt can't fetch —
  /// only yt-dlp with synced cookies can, so it should lead the extractor list.
  bool _isLoginGatedUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains("/stories/") ||
        lower.contains("/story/") ||
        lower.contains("facebook.com/share") ||
        lower.contains("facebook.com/stories");
  }

  Future<VideoModel> _tryGetVideoFromCobalt(
      String instanceUrl, String videoLink) async {
    final headers = <String, dynamic>{
      "Accept": "application/json",
      "Content-Type": "application/json",
    };

    headers["Authorization"] = "Api-Key ${ApiConfig.cobaltApiKey}";

    // Single request: Cobalt auto-selects the best stream up to videoQuality.
    // (Looping every lower quality per instance was the main fetch slowdown.)
    final response = await dioHelper.post(
      path: AppConstants.cobaltEndpoint,
      baseUrl: instanceUrl,
      customHeaders: headers,
      // Short connect timeout: skip dead instances fast in the fallback chain
      connectTimeout:
          const Duration(seconds: ApiConfig.cobaltConnectTimeoutSeconds),
      receiveTimeout:
          const Duration(seconds: ApiConfig.cobaltReceiveTimeoutSeconds),
      data: {
        "url": videoLink,
        "videoQuality": ApiConfig.videoQuality,
        "filenameStyle": "basic",
        "downloadMode": "auto",
      },
    );

    if (response.data == null) {
      throw Exception("Empty response from Cobalt");
    }

    final data = response.data as Map<String, dynamic>;
    final status = data["status"] as String?;

    if (status == "local-processing") {
      throw Exception("Cobalt requires local processing; use yt-dlp fallback");
    }

    if (status == "error") {
      final error = data["error"];
      final code = error is Map ? error["code"]?.toString() : error?.toString();
      if (code != null && code.contains("youtube.login")) {
        throw Exception("Video ini membutuhkan autentikasi YouTube di server. "
            "Hubungi admin server Cobalt untuk konfigurasi cookies YouTube.");
      }
      if (code != null && code.contains("link.invalid")) {
        throw Exception("Link tidak valid atau tidak didukung.");
      }
      if (code != null && code.contains("fetch.empty")) {
        throw Exception("Tidak bisa mengakses konten. Video mungkin private, "
            "dihapus, atau platform membutuhkan cookies di server.");
      }
      throw Exception("Cobalt error: $code");
    }

    if (status == "tunnel" || status == "redirect") {
      final tunnelUrl = data["url"] as String? ?? "";
      if (tunnelUrl.isNotEmpty && await _validateTunnelUrl(tunnelUrl)) {
        return VideoModel.fromCobalt(data, videoLink);
      }
      throw Exception("Tunnel tidak valid untuk video ini.");
    }

    if (status == "picker") {
      return VideoModel.fromCobalt(data, videoLink);
    }

    throw Exception("Server tidak bisa memproses video ini. "
        "Coba video lain atau hubungi admin server.");
  }

  /// Resolve an audio-only (MP3) URL via the yt-dlp API. yt-dlp (with the deno
  /// EJS solver) reliably extracts audio where Cobalt's audio tunnel does not.
  @override
  Future<String> getAudioUrl(String videoLink) async {
    final baseUrl = ApiConfig.ytdlpApiUrl;
    final response = await _postYtdlp(
      path: "/download",
      baseUrl: baseUrl,
      customHeaders: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-Api-Key": ApiConfig.ytdlpApiKey,
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 210),
      data: {"url": videoLink, "mode": "audio"},
    );
    final data = response.data as Map<String, dynamic>?;
    final status = data?["status"] as String?;
    if (status == "tunnel" || status == "redirect") {
      var url = data?["url"] as String? ?? "";
      if (url.isNotEmpty) {
        if (url.startsWith("/")) url = "$baseUrl$url"; // served file
        return url;
      }
    }
    throw Exception(data?["detail"]?.toString() ?? "Gagal mengekstrak audio");
  }

  /// HEAD check tunnel URL to verify it will return actual data
  Future<bool> _validateTunnelUrl(String tunnelUrl) async {
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 5);

      final response = await dio.head(tunnelUrl);
      if (response.statusCode != 200) return false;

      final estimated = response.headers.value('estimated-content-length');
      final contentLength = response.headers.value('content-length');

      // If Content-Length is present and > 0, it's valid
      if (contentLength != null) {
        final size = int.tryParse(contentLength) ?? 0;
        return size > 0;
      }

      // If Estimated-Content-Length is -1, Cobalt can't process this video
      if (estimated != null) {
        final size = int.tryParse(estimated) ?? -1;
        return size > 0;
      }

      // No size headers at all - assume it works (chunked streaming)
      return true;
    } catch (e) {
      developer.log("Tunnel validation failed: $e", name: "VideoAPI");
      return false;
    }
  }

  Future<VideoModel> _tryGetVideoFromTikwm(String videoLink) async {
    final response = await dioHelper.get(
      path: AppConstants.tikwmEndpoint,
      baseUrl: AppConstants.tikwmBaseUrl,
      queryParams: {"url": videoLink, "hd": "1"},
      customHeaders: {
        "Accept": "application/json",
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      },
    );

    if (response.data == null) {
      throw Exception("Empty response from TikWM");
    }

    final data = response.data as Map<String, dynamic>;
    if (data["code"] != 0 && data["code"] != "0") {
      throw Exception("TikWM error: ${data["msg"]}");
    }

    return VideoModel.fromTikwm(data, videoLink);
  }

  bool _isTikTokUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains("tiktok.com") ||
        lower.contains("douyin.com") ||
        lower.contains("v.douyin.com");
  }

  Future<Response> _postYtdlp({
    required String path,
    required String baseUrl,
    required Map<String, dynamic> customHeaders,
    required Duration connectTimeout,
    required Duration receiveTimeout,
    required Map<String, dynamic> data,
  }) async {
    try {
      return await dioHelper.post(
        path: path,
        baseUrl: baseUrl,
        customHeaders: customHeaders,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        data: data,
      );
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map && body['detail'] != null) {
        throw Exception(body['detail'].toString());
      }
      rethrow;
    }
  }

  Future<VideoModel> _tryGetVideoInfoFromYtdlp(String videoLink) async {
    final baseUrl = ApiConfig.ytdlpApiUrl;
    final response = await _postYtdlp(
      path: "/info",
      baseUrl: baseUrl,
      customHeaders: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-Api-Key": ApiConfig.ytdlpApiKey,
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout:
          const Duration(seconds: ApiConfig.ytdlpInfoTimeoutSeconds),
      data: {"url": videoLink},
    );
    final data = response.data as Map<String, dynamic>?;
    if (data == null || data["status"] != "ok") {
      throw Exception(data?["detail"]?.toString() ?? "yt-dlp info failed");
    }
    return VideoModel.fromYtdlpInfo(data, videoLink);
  }

  @override
  Future<ResolvedMedia> resolveMedia(String sourceUrl, VideoLink option) async {
    if (!option.isDeferred && option.link.isNotEmpty) {
      return ResolvedMedia(
        url: option.link,
        filename: 'media${option.extension}',
        extension: option.extension,
        mediaKind: option.mediaKind,
      );
    }
    final baseUrl = ApiConfig.ytdlpApiUrl;
    final response = await _postYtdlp(
      path: "/download",
      baseUrl: baseUrl,
      customHeaders: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-Api-Key": ApiConfig.ytdlpApiKey,
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 210),
      data: {
        "url": sourceUrl,
        "quality": option.height?.toString() ?? ApiConfig.videoQuality,
        "mode": option.mode,
      },
    );
    final data = response.data as Map<String, dynamic>?;
    if (data == null ||
        (data["status"] != "redirect" && data["status"] != "tunnel")) {
      throw Exception(data?["detail"]?.toString() ?? "Gagal menyiapkan media");
    }
    var url = data["url"]?.toString() ?? '';
    if (url.startsWith('/')) url = '$baseUrl$url';
    if (url.isEmpty) throw Exception('Media URL kosong');
    final filename = data["filename"]?.toString() ?? 'media${option.extension}';
    final extension = _extensionFromFilename(filename, option.extension);
    final kindName = data["mediaKind"]?.toString();
    final kind = MediaKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => extension == '.mp3' ? MediaKind.audio : option.mediaKind,
    );
    return ResolvedMedia(
      url: url,
      filename: filename,
      extension: extension,
      mediaKind: kind,
    );
  }

  String _extensionFromFilename(String filename, String fallback) {
    final match = RegExp(r'\.([A-Za-z0-9]+)$').firstMatch(filename);
    if (match == null) return fallback;
    return '.${match.group(1)!.toLowerCase()}';
  }

  Future<VideoModel> _tryGetVideoFromYtdlp(String videoLink) async {
    final baseUrl = ApiConfig.ytdlpApiUrl;
    final apiKey = ApiConfig.ytdlpApiKey;

    final response = await _postYtdlp(
      path: "/download",
      baseUrl: baseUrl,
      customHeaders: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-Api-Key": apiKey,
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 210),
      data: {
        "url": videoLink,
        "quality": ApiConfig.videoQuality,
      },
    );

    if (response.data == null) {
      throw Exception("Empty response from yt-dlp API");
    }

    final data = response.data as Map<String, dynamic>;
    final status = data["status"] as String?;

    if (status == "error" || status == null) {
      throw Exception("yt-dlp error: ${data["detail"] ?? "unknown"}");
    }

    return VideoModel.fromYtdlp(data, videoLink, baseUrl);
  }

  @override
  Future<String> saveVideo({
    required String videoLink,
    required String savePath,
    CancelToken? cancelToken,
    Function(int received, int total)? onReceiveProgress,
  }) async {
    try {
      if (videoLink.isEmpty) {
        throw Exception("Video link cannot be empty");
      }

      if (savePath.isEmpty) {
        throw Exception("Save path cannot be empty");
      }

      developer.log("Starting download: $videoLink to $savePath",
          name: "DownloadService");

      if (_isImagePath(savePath)) {
        await dioHelper.downloadImage(
          savePath: savePath,
          downloadLink: videoLink,
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
        );
      } else {
        await dioHelper.download(
          savePath: savePath,
          downloadLink: videoLink,
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
        );
      }

      final file = File(savePath);
      if (!file.existsSync()) {
        throw Exception("Download failed: File was not created");
      }

      final fileSize = file.lengthSync();
      if (fileSize == 0) {
        await file.delete();
        throw Exception("Download failed: File is empty");
      }

      developer.log("Download completed successfully: $fileSize bytes",
          name: "DownloadService");
      return AppStrings.downloadSuccess;
    } catch (error) {
      developer.log("Download error: $error", name: "DownloadService");

      try {
        final file = File(savePath);
        if (file.existsSync()) {
          await file.delete();
        }
      } catch (cleanupError) {
        developer.log("Failed to cleanup: $cleanupError",
            name: "DownloadService");
      }

      rethrow;
    }
  }

  bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }
}
