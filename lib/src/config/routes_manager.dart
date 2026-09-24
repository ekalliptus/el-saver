import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'dart:developer' as developer;

import '../core/utils/app_constants.dart';
import '../features/cookie_auth/presentation/bloc/account_bloc.dart';
import '../features/cookie_auth/presentation/bloc/account_event.dart';
import '../features/cookie_auth/presentation/screens/accounts_screen.dart';
import '../features/cookie_auth/presentation/screens/legal_screen.dart';
import '../features/cookie_auth/presentation/screens/webview_login_screen.dart';
import '../features/social_videos_downloader/presentation/screens/downloader_screen.dart';
import '../features/social_videos_downloader/presentation/screens/downloads_screen.dart';
import '../features/social_videos_downloader/presentation/widgets/downloads_screen/view_video_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/whatsapp_status/presentation/screens/whatsapp_status_screen.dart';
import '../core/screens/permission_setup_screen.dart';

class Routes {
  static const String splash = "/splash";
  static const String downloader = "/downloader";
  static const String downloads = "/downloads";
  static const String viewVideo = "/viewVideo";
  static const String permissionSetup = "/permissionSetup";
  static const String accounts = "/accounts";
  static const String webviewLogin = "/webviewLogin";
  static const String legal = "/legal";
  static const String whatsappStatus = "/whatsappStatus";
}

class AppRounter {
  static Route? getRoute(RouteSettings setting) {
    developer.log('🚀 AppRouter.getRoute called for: ${setting.name}',
        name: 'AppRouter');

    switch (setting.name) {
      case Routes.splash:
        developer.log('✅ Creating SplashScreen route', name: 'AppRouter');
        return MaterialPageRoute(builder: (context) {
          developer.log('🎬 SplashScreen widget builder called',
              name: 'AppRouter');
          return const SplashScreen();
        });
      case Routes.downloader:
        developer.log('✅ Creating DownloaderScreen route', name: 'AppRouter');
        return MaterialPageRoute(
            builder: (context) => const DownloaderScreen());
      case Routes.downloads:
        developer.log('✅ Creating DownloadsScreen route', name: 'AppRouter');
        return MaterialPageRoute(builder: (context) => const DownloadsScreen());
      case Routes.whatsappStatus:
        return MaterialPageRoute(
            builder: (context) => const WhatsappStatusScreen());
      case Routes.viewVideo:
        developer.log('✅ Creating ViewVideoScreen route', name: 'AppRouter');
        return MaterialPageRoute(
            builder: (context) => ViewVideoScreen(
                  videoPath: setting.arguments as String,
                ));
      case Routes.permissionSetup:
        developer.log('✅ Creating PermissionSetupScreen route',
            name: 'AppRouter');
        return MaterialPageRoute(
            builder: (context) => const PermissionSetupScreen());
      case Routes.accounts:
        return MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (_) => GetIt.I<AccountBloc>()..add(LoadAccounts()),
            child: const AccountsScreen(),
          ),
        );
      case Routes.webviewLogin:
        final platform = setting.arguments as SocialPlatform;
        return MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (_) => GetIt.I<AccountBloc>(),
            child: WebViewLoginScreen(platform: platform),
          ),
        );
      case Routes.legal:
        final tab = setting.arguments is int ? setting.arguments as int : 0;
        return MaterialPageRoute(
            builder: (context) => LegalScreen(initialTab: tab));
      default:
        developer.log('❌ Unknown route: ${setting.name}', name: 'AppRouter');
        return null;
    }
  }
}
