// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:el_saver/src/core/utils/app_strings.dart';
import 'package:el_saver/src/core/services/permission_service.dart';
import 'package:el_saver/src/core/providers/language_provider.dart';
import 'package:el_saver/src/container_injector.dart';
import '../../config/routes_manager.dart';
import '../../core/utils/app_assets.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/app_constants.dart';
import '../../core/utils/preload_svg_assets.dart';
import 'dart:developer' as developer;

/// Splash with an ambient brand glow, expanding pulse rings, staggered
/// logo/text entrance and a determinate-feeling progress bar.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _contentController;
  late final AnimationController _pulseController;
  late final AnimationController _progressController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _loaderOpacity;
  late final Animation<double> _ringScale1;
  late final Animation<double> _ringOpacity1;
  late final Animation<double> _ringScale2;
  late final Animation<double> _ringOpacity2;
  late final PermissionService _permissionService;
  bool _hasNavigated = false;

  @override
  initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF121212),
      ),
    );

    _permissionService = sl<PermissionService>();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _textSlide = Tween(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );
    _loaderOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // Expanding sonar rings around the logo, on repeat.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _ringScale1 = Tween(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(
          parent: _pulseController, curve: const Interval(0.0, 0.7)),
    );
    _ringOpacity1 = Tween(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(
          parent: _pulseController, curve: const Interval(0.0, 0.7)),
    );
    _ringScale2 = Tween(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(
          parent: _pulseController, curve: const Interval(0.3, 1.0)),
    );
    _ringOpacity2 = Tween(begin: 0.35, end: 0.0).animate(
      CurvedAnimation(
          parent: _pulseController, curve: const Interval(0.3, 1.0)),
    );

    // Progress bar fills over the whole splash, slowly — reads as loading.
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _logoController.forward().then((_) {
      if (mounted) {
        _contentController.forward();
        _pulseController.repeat();
        _progressController.forward();
      }
    });

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final preloadFuture = _preloadAssets();
      final timeFuture = Future.delayed(
          const Duration(milliseconds: AppConstants.navigateTime));

      await Future.wait([preloadFuture, timeFuture]).timeout(
        const Duration(seconds: 5),
        onTimeout: () => [],
      );

      await _checkPermissionsAndNavigate();
    } catch (e) {
      developer.log('Init error: $e', name: 'SplashScreen');
      if (!_hasNavigated) _navigateToDownloader();
    }
  }

  Future<void> _checkPermissionsAndNavigate() async {
    if (_hasNavigated) return;

    try {
      final result = await Future.any([
        Future.delayed(const Duration(seconds: 2), () => {'timeout': true}),
        _performPermissionCheck(),
      ]);

      if (_hasNavigated) return;

      if (result['timeout'] == true) {
        _navigateToDownloader();
        return;
      }

      final isFirstLaunch = result['isFirstLaunch'] as bool;
      final permissionsGranted = result['permissionsGranted'] as bool;

      if (mounted && !_hasNavigated) {
        if (isFirstLaunch) {
          // First launch: the onboarding walkthrough comes before everything.
          _hasNavigated = true;
          Navigator.of(context)
              .pushNamedAndRemoveUntil(Routes.onboarding, (route) => false);
        } else if (!permissionsGranted) {
          _navigateToPermissionSetup();
        } else {
          _navigateToDownloader();
        }
      }
    } catch (e) {
      if (!_hasNavigated) _navigateToDownloader();
    }
  }

  Future<Map<String, dynamic>> _performPermissionCheck() async {
    try {
      final isFirstLaunch = await _permissionService.isFirstLaunch();
      final permissionsGranted =
          await _permissionService.areAllPermissionsGranted();
      return {
        'isFirstLaunch': isFirstLaunch,
        'permissionsGranted': permissionsGranted,
      };
    } catch (_) {
      // Assume NOT granted: the permission setup screen re-checks and lets
      // the user through; silently claiming granted would skip setup forever.
      return {'isFirstLaunch': false, 'permissionsGranted': false};
    }
  }

  Future<void> _preloadAssets() async {
    try {
      PreLoadAssets preLoadAssets = PreLoadAssets();
      await preLoadAssets.preLoadLoadingScreenAssets();
    } catch (_) {}
  }

  void _navigateToPermissionSetup() {
    if (mounted && !_hasNavigated) {
      // A back-press during init can leave delayed callbacks running after
      // the user has moved on; never yank them into permission setup then.
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      _hasNavigated = true;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(Routes.permissionSetup, (route) => false);
    }
  }

  void _navigateToDownloader() {
    if (mounted && !_hasNavigated) {
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      _hasNavigated = true;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(Routes.downloader, (route) => false);
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = size.width * 0.28;

    return Consumer<LanguageProvider>(
      builder: (context, _, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: SizedBox.expand(
            child: Column(
              children: [
                const Spacer(flex: 4),

                // Logo + ambient glow + expanding sonar rings.
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Ambient brand glow behind everything.
                    Container(
                      width: logoSize * 2.2,
                      height: logoSize * 2.2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primaryColor.withOpacity(0.35),
                            AppColors.primaryColor.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _ringScale2.value,
                          child: Opacity(
                            opacity: _ringOpacity2.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: logoSize * 1.55,
                        height: logoSize * 1.55,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryColorLight.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _ringScale1.value,
                          child: Opacity(
                            opacity: _ringOpacity1.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: logoSize * 1.25,
                        height: logoSize * 1.25,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: child,
                          ),
                        );
                      },
                      child: SizedBox(
                        width: logoSize,
                        height: logoSize,
                        child: Image.asset(
                          AppAssets.splashLogo,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // App name + slogan
                AnimatedBuilder(
                  animation: _contentController,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _textSlide,
                      child: Opacity(
                        opacity: _textOpacity.value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        AppStrings.appName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.95),
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppStrings.appSlogan,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withOpacity(0.4),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 5),

                // Slim determinate-feeling progress bar at the bottom.
                AnimatedBuilder(
                  animation: _contentController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _loaderOpacity.value,
                      child: child,
                    );
                  },
                  child: SizedBox(
                    width: 160,
                    height: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, _) {
                          return Stack(
                            children: [
                              Container(
                                color: Colors.white.withOpacity(0.08),
                              ),
                              FractionallySizedBox(
                                widthFactor:
                                    0.15 + 0.75 * _progressController.value,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primaryColor,
                                        const Color(0xFF38BDF8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),

                SizedBox(height: size.height * 0.06),
              ],
            ),
          ),
        );
      },
    );
  }
}
