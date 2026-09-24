import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'package:el_saver/bloc_observer.dart';
import 'package:el_saver/src/container_injector.dart';
import 'package:el_saver/src/my_app.dart';
import 'package:el_saver/src/core/services/premium_service.dart';
import 'package:el_saver/src/core/services/language_service.dart';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await MobileAds.instance.initialize();
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    developer.log('Firebase initialized', name: 'Main');
  } catch (e) {
    developer.log('Firebase init failed (app continues): $e', name: 'Main');
  }

  try {
    initApp();
    Bloc.observer = MyBlockObserver();

    await LanguageService.instance.initialize();
    await LanguageService.instance.autoDetectLanguage();
    await sl<PremiumService>().initialize();

    runApp(const MyApp());
  } catch (e) {
    developer.log('Critical error: $e', name: 'Main');
    try {
      initApp();
      Bloc.observer = MyBlockObserver();
    } catch (_) {}
    runApp(const MyApp());
  }
}
