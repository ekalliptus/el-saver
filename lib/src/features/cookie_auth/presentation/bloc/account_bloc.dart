import 'dart:async';

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

    // Emit success immediately, then push the cookies to the server without
    // awaiting it: bloc events are sequential, so an in-handler await would
    // keep the accounts list stale (and pop an orange false-alarm snackbar)
    // for as long as the backend round-trip takes.
    emit(LoginSuccess(platform: event.platform, synced: false));
    add(LoadAccounts());

    unawaited(cookieRepo.syncToServer(cookie).then((synced) {
      if (synced && !isClosed) {
        emit(LoginSuccess(platform: event.platform, synced: true));
      }
    }));
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
