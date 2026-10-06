import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/cookie_extraction_service.dart';
import '../../domain/entities/platform_cookie.dart';
import '../../domain/repositories/cookie_repo.dart';
import 'account_event.dart';
import 'account_state.dart';

class AccountBloc extends Bloc<AccountEvent, AccountState> {
  final CookieRepo cookieRepo;
  final CookieExtractionService extractionService;

  AccountBloc({
    required this.cookieRepo,
    required this.extractionService,
  }) : super(AccountsInitial()) {
    on<LoadAccounts>(_onLoad);
    on<CookiesExtracted>(_onCookiesExtracted);
    on<LogoutFromPlatform>(_onLogout);
  }

  Future<void> _onLoad(LoadAccounts event, Emitter<AccountState> emit) async {
    emit(AccountsLoading());
    final cookies = await cookieRepo.getAllCookies();
    emit(AccountsLoaded(cookies));
  }

  Future<void> _onCookiesExtracted(
    CookiesExtracted event,
    Emitter<AccountState> emit,
  ) async {
    final isSuccess = extractionService.isLoginSuccessful(
      event.cookies,
      event.platform,
    );

    if (!isSuccess) {
      emit(LoginFailure(
        platform: event.platform,
        message: "Login gagal. Cookies tidak ditemukan.",
      ));
      add(LoadAccounts());
      return;
    }

    final username = extractionService.extractUsername(
      event.cookies,
      event.platform,
    );

    final cookie = PlatformCookie(
      platform: event.platform,
      cookies: event.cookies,
      username: username,
    );

    await cookieRepo.saveCookies(cookie);

    // Emit success immediately so the UI isn't blocked on the backend sync
    // (which can take several seconds), then push the cookies to the server.
    emit(LoginSuccess(platform: event.platform, synced: false));
    add(LoadAccounts());

    final synced = await cookieRepo.syncToServer(cookie);
    // The webview route pops (and closes this bloc) as soon as the first
    // LoginSuccess lands; the bloc may already be closed here.
    if (synced && !isClosed) {
      emit(LoginSuccess(platform: event.platform, synced: true));
    }
  }

  Future<void> _onLogout(
    LogoutFromPlatform event,
    Emitter<AccountState> emit,
  ) async {
    await cookieRepo.deleteCookies(event.platform);
    final serverDeleted = await cookieRepo.deleteFromServer(event.platform);
    emit(LogoutSuccess(event.platform, serverSynced: serverDeleted));
    add(LoadAccounts());
  }
}
