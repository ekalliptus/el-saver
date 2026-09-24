import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:el_saver/src/config/routes_manager.dart';
import 'package:el_saver/src/container_injector.dart';
import 'package:el_saver/src/core/utils/app_strings.dart';
import 'package:el_saver/src/core/services/premium_service.dart';
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
      await sl<PremiumService>().verify();
      await _updateService.initialize();
      _updateService.startPeriodicCheck();
      _updateSub = _updateService.updateStream.listen((info) {
        if (mounted && !_dialogShowing) _showUpdateDialog(info);
      });
    });
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
