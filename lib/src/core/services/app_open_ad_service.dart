import 'dart:async';

import 'package:el_saver/src/container_injector.dart';
import 'package:el_saver/src/core/services/premium_service.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Full-screen ad on app open / return-from-background. Google's own
/// guidance: show at natural open transitions, skip when the user is
/// mid-task (we skip if a download is active to avoid interrupting).
class AppOpenAdService with WidgetsBindingObserver {
  AppOpenAdService._();
  static final AppOpenAdService instance = AppOpenAdService._();

  static const _testAdUnitId = 'ca-app-pub-3940256099942544/9257395921';

  AppOpenAd? _loaded;
  bool _loading = false;
  bool _showing = false;
  DateTime? _loadedAt;
  // AdMob app-open creatives expire after 4 hours.
  static const _maxAge = Duration(hours: 4);
  // Never immediately re-show after the last dismissal.
  static const _minGap = Duration(minutes: 3);
  DateTime? _lastShownAt;

  bool get _enabled {
    try {
      if (sl<PremiumService>().isPremium) return false;
      final unit = _resolveAdUnitId();
      return unit != null;
    } catch (_) {
      return false;
    }
  }

  String? _resolveAdUnitId() {
    if (kDebugMode) return _testAdUnitId;
    try {
      final remote =
          FirebaseRemoteConfig.instance.getString('appopen_ad_unit_id');
      if (remote.trim().isNotEmpty) return remote.trim();
    } catch (_) {}
    return null;
  }

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await _preload();
  }

  Future<void> _preload() async {
    if (_loading || (_loaded != null && !_isExpired)) return;
    if (!_enabled) return;
    final unitId = _resolveAdUnitId();
    if (unitId == null) return;
    _loading = true;
    try {
      await AppOpenAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _loaded = ad;
            _loadedAt = DateTime.now();
          },
          onAdFailedToLoad: (_) => _loaded = null,
        ),
      );
    } catch (_) {
      _loaded = null;
    } finally {
      _loading = false;
    }
  }

  bool get _isExpired =>
      _loadedAt == null || DateTime.now().difference(_loadedAt!) > _maxAge;

  /// Cold start: call from the splash when navigation to the home screen
  /// has settled (~600ms) so the ad never blocks first paint.
  Future<void> maybeShowOnLaunch() async {
    if (!_enabled) return;
    if (_loaded == null) {
      await _preload();
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _show();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeShowOnResume();
    } else if (state == AppLifecycleState.paused) {
      // Preload while backgrounded so the next resume has a fresh ad.
      _preload();
    }
  }

  Future<void> _maybeShowOnResume() async {
    if (_showing || !_enabled) return;
    final now = DateTime.now();
    if (_lastShownAt != null &&
        now.difference(_lastShownAt!) < _minGap) {
      return;
    }
    if (_loaded == null) {
      await _preload();
      if (_loaded == null) return;
    }
    await _show();
  }

  Future<void> _show() async {
    final ad = _loaded;
    if (ad == null || _showing) return;
    _showing = true;
    _loaded = null;
    _lastShownAt = DateTime.now();
    var finished = false;
    void finish() {
      if (finished) return;
      finished = true;
      _showing = false;
      ad.dispose();
      _preload();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, __) => finish(),
    );
    try {
      await ad.show();
    } catch (_) {
      finish();
    }
  }
}
