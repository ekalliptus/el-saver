import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../container_injector.dart';
import 'data/data_source/cookie_local_data_source.dart';
import 'data/data_source/cookie_remote_data_source.dart';
import 'data/repositories/cookie_repo_impl.dart';
import 'data/services/cookie_extraction_service.dart';
import 'domain/repositories/cookie_repo.dart';
import 'presentation/bloc/account_bloc.dart';

void initCookieAuth() {
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  sl.registerLazySingleton<CookieLocalDataSource>(
    () => CookieLocalDataSource(storage: sl()),
  );

  sl.registerLazySingleton<CookieRemoteDataSource>(
    () => CookieRemoteDataSource(),
  );

  sl.registerLazySingleton<CookieExtractionService>(
    () => CookieExtractionService(),
  );

  sl.registerLazySingleton<CookieRepo>(
    () => CookieRepoImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
    ),
  );

  // Singleton: the webview login screen and the accounts screen must share
  // one bloc, or the login sync-status states never reach the accounts UI.
  sl.registerLazySingleton(
    () => AccountBloc(cookieRepo: sl(), extractionService: sl()),
  );
}
