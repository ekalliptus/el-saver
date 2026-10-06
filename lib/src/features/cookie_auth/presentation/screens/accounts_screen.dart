// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../config/routes_manager.dart';
import '../../../../container_injector.dart';
import '../../../../core/utils/app_colors.dart';
import '../../../../core/utils/app_strings.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/widgets/update_dialog.dart';
import '../../data/models/platform_login_config.dart';
import '../../domain/entities/platform_cookie.dart';
import '../bloc/account_bloc.dart';
import '../bloc/account_event.dart';
import '../bloc/account_state.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final fgColor = theme.textTheme.bodyMedium?.color ?? Colors.white;
    final mutedColor =
        isDark ? AppColors.mutedForegroundDark : AppColors.mutedForegroundLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        title: Text(
          "Akun & Cookies",
          style: TextStyle(color: fgColor, fontSize: 18),
        ),
        iconTheme: IconThemeData(color: fgColor),
      ),
      body: BlocConsumer<AccountBloc, AccountState>(
        listener: (context, state) {
          if (state is LoginSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.synced
                  ? "Login berhasil & cookies tersinkronisasi ke server!"
                  : "Login berhasil! Cookies tersimpan lokal. (Server sync gagal)"),
              backgroundColor: state.synced ? AppColors.green : Colors.orange,
            ));
          }
          if (state is LoginFailure) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.red,
            ));
          }
          if (state is LogoutSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.serverSynced
                  ? "Logout berhasil"
                  : "Logout lokal berhasil, tapi server belum konfirmasi. Coba logout lagi nanti."),
              backgroundColor:
                  state.serverSynced ? AppColors.primaryColor : Colors.orange,
            ));
          }
        },
        builder: (context, state) {
          final cookies =
              state is AccountsLoaded ? state.cookies : <PlatformCookie>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: mutedColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Login ke platform untuk download konten yang membutuhkan autentikasi. Cookies disimpan terenkripsi di perangkat dan disinkronkan ke server Cobalt.",
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...PlatformLoginConfig.supported.map((config) {
                final cookie = cookies
                    .where((c) => c.platform == config.platform)
                    .firstOrNull;
                return _PlatformTile(
                  config: config,
                  cookie: cookie,
                  onLogin: () async {
                    await Navigator.of(context).pushNamed(
                      Routes.webviewLogin,
                      arguments: config.platform,
                    );
                    if (context.mounted) {
                      context.read<AccountBloc>().add(LoadAccounts());
                    }
                  },
                  onLogout: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text('Logout dari ${config.name}?'),
                        content: const Text(
                          'Sesi login akan dihapus dari perangkat ini dan '
                          'server. Video yang sudah terunduh tidak terhapus.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.red),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      context
                          .read<AccountBloc>()
                          .add(LogoutFromPlatform(config.platform));
                    }
                  },
                );
              }),
              const SizedBox(height: 24),
              const _UpdateSection(),
              const SizedBox(height: 16),
              _LegalLinks(mutedColor: mutedColor),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  final Color mutedColor;
  const _LegalLinks({required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushNamed(Routes.legal, arguments: 0),
          child: Text(
            "Kebijakan Privasi",
            style: TextStyle(
                color: mutedColor,
                fontSize: 12,
                decoration: TextDecoration.underline),
          ),
        ),
        Text("•", style: TextStyle(color: mutedColor, fontSize: 12)),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushNamed(Routes.legal, arguments: 1),
          child: Text(
            "Ketentuan Layanan",
            style: TextStyle(
                color: mutedColor,
                fontSize: 12,
                decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }
}

class _UpdateSection extends StatefulWidget {
  const _UpdateSection();

  @override
  State<_UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<_UpdateSection> {
  bool _checking = false;
  String _version = "";
  String _buildNumber = "";

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    final service = sl<UpdateService>();
    final info = await service.checkForUpdate();
    if (!mounted) return;
    setState(() => _checking = false);

    if (info != null) {
      showDialog(
        context: context,
        barrierDismissible: !info.isForced,
        builder: (_) => UpdateDialog(updateInfo: info, updateService: service),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.appUpToDate),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final fgColor = theme.textTheme.bodyMedium?.color ?? Colors.white;
    final mutedColor =
        isDark ? AppColors.mutedForegroundDark : AppColors.mutedForegroundLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: mutedColor, size: 18),
              const SizedBox(width: 8),
              Text(
                AppStrings.appInfo,
                style: TextStyle(
                    color: fgColor, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow("Versi", "v$_version ($_buildNumber)", mutedColor),
          _infoRow("Package", "com.ekalliptus.saver", mutedColor),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _checking ? null : _checkUpdate,
              icon: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_checking ? "..." : AppStrings.checkUpdate),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: mutedColor, fontSize: 12)),
          Text(value, style: TextStyle(color: mutedColor, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PlatformTile extends StatelessWidget {
  final PlatformLoginConfig config;
  final PlatformCookie? cookie;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const _PlatformTile({
    required this.config,
    required this.cookie,
    required this.onLogin,
    required this.onLogout,
  });

  bool get isLoggedIn => cookie != null && cookie!.hasCookies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final fgColor = theme.textTheme.bodyMedium?.color ?? Colors.white;
    final mutedColor =
        isDark ? AppColors.mutedForegroundDark : AppColors.mutedForegroundLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLoggedIn ? AppColors.green.withOpacity(0.3) : borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isLoggedIn
                  ? AppColors.green.withOpacity(0.15)
                  : mutedColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLoggedIn ? Icons.check_circle : Icons.person_outline,
              color: isLoggedIn ? AppColors.green : mutedColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.name,
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLoggedIn
                      ? "Logged in${cookie!.username != null ? ' (${cookie!.username})' : ''}"
                      : "Belum login",
                  style: TextStyle(
                    color: isLoggedIn
                        ? AppColors.green.withOpacity(0.8)
                        : mutedColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isLoggedIn)
            TextButton(
              onPressed: onLogout,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text("Logout", style: TextStyle(fontSize: 12)),
            )
          else
            ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: const Text("Login", style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
