import '../../../../core/error/failure.dart';
import '../../../../core/utils/app_constants.dart';
import '../../domain/entities/download_item.dart';

class DownloadErrorClassifier {
  static Failure classify(String rawMessage, String sourceUrl,
      {String sourceCode = ''}) {
    final message = rawMessage.toLowerCase();
    final detected = DownloadItem.detectPlatform(sourceUrl);
    final platform = detected == SocialPlatform.youtubeMusic
        ? SocialPlatform.youtube
        : detected;

    final excluded = message.contains('not a bot') ||
        message.contains('prove that it') ||
        message.contains('not available in your country') ||
        message.contains('geo') ||
        message.contains('drm') ||
        message.contains('unsupported') ||
        message.contains('invalid url');
    if (!excluded && _requiresLogin(message)) {
      return AuthRequiredFailure(
        platform: platform,
        sourceCode: sourceCode,
        message:
            'Video ${_name(platform)} tidak bisa diambil karena platformnya '
            'menolak akses tanpa login (konten private atau dibatasi anti-bot). '
            'Login sekali saja, setelah itu video bisa diunduh otomatis.',
      );
    }
    return ServerFailure(message: rawMessage);
  }

  static bool _requiresLogin(String message) =>
      message.contains('login required') ||
      message.contains('log in') ||
      message.contains('sign in') ||
      message.contains('registered users') ||
      message.contains('login page') ||
      message.contains('private account') ||
      message.contains('requires authentication');

  static String _name(SocialPlatform platform) =>
      DownloadItem.platformNameOf(platform);
}
