import '../../../../core/utils/app_constants.dart';
import '../../domain/entities/platform_cookie.dart';

abstract class AccountState {}

class AccountsInitial extends AccountState {}

class AccountsLoading extends AccountState {}

class AccountsLoaded extends AccountState {
  final List<PlatformCookie> cookies;
  AccountsLoaded(this.cookies);
}

class LoginSuccess extends AccountState {
  final SocialPlatform platform;
  final bool synced;
  LoginSuccess({required this.platform, this.synced = false});
}

class LoginFailure extends AccountState {
  final SocialPlatform platform;
  final String message;
  LoginFailure({required this.platform, required this.message});
}

class LogoutSuccess extends AccountState {
  final SocialPlatform platform;
  final bool serverSynced;
  LogoutSuccess(this.platform, {this.serverSynced = false});
}
