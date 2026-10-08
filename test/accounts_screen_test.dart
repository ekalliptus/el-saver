import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_saver/src/core/utils/app_constants.dart';
import 'package:el_saver/src/features/cookie_auth/data/services/cookie_extraction_service.dart';
import 'package:el_saver/src/features/cookie_auth/domain/entities/platform_cookie.dart';
import 'package:el_saver/src/features/cookie_auth/domain/repositories/cookie_repo.dart';
import 'package:el_saver/src/features/cookie_auth/presentation/bloc/account_bloc.dart';
import 'package:el_saver/src/features/cookie_auth/presentation/bloc/account_event.dart';
import 'package:el_saver/src/features/cookie_auth/presentation/screens/accounts_screen.dart';

class FakeCookieRepo implements CookieRepo {
  @override
  Future<List<PlatformCookie>> getAllCookies() async => [
        PlatformCookie(
          platform: SocialPlatform.instagram,
          cookies: {'sessionid': 'x', 'ds_user_id': '1'},
          username: 'tester',
        ),
      ];

  @override
  Future<PlatformCookie?> getCookies(SocialPlatform platform) async => null;

  @override
  Future<void> saveCookies(PlatformCookie cookie) async {}

  @override
  Future<void> deleteCookies(SocialPlatform platform) async {}

  @override
  Future<bool> syncToServer(PlatformCookie cookie) async => true;

  @override
  Future<bool> deleteFromServer(SocialPlatform platform) async => true;
}

Widget _wrap(Widget child) => MaterialApp(
      home: BlocProvider<AccountBloc>(
        create: (_) => AccountBloc(
          cookieRepo: FakeCookieRepo(),
          extractionService: CookieExtractionService(),
        ),
        child: child,
      ),
    );

void main() {
  testWidgets('accounts screen renders info card and platform tiles',
      (tester) async {
    await tester.pumpWidget(_wrap(const AccountsScreen()));
    await tester.pump();

    expect(find.text('Instagram & Threads'), findsOneWidget);
  });

  testWidgets('accounts screen shows logged-in state after load',
      (tester) async {
    await tester.pumpWidget(_wrap(const AccountsScreen()));
    await tester.pump();
    final context = tester.element(find.byType(AccountsScreen));
    context.read<AccountBloc>().add(LoadAccounts());
    await tester.pumpAndSettle();

    expect(find.textContaining('Logged in'), findsWidgets);
  });
}
