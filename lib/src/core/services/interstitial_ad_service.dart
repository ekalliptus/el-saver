import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Full-screen interstitial shown at a natural break (right after a download
/// completes). Frequency-capped so it never becomes an AdMob policy risk:
/// every 3 completed downloads and at most once per 10 minutes. Premium
/// users never see it (caller checks).
class InterstitialAdService {
  InterstitialAdService._();
  static final InterstitialAdService instance = InterstitialAdService._();

  static const _prefsKey = 'interstitial_success_count';
  static const _lastShownKey = 'interstitial_last_shown_at';

  /// Google's public interstitial test unit (safe to render in any build).
  static const _testAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  int _successCount = 0;
  int? _lastShownMs;
  InterstitialAd? _loaded;
  bool _loading = false;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _successCount = prefs.getInt(_prefsKey) ?? 0;
      _lastShownMs = prefs.getInt(_lastShownKey);
    } catch (_) {}
    await _preload();
  }

  String _resolveAdUnitId() {
    // Production unit comes from Remote Config so it can be changed or
    // killed without shipping an app update; empty -> Google test unit.
    try {
      final remote =
          FirebaseRemoteConfig.instance.getString('interstitial_ad_unit_id');
      if (remote.trim().isNotEmpty) return remote.trim();
    } catch (_) {}
    return _testAdUnitId;
  }

  Future<void> _preload() async {
    if (_loading || _loaded != null) return;
    _loading = true;
    try {
      await InterstitialAd.load(
        adUnitId: _resolveAdUnitId(),
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _loaded = ad,
          onAdFailedToLoad: (_) => _loaded = null,
        ),
      );
    } catch (_) {
      _loaded = null;
    } finally {
      _loading = false;
    }
  }

  /// Call on every download success. Shows the interstitial when the
  /// frequency gates pass; always keeps the next ad preloaded.
  Future<void> onDownloadSuccess() async {
    _successCount++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, _successCount);
    } catch (_) {}

    const everyN = 3;
    const minInterval = Duration(minutes: 10);
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastOk = _lastShownMs == null ||
        now - _lastShownMs! >= minInterval.inMilliseconds;
    final due = _successCount % everyN == 0;

    if (due && lastOk) {
      await _show(now);
    }
    await _preload();
  }

  Future<void> _show(int nowMs) async {
    final ad = _loaded;
    _loaded = null;
    if (ad == null) {
      await _preload();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _preload();
      },
    );
    _lastShownMs = nowMs;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastShownKey, nowMs);
    } catch (_) {}
    await ad.show();
  }
}
