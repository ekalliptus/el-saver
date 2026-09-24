import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Compare two semver strings ("x.y.z"). Returns true if [remote] > [local].
/// Robust to missing components ("1.6" == "1.6.0") and stray build suffixes.
bool isNewerVersionName(String remote, String local) {
  List<int> parse(String v) => v
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
  final r = parse(remote);
  final l = parse(local);
  final n = r.length > l.length ? r.length : l.length;
  for (var i = 0; i < n; i++) {
    final rv = i < r.length ? r[i] : 0;
    final lv = i < l.length ? l[i] : 0;
    if (rv != lv) return rv > lv;
  }
  return false;
}

/// Map an Android ABI to the split-per-abi release APK filename.
String abiApkFileName(List<String> supportedAbis) {
  // Priority: arm64 > armv7 > x86_64 (matches `flutter build --split-per-abi`)
  if (supportedAbis.contains('arm64-v8a')) return 'app-arm64-v8a-release.apk';
  if (supportedAbis.contains('armeabi-v7a')) {
    return 'app-armeabi-v7a-release.apk';
  }
  if (supportedAbis.contains('x86_64')) return 'app-x86_64-release.apk';
  // Unknown ABI: fall back to arm64 (most common modern default)
  return 'app-arm64-v8a-release.apk';
}

class UpdateService {
  Timer? _checkTimer;
  final _updateController = StreamController<UpdateInfo>.broadcast();

  Stream<UpdateInfo> get updateStream => _updateController.stream;

  Future<void> initialize() async {
    try {
      final config = FirebaseRemoteConfig.instance;
      await config.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 5),
      ));
      await config.setDefaults({
        'latest_version_name': '1.6.0',
        'latest_version_code': 8,
        // Folder holding the split-per-abi APKs, e.g. a GitHub release:
        // https://github.com/<owner>/<repo>/releases/download/v1.6.0
        'download_url_base': '',
        // Legacy single-URL fallback (used verbatim if download_url_base empty)
        'download_url': '',
        'changelog': '',
        'is_forced': false,
      });
      await config.fetchAndActivate();
      developer.log('Firebase Remote Config initialized',
          name: 'UpdateService');
    } catch (e) {
      developer.log('Remote Config init failed: $e', name: 'UpdateService');
    }
  }

  void startPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      checkForUpdate();
    });
    // Initial check after 5 seconds
    Future.delayed(const Duration(seconds: 5), checkForUpdate);
  }

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final config = FirebaseRemoteConfig.instance;
      await config.fetchAndActivate();

      final latestVersionCode = config.getInt('latest_version_code');
      final latestVersionName = config.getString('latest_version_name');
      final downloadUrlBase = config.getString('download_url_base').trim();
      final legacyUrl = config.getString('download_url').trim();
      final changelog = config.getString('changelog');
      final isForcedStr = config.getString('is_forced').toLowerCase();
      final isForced = isForcedStr == 'true' || isForcedStr == '1';

      final packageInfo = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      // Compare by semver name: split-per-abi offsets the versionCode
      // (armv7 +1000 / arm64 +2000 / x86_64 +4000) so codes aren't comparable.
      final isNewer =
          isNewerVersionName(latestVersionName, packageInfo.version);

      // Resolve the right APK for this device's ABI.
      final downloadUrl = await _resolveDownloadUrl(downloadUrlBase, legacyUrl);

      if (isNewer && downloadUrl.isNotEmpty) {
        final info = UpdateInfo(
          versionName: latestVersionName,
          versionCode: latestVersionCode,
          currentVersionCode: currentCode,
          currentVersionName: packageInfo.version,
          downloadUrl: downloadUrl,
          changelog: changelog,
          isForced: isForced,
        );
        _updateController.add(info);
        developer.log('Update available: $latestVersionName',
            name: 'UpdateService');
        return info;
      }
    } catch (e) {
      developer.log('Update check failed: $e', name: 'UpdateService');
    }
    return null;
  }

  /// Build the download URL for this device's ABI. Prefers [base] +
  /// per-abi filename; falls back to [legacy] single URL when base is empty.
  Future<String> _resolveDownloadUrl(String base, String legacy) async {
    if (base.isEmpty) return legacy;
    List<String> abis = const [];
    try {
      if (Platform.isAndroid) {
        abis = (await DeviceInfoPlugin().androidInfo).supportedAbis;
      }
    } catch (e) {
      developer.log('ABI detection failed: $e', name: 'UpdateService');
    }
    final file = abiApkFileName(abis);
    final trimmed =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$trimmed/$file';
  }

  Future<String?> downloadUpdate(String url,
      {Function(double)? onProgress}) async {
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/el_saver_update.apk';

      // Delete old file if exists
      final oldFile = File(savePath);
      if (oldFile.existsSync()) await oldFile.delete();

      final dio = Dio(BaseOptions(
        followRedirects: true,
        maxRedirects: 5,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 10),
      ));

      // Stream manually: dio.download's onReceiveProgress reports the
      // Content-Length of the FIRST hop, which for GitHub is a 302 with
      // content-length: 0 -> total stays 0 and progress sticks/estimates.
      // Reading the final streamed response gives the real length + live bytes.
      final response = await dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            "Accept": "application/vnd.android.package-archive,*/*",
            "User-Agent": "ELSaver/1.0",
          },
        ),
      );

      final total = int.tryParse(
              response.headers.value(Headers.contentLengthHeader) ?? '') ??
          -1;

      final raf = File(savePath).openSync(mode: FileMode.write);
      int received = 0;
      try {
        await for (final chunk in response.data!.stream) {
          raf.writeFromSync(chunk);
          received += chunk.length;
          if (onProgress != null && total > 0) {
            onProgress((received / total).clamp(0.0, 1.0));
          }
        }
      } finally {
        await raf.close();
      }
      if (onProgress != null) onProgress(1.0);

      // Validate downloaded file is actually an APK
      final file = File(savePath);
      if (!file.existsSync() || file.lengthSync() < 1000) {
        developer.log('Download invalid: file too small or missing',
            name: 'UpdateService');
        return null;
      }

      // Check APK magic bytes (PK zip header: 50 4B 03 04)
      final bytes = file.readAsBytesSync().take(4).toList();
      if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
        developer.log('Download invalid: not an APK file',
            name: 'UpdateService');
        await file.delete();
        return null;
      }

      return savePath;
    } catch (e) {
      developer.log('Download update failed: $e', name: 'UpdateService');
      return null;
    }
  }

  /// Open the APK with the system package installer (shows the standard
  /// install popup). This is the only install path — no silent installs.
  Future<bool> installUpdateManual(String apkPath) async {
    try {
      if (Platform.isAndroid) {
        await OpenFile.open(apkPath);
        return true;
      }
    } catch (e) {
      developer.log('Manual install failed: $e', name: 'UpdateService');
    }
    return false;
  }

  void dispose() {
    _checkTimer?.cancel();
    _updateController.close();
  }
}

class UpdateInfo {
  final String versionName;
  final int versionCode;
  final int currentVersionCode;
  final String currentVersionName;
  final String downloadUrl;
  final String changelog;
  final bool isForced;

  UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.currentVersionCode,
    required this.currentVersionName,
    required this.downloadUrl,
    this.changelog = '',
    this.isForced = false,
  });

  bool get isNewerVersion => versionCode > currentVersionCode;
}

enum UpdateStatus { idle, checking, available, downloading, installing, error }
