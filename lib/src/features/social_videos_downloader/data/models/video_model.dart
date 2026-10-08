import 'package:el_saver/src/features/social_videos_downloader/data/models/video_link_model.dart';
import 'package:el_saver/src/features/social_videos_downloader/data/models/video_stats_model.dart';
import 'package:el_saver/src/features/social_videos_downloader/domain/entities/video.dart';
import 'package:el_saver/src/features/social_videos_downloader/domain/entities/video_link.dart';

class VideoModel extends Video {
  const VideoModel({
    required super.success,
    required super.message,
    required super.srcUrl,
    required super.ogUrl,
    required super.title,
    required super.picture,
    required super.images,
    required super.timeTaken,
    required super.rId,
    required super.videoLinks,
    super.stats,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    List<VideoLinkModel> videoLinks = [];

    if (json['play'] != null) {
      videoLinks.add(VideoLinkModel(
          quality: _fmt("Standard"), link: json['play'].toString()));
    }
    if (json['hdplay'] != null) {
      videoLinks.add(
          VideoLinkModel(quality: _fmt("HD"), link: json['hdplay'].toString()));
    }
    if (json['wmplay'] != null) {
      videoLinks.add(VideoLinkModel(
          quality: _fmt("Watermark"), link: json['wmplay'].toString()));
    }

    if (json['video_url'] != null) {
      videoLinks.add(VideoLinkModel(
          quality: _fmt("Video"), link: json['video_url'].toString()));
    }

    if (json['links'] != null && json['links'] is List) {
      videoLinks.addAll((json['links'] as List)
          .map((linkJson) => VideoLinkModel(
              quality: _fmt(linkJson['quality'] ?? "Video"),
              link: linkJson['link'] ?? ""))
          .toList());
    }

    if (json['image_urls'] != null && json['image_urls'] is List) {
      List<String> imageUrls = List<String>.from(json['image_urls']);
      for (int i = 0; i < imageUrls.length; i++) {
        videoLinks.add(VideoLinkModel(
            quality: _fmt("Image ${i + 1}"), link: imageUrls[i]));
      }
    }

    VideoStatsModel? stats;
    if (json['duration'] != null ||
        json['play_count'] != null ||
        json['likes'] != null) {
      stats = VideoStatsModel(
        videoLenght: json['duration']?.toString() ?? "0",
        viewsCount: json['play_count']?.toString() ??
            json['viewCount']?.toString() ??
            json['likes']?.toString() ??
            "0",
      );
    }

    List<String> images = [];
    if (json['images'] != null && json['images'] is List) {
      images =
          List<String>.from((json['images'] as List).map((e) => e.toString()));
    } else if (json['image_urls'] != null && json['image_urls'] is List) {
      images = List<String>.from(
          (json['image_urls'] as List).map((e) => e.toString()));
    }

    return VideoModel(
      success: json["success"] ?? false,
      message: json["message"] ?? "",
      srcUrl: json["src_url"] ?? "",
      ogUrl: json["og_url"] ?? "",
      title: json["title"] ?? "",
      picture: json["picture"] ?? "",
      images: images,
      timeTaken: json["timeTaken"] ?? "",
      rId: json["r_id"] ?? "",
      videoLinks: videoLinks,
      stats: stats,
    );
  }

  /// Parse Cobalt API response
  factory VideoModel.fromCobalt(Map<String, dynamic> json, String originalUrl,
      {String? audioUrl}) {
    final status = json["status"] as String?;
    final rId = DateTime.now().millisecondsSinceEpoch.toString();
    List<VideoLinkModel> videoLinks = [];
    List<String> images = [];
    String title = json["filename"] ?? "Video";

    if (status == "redirect" || status == "tunnel") {
      final url = json["url"] as String? ?? "";
      final filename = json["filename"] as String? ?? "Video";
      final extension = _extensionFromFilename(filename);
      final kind = extension == '.mp3' ? MediaKind.audio : MediaKind.video;
      videoLinks.add(VideoLinkModel(
        id: 'cobalt-0',
        quality: _fmt(kind == MediaKind.audio ? "Audio (MP3)" : "Best Quality"),
        link: url,
        mediaKind: kind,
        mode: kind == MediaKind.audio ? 'audio' : 'video',
        extension: extension,
      ));
      title = filename;
    } else if (status == "picker") {
      final picker = json["picker"] as List? ?? [];

      for (int i = 0; i < picker.length; i++) {
        final item = picker[i] as Map<String, dynamic>;
        final type = item["type"] as String? ?? "video";
        final url = item["url"] as String? ?? "";

        if (type == "photo") {
          images.add(url);
          videoLinks.add(VideoLinkModel(
            id: 'picker-$i',
            quality: _fmt("Image ${i + 1}"),
            link: url,
            mediaKind: MediaKind.image,
            extension: '.jpg',
          ));
        } else if (type == "gif") {
          videoLinks.add(VideoLinkModel(
            id: 'picker-$i',
            quality: _fmt("GIF ${i + 1}"),
            link: url,
            mediaKind: MediaKind.gif,
            extension: '.gif',
          ));
        } else {
          videoLinks.add(VideoLinkModel(
            id: 'picker-$i',
            quality: _fmt("Video ${i + 1}"),
            link: url,
            mediaKind: MediaKind.video,
            extension: '.mp4',
          ));
        }
      }

      final pickerAudio = json["audio"] as String?;
      if (pickerAudio != null && pickerAudio.isNotEmpty) {
        videoLinks.add(VideoLinkModel(
          quality: "🎵 Audio Only",
          link: pickerAudio,
          isAudio: true,
          mode: 'audio',
          extension: '.mp3',
        ));
      }
    }

    // Audio-only tunnel fetched separately (video-tunnel case).
    if (audioUrl != null && audioUrl.isNotEmpty) {
      videoLinks.add(VideoLinkModel(
        quality: "🎵 Audio (MP3)",
        link: audioUrl,
        isAudio: true,
        mode: 'audio',
        extension: '.mp3',
      ));
    }

    return VideoModel(
      success: videoLinks.isNotEmpty,
      message: videoLinks.isNotEmpty ? "Success" : "No media found",
      srcUrl: originalUrl,
      ogUrl: originalUrl,
      title: _cleanTitle(title),
      picture: "",
      images: images,
      timeTaken: DateTime.now().toString(),
      rId: rId,
      videoLinks: videoLinks,
    );
  }

  /// Parse TikWM API response (TikTok/Douyin fallback)
  factory VideoModel.fromTikwm(Map<String, dynamic> json, String originalUrl) {
    final data = json["data"] as Map<String, dynamic>? ?? {};
    final rId = DateTime.now().millisecondsSinceEpoch.toString();
    List<VideoLinkModel> videoLinks = [];
    List<String> images = [];

    // Video URLs
    final hdPlay = data["hdplay"] as String?;
    final play = data["play"] as String?;
    final wmPlay = data["wmplay"] as String?;

    if (hdPlay != null && hdPlay.isNotEmpty) {
      videoLinks.add(VideoLinkModel(
        quality: _fmt("HD No Watermark"),
        link: hdPlay,
      ));
    }
    if (play != null && play.isNotEmpty) {
      videoLinks.add(VideoLinkModel(
        quality: _fmt("Standard No Watermark"),
        link: play,
      ));
    }
    if (wmPlay != null && wmPlay.isNotEmpty) {
      videoLinks.add(VideoLinkModel(
        quality: _fmt("With Watermark"),
        link: wmPlay,
      ));
    }

    // Image gallery (TikTok photo mode)
    final imageList = data["images"] as List?;
    if (imageList != null) {
      for (int i = 0; i < imageList.length; i++) {
        final url = imageList[i].toString();
        images.add(url);
        videoLinks.add(VideoLinkModel(
          quality: _fmt("Image ${i + 1}"),
          link: url,
        ));
      }
    }

    // Music
    final musicUrl = data["music"] as String?;
    if (musicUrl != null && musicUrl.isNotEmpty) {
      videoLinks.add(VideoLinkModel(
        quality: "🎵 Audio/Music",
        link: musicUrl,
        isAudio: true,
        mode: 'audio',
        extension: '.mp3',
      ));
    }

    final title = data["title"] as String? ?? "TikTok Video";
    final cover =
        data["cover"] as String? ?? data["origin_cover"] as String? ?? "";
    final duration = data["duration"]?.toString() ?? "0";
    final playCount = data["play_count"]?.toString() ?? "0";

    return VideoModel(
      success: videoLinks.isNotEmpty,
      message: videoLinks.isNotEmpty ? "Success" : "No media found",
      srcUrl: originalUrl,
      ogUrl: originalUrl,
      title: _cleanTitle(title),
      picture: cover,
      images: images,
      timeTaken: DateTime.now().toString(),
      rId: rId,
      videoLinks: videoLinks,
      stats: VideoStatsModel(
        videoLenght: duration,
        viewsCount: playCount,
      ),
    );
  }

  /// Parse yt-dlp /info response into deferred quality choices.
  factory VideoModel.fromYtdlpInfo(
      Map<String, dynamic> json, String originalUrl) {
    final links = <VideoLinkModel>[];
    final formats = json['formats'] as List? ?? const [];
    for (final raw in formats) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final height = item['height'] as int?;
      final quality = item['quality']?.toString() ??
          (height == null ? 'Video' : '${height}p');
      final kindName = item['mediaKind']?.toString();
      final kind = MediaKind.values.firstWhere(
        (value) => value.name == kindName,
        orElse: () => MediaKind.video,
      );
      final ext = _normalizeExtension(
        item['extension']?.toString() ??
            item['ext']?.toString() ??
            (kind == MediaKind.image ? 'jpg' : 'mp4'),
      );
      links.add(VideoLinkModel(
        id: 'quality-${height ?? quality}',
        quality: _fmt(quality),
        link: '',
        size: item['filesize'] as int?,
        mediaKind: kind,
        mode: kind == MediaKind.audio ? 'audio' : 'video',
        extension: ext,
        height: height,
        isDeferred: true,
      ));
    }
    final audio = json['audio'];
    if (audio is Map) {
      final item = Map<String, dynamic>.from(audio);
      links.add(VideoLinkModel(
        id: 'audio-mp3',
        quality: _fmt(item['quality']?.toString() ?? 'Audio (MP3)'),
        link: '',
        size: item['filesize'] as int?,
        mediaKind: MediaKind.audio,
        mode: 'audio',
        extension: '.mp3',
        isDeferred: true,
      ));
    }
    return VideoModel(
      success: links.isNotEmpty,
      message: links.isNotEmpty ? 'Success' : 'No media found',
      srcUrl: originalUrl,
      ogUrl: originalUrl,
      title: _cleanTitle(json['title']?.toString() ?? 'Downloaded Media'),
      picture: json['thumbnail']?.toString() ?? '',
      images: const [],
      timeTaken: DateTime.now().toString(),
      rId: DateTime.now().millisecondsSinceEpoch.toString(),
      videoLinks: links,
    );
  }

  /// Parse yt-dlp API response (YouTube fallback)
  factory VideoModel.fromYtdlp(
      Map<String, dynamic> json, String originalUrl, String apiBaseUrl) {
    final rId = DateTime.now().millisecondsSinceEpoch.toString();
    List<VideoLinkModel> videoLinks = [];

    final status = json["status"] as String?;
    final title = json["title"] as String? ??
        json["filename"] as String? ??
        "YouTube Video";
    var url = json["url"] as String? ?? "";

    // If URL is relative path (tunnel/merged file), prepend base URL
    if (url.startsWith("/")) {
      url = "$apiBaseUrl$url";
    }

    if (url.isNotEmpty) {
      final label = status == "redirect"
          ? "Best Quality (Direct)"
          : "Best Quality (Merged)";
      videoLinks.add(VideoLinkModel(
        quality: _fmt(label),
        link: url,
      ));
    }

    return VideoModel(
      success: videoLinks.isNotEmpty,
      message: videoLinks.isNotEmpty ? "Success" : "No media found",
      srcUrl: originalUrl,
      ogUrl: originalUrl,
      title: _cleanTitle(title),
      picture: "",
      images: const [],
      timeTaken: DateTime.now().toString(),
      rId: rId,
      videoLinks: videoLinks,
    );
  }

  static String _extensionFromFilename(String filename) {
    final match = RegExp(r'\.([A-Za-z0-9]+)$').firstMatch(filename);
    return _normalizeExtension(match?.group(1) ?? 'mp4');
  }

  static String _normalizeExtension(String value) {
    if (value.isEmpty) return '.mp4';
    return value.startsWith('.')
        ? value.toLowerCase()
        : '.${value.toLowerCase()}';
  }

  static String _cleanTitle(String title) {
    if (title.isEmpty) return "Downloaded Media";
    // Strip file extension
    String clean = title.replaceAll(
        RegExp(r'\.(mp4|webm|mkv|mp3|ogg|wav|m4a)$', caseSensitive: false), '');
    // Strip quality/codec suffix like "(720p, h264)" or "(1080p)"
    clean = clean.replaceAll(RegExp(r'\s*\(\d+p,?\s*\w*\)\s*$'), '');
    // Replace Cobalt's platform_hashID names with readable names
    if (RegExp(r'^facebook_[A-Za-z0-9_-]+$').hasMatch(clean)) {
      return "Facebook Video";
    }
    if (RegExp(r'^instagram_[A-Za-z0-9_-]+$').hasMatch(clean)) {
      return "Instagram Post";
    }
    if (RegExp(r'^twitter_[A-Za-z0-9_-]+$').hasMatch(clean)) {
      return "Twitter Post";
    }
    if (RegExp(r'^reddit_[A-Za-z0-9_-]+$').hasMatch(clean)) {
      return "Reddit Post";
    }
    if (RegExp(r'^pinterest_[A-Za-z0-9_-]+$').hasMatch(clean)) {
      return "Pinterest Pin";
    }
    if (RegExp(r'^tumblr_[A-Za-z0-9_-]+$').hasMatch(clean)) {
      return "Tumblr Post";
    }
    if (RegExp(r'^snapchat_[A-Za-z0-9_-]+$').hasMatch(clean)) {
      return "Snapchat Story";
    }
    clean = clean.trim();
    return clean.isNotEmpty ? clean : "Downloaded Media";
  }

  static String _fmt(String quality) {
    final q = quality.toLowerCase();

    if (q.contains('best')) return '📺 Best Quality (Recommended)';
    if (q.contains('hd no watermark')) return '📺 HD No Watermark (Best)';
    if (q.contains('standard no watermark')) return '📺 Standard No Watermark';
    if (q.contains('with watermark')) return '📺 With Watermark';
    if (q.contains('hd')) return '📺 HD Quality';
    if (q.contains('standard')) return '📺 Standard Quality';
    if (q.contains('watermark')) return '📺 With Watermark';

    if (q.startsWith('video')) return '📺 $quality';
    if (q.startsWith('gif')) return '🎞️ $quality';
    if (q.startsWith('image')) return '🖼️ $quality (Photo)';

    if (q.contains('audio')) return '🎵 Audio Only';

    return '📺 $quality';
  }
}
