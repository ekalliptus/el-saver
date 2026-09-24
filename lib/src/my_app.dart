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

    // Init + start update checks after app is ready
    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;
      await _maybeNudgePermissions();
      await sl<PremiumService>().verify();
      await _updateService.initialize();
      _updateService.startPeriodicCheck();
      _updateSub = _updateService.updateStream.listen((info) {
        if (mounted && !_dialogShowing) _showUpdateDialog(info);
      });
    });
  }

  /// Re-offer permission activation to users who upgraded from older
  /// versions (new permissions were added since). Throttled to once per
  /// 72 hours so it never becomes annoying.
  Future<void> _maybeNudgePermissions() async {
    final permissionService = PermissionService();
    try {
      if (!await permissionService.hasMissingCriticalPermissions()) return;
      final prefs = await SharedPreferences.getInstance();
      final lastNudge = prefs.getInt('perm_nudge_last') ?? 0;
      final hoursSince = DateTime.now().millisecondsSinceEpoch - lastNudge;
      if (hoursSince < const Duration(hours: 72).inMilliseconds) return;
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      final activate = await showDialog<bool>(
        context: ctx,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(Icons.shield_outlined,
              size: 44, color: AppColors.primaryColor),
          title: const Text('Lengkapi izin aplikasi'),
          content: const Text(
            'Versi baru EL-Saver butuh izin tambahan: akses media (fitur '
            'Status WhatsApp) dan akses file lengkap. Tanpa itu, sebagian '
            'fitur tidak berfungsi.\n\nAktifkan sekarang? Prosesnya cepat, '
            'tinggal ikuti beberapa halaman pengaturan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Nanti'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.shield, size: 18),
              label: const Text('Aktifkan Sekarang'),
            ),
          ],
        ),
      );
      await prefs.setInt(
          'perm_nudge_last', DateTime.now().millisecondsSinceEpoch);
      if (activate == true && ctx.mounted) {
        await Navigator.of(ctx).pushNamed(Routes.permissionSetup);
      }
    } catch (_) {
      // Nudge is best-effort; never block startup.
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
