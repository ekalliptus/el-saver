import 'dart:async';

import 'package:el_saver/src/container_injector.dart';
import 'package:el_saver/src/core/services/premium_service.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
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
  // Retention-only: never read. Holds the on-screen ad strongly so GC
  // can't collect the Dart-side object mid-display.
  // ignore: unused_field
  InterstitialAd? _showing;
  bool _loading = false;
  Timer? _preloadTimer;

  /// Show the interstitial every Nth user download action. Remote Config
  /// knob (`interstitial_every_n`) so frequency can change without a
  /// release; falls back to 2 until Remote Config has defaults registered.
  int get _everyN {
    try {
      final n = FirebaseRemoteConfig.instance.getInt('interstitial_every_n');
      if (n >= 1) return n;
    } catch (_) {}
    return 2;
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _successCount = prefs.getInt(_prefsKey) ?? 0;
      _lastShownMs = prefs.getInt(_lastShownKey);
    } catch (_) {}
    await _preload();
    // Keep an ad warm: without this, a failed preload left nothing ready
    // and the due moment silently skipped the ad.
    _preloadTimer?.cancel();
    _preloadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_loaded == null && !_loading) _preload();
    });
  }

  /// Ad unit for the next load: test unit in debug, the Remote Config unit
  /// in release. Null in release until Remote Config has been fetched —
  /// never fall back to the test unit for production traffic.
  String? _resolveAdUnitId() {
    if (kDebugMode) return _testAdUnitId;
    try {
      final remote =
          FirebaseRemoteConfig.instance.getString('interstitial_ad_unit_id');
      if (remote.trim().isNotEmpty) return remote.trim();
    } catch (_) {}
    return null;
  }

  Future<void> _preload() async {
    if (_loading || _loaded != null) return;
    // Premium users never see ads — don't request any either.
    try {
      if (sl<PremiumService>().isPremium) return;
    } catch (_) {}
    final unitId = _resolveAdUnitId();
    if (unitId == null) return;
    _loading = true;
    try {
      await InterstitialAd.load(
        adUnitId: unitId,
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

  /// Call on every user-initiated download/save action. Shows the
  /// interstitial when the frequency gates pass; always keeps the next
  /// ad preloaded.
  Future<void> onUserDownloadAction() async {
    try {
      if (sl<PremiumService>().isPremium) return;
    } catch (_) {}
    _successCount++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, _successCount);
    } catch (_) {}

    const minInterval = Duration(minutes: 2);
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastOk = _lastShownMs == null ||
        now - _lastShownMs! >= minInterval.inMilliseconds;
    final due = _successCount % _everyN == 0;

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
    // Strong reference for the whole presentation: after show() returns,
    // the local goes out of scope and GC could collect the Dart-side ad
    // object mid-display — the ad then closed itself ("hilang sendiri")
    // while the close button was already on screen.
    _showing = ad;
    // The tap that triggered us also pops a sheet and pushes a route;
    // letting that transition settle first avoids the close-button
    // jank/freeze reported when the ad opened mid-navigation.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    var finished = false;
    void finish(InterstitialAd ad) {
      if (finished) return; // callbacks can fire twice on some devices
      finished = true;
      _showing = null;
      ad.dispose();
      _preload();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: finish,
      onAdFailedToShowFullScreenContent: (ad, _) => finish(ad),
    );
    _lastShownMs = nowMs;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastShownKey, nowMs);
    } catch (_) {}
    try {
      await ad.show();
    } catch (_) {
      finish(ad); // e.g. activity paused mid-flow; never leak the ad
    }
  }
}
