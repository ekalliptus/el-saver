import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_saver/src/config/routes_manager.dart';
import 'package:el_saver/src/container_injector.dart';
import 'package:el_saver/src/core/utils/app_colors.dart';
import 'package:el_saver/src/core/utils/app_strings.dart';
import 'package:el_saver/src/core/services/premium_service.dart';
import 'package:el_saver/src/core/services/permission_service.dart';
import 'package:el_saver/src/core/services/update_service.dart';
import 'package:el_saver/src/core/services/app_open_ad_service.dart';
import 'package:el_saver/src/core/services/app_readiness.dart';
import 'package:el_saver/src/core/widgets/update_dialog.dart';
import 'package:el_saver/src/core/providers/language_provider.dart';
import 'package:el_saver/src/features/social_videos_downloader/presentation/bloc/downloader_bloc/downloader_bloc.dart';
import 'package:el_saver/src/features/social_videos_downloader/presentation/bloc/theme_bloc/theme_bloc.dart';
import 'dart:async';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final UpdateService _updateService;
  StreamSubscription<UpdateInfo>? _updateSub;
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    _updateService = sl<UpdateService>();
    // App-open ads: preload now, but the cold-start SHOW moved to
    // MainShellScreen so it never covers splash/onboarding/permission setup.
    AppOpenAdService.instance.initialize();

    // Everything below surfaces UI on its own schedule — the permission
    // nudge, update dialogs and the premium promo. They must wait until
    // the main shell is on screen (readiness gate), then settle a few
    // seconds, so they never race the splash → onboarding → permission
    // setup flow.
    unawaited(_runPostSetupSequence());
  }

  Future<void> _runPostSetupSequence() async {
    await AppReadiness.waitUntilReady();
    await Future<void>.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    await _maybeNudgePermissions();
    await sl<PremiumService>().verify();
    await _updateService.initialize();
    _updateService.startPeriodicCheck();
    _updateSub = _updateService.updateStream.listen((info) {
      if (mounted && !_dialogShowing) _showUpdateDialog(info);
    });
    // E: periodic premium promo — every 3 days, never overlaps dialogs.
    await _maybeShowPremiumPromo();
  }

  /// E: promotion sheet for non-premium users, at most once per 3 days.
  /// Runs after everything else so it never fights the permission nudge,
  /// premium verify or the update dialog.
  Future<void> _maybeShowPremiumPromo() async {
    try {
      if (sl<PremiumService>().isPremium) return;
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final interval = const Duration(days: 3).inMilliseconds;
      final last = prefs.getInt('premium_promo_last') ?? 0;
      if (now - last < interval) return;
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted || _dialogShowing) return;
      await prefs.setInt('premium_promo_last', now);
      _dialogShowing = true;
      try {
        await showModalBottomSheet<bool>(
          // ignore: use_build_context_synchronously
          context: ctx,
          isDismissible: true,
          enableDrag: true,
          useRootNavigator: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.workspace_premium,
                      color: AppColors.primaryColor, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(AppStrings.promoTitle,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(AppStrings.promoBody,
                    style: const TextStyle(fontSize: 14, height: 1.4)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      final activated =
                          await sl<PremiumService>().startTrial();
                      if (activated) {
                        final toastCtx = navigatorKey.currentContext;
                        if (toastCtx != null && toastCtx.mounted) {
                          ScaffoldMessenger.of(toastCtx).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Trial 3 hari aktif — iklan hilang!'),
                              backgroundColor: AppColors.green,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.flash_on, size: 18),
                    label: Text(AppStrings.promoCta),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Nanti'),
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      } finally {
        _dialogShowing = false;
      }
    } catch (_) {
      // Promo is best-effort; never block startup.
    }
  }

  /// Re-offer permission activation to users who upgraded from older
  /// versions (new permissions were added since). Throttled to once per
  /// 72 hours so it never becomes annoying.
  Future<void> _maybeNudgePermissions() async {
    final permissionService = PermissionService();
    try {
      if (_dialogShowing) return;
      if (!await permissionService.hasMissingCriticalPermissions()) return;
      final prefs = await SharedPreferences.getInstance();
      final lastNudge = prefs.getInt('perm_nudge_last') ?? 0;
      final hoursSince = DateTime.now().millisecondsSinceEpoch - lastNudge;
      if (hoursSince < const Duration(hours: 72).inMilliseconds) return;
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      _dialogShowing = true;
      final activate = await showDialog<bool>(
        context: ctx,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(Icons.shield_outlined,
              size: 44, color: AppColors.primaryColor),
          title: Text(AppStrings.completeAppPermissions),
          content: Text(
            AppStrings.permissionNudgeContent,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppStrings.notNow),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.shield, size: 18),
              label: Text(AppStrings.activateNow),
            ),
          ],
        ),
      );
      _dialogShowing = false;
      await prefs.setInt(
          'perm_nudge_last', DateTime.now().millisecondsSinceEpoch);
      if (activate == true && ctx.mounted) {
        await Navigator.of(ctx).pushNamed(Routes.permissionSetup);
      }
    } catch (_) {
      // Nudge is best-effort; never block startup.
    } finally {
      _dialogShowing = false;
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || _dialogShowing) return;

    _dialogShowing = true;
    showDialog(
      context: ctx,
      barrierDismissible: !info.isForced,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: !info.isForced,
        child: UpdateDialog(updateInfo: info, updateService: _updateService),
      ),
    ).then((_) => _dialogShowing = false);
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _updateService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<DownloaderBloc>(create: (_) => sl<DownloaderBloc>()),
          BlocProvider<ThemeBloc>(create: (_) => sl<ThemeBloc>()),
        ],
        child: Consumer<LanguageProvider>(
          builder: (context, _, child) {
            return BlocBuilder<ThemeBloc, ThemeState>(
              builder: (context, state) {
                return MaterialApp(
                  navigatorKey: navigatorKey,
                  title: AppStrings.appName,
                  debugShowCheckedModeBanner: false,
                  theme: state.themeData,
                  darkTheme: ThemeState.darkTheme.themeData,
                  themeMode: state.themeData.brightness == Brightness.dark
                      ? ThemeMode.dark
                      : ThemeMode.light,
                  initialRoute: Routes.splash,
                  onGenerateRoute: AppRounter.getRoute,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
