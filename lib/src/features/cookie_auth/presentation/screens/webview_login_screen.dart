// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/utils/app_colors.dart';
import '../../../../core/utils/app_constants.dart';
import '../../data/models/platform_login_config.dart';
import '../../data/services/cookie_extraction_service.dart';
import '../bloc/account_bloc.dart';
import '../bloc/account_event.dart';
import '../bloc/account_state.dart';

class WebViewLoginScreen extends StatefulWidget {
  final SocialPlatform platform;
  const WebViewLoginScreen({super.key, required this.platform});

  @override
  State<WebViewLoginScreen> createState() => _WebViewLoginScreenState();
}

class _WebViewLoginScreenState extends State<WebViewLoginScreen> {
  WebViewController? _controller;
  PlatformLoginConfig? _config;
  final CookieExtractionService _extractionService = CookieExtractionService();
  bool _loading = true;
  bool _extracted = false;
  bool _extracting = false;
  String _statusText = "Menunggu login...";

  bool get _isManual => _config?.manualCompletion ?? false;

  @override
  void initState() {
    super.initState();
    // The error classifier can name platforms (threads, bilibili) that have
    // no login config; bail out gracefully instead of crashing.
    _config = PlatformLoginConfig.getConfig(widget.platform);
    final config = _config;
    if (config == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text("Login ${widget.platform.name} belum didukung di aplikasi."),
          backgroundColor: AppColors.red,
        ));
        Navigator.of(context).pop(false);
      });
      return;
    }
    if (config.manualCompletion) {
      _statusText = "Login di halaman ini, lalu tekan tombol 'Selesai Login'.";
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          // Block app deep-links (bstar://, intent://, ...) that the WebView
          // can't load. Bilibili redirects here after a successful login, so
          // treat the attempt as a login-success signal for manual platforms.
          if (uri != null && uri.scheme != 'http' && uri.scheme != 'https') {
            if (_isManual && !_extracted) {
              if (mounted) {
                setState(() =>
                    _statusText = "Login terdeteksi, mengambil cookies...");
              }
              _tryExtractCookies("deepLink:${uri.scheme}");
            }
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageStarted: (url) {
          if (mounted) setState(() => _loading = true);
          if (!_isManual) _onUrlChanged(url);
        },
        onPageFinished: (url) {
          if (mounted) setState(() => _loading = false);
          if (!_isManual) _tryExtractCookies("pageFinished");
        },
        onUrlChange: (change) {
          if (change.url != null && !_isManual) {
            _onUrlChanged(change.url!);
          }
        },
        onWebResourceError: (error) {
          // Page load failed (timeout etc) - still try to extract cookies
          // because login might have succeeded before the redirect timed out.
          // Bilibili's post-login redirect to bstar:// surfaces here as
          // ERR_UNKNOWN_URL_SCHEME on some WebView builds.
          if (!_isManual) {
            _tryExtractCookies("webError: ${error.description}");
          } else if (!_extracted) {
            _tryExtractCookies("webError: ${error.description}");
          }
        },
      ))
      ..setUserAgent(config.userAgent ??
          "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
      ..loadRequest(Uri.parse(config.loginUrl));
  }

  void _onUrlChanged(String url) {
    final config = _config;
    if (_extracted || config == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final isSuccessPage = config.successDomains.any(
      (domain) => uri.host == domain || uri.host.endsWith(".$domain"),
    );

    if (isSuccessPage) {
      if (mounted) {
        setState(() => _statusText = "Login terdeteksi, mengambil cookies...");
      }
      // Delay to let cookies propagate, then extract
      Future.delayed(const Duration(seconds: 2), () {
        _tryExtractCookies("successUrl");
      });
    }
  }

  Future<void> _tryExtractCookies(String trigger) async {
    final controller = _controller;
    if (_config == null || controller == null || _extracted || _extracting) {
      return;
    }
    _extracting = true;

    try {
      final cookies = await _extractionService.extractCookies(
        controller,
        widget.platform,
      );

      if (cookies.isEmpty) {
        _handleExtractionFailed(trigger, "Cookies belum tersedia.");
        return;
      }

      if (_extractionService.isLoginSuccessful(cookies, widget.platform)) {
        _extracted = true;
        if (mounted) {
          context.read<AccountBloc>().add(
                CookiesExtracted(platform: widget.platform, cookies: cookies),
              );
        }
      } else {
        _handleExtractionFailed(
          trigger,
          "Login belum terdeteksi. Pastikan sudah sign-in, lalu tekan 'Selesai Login'.",
        );
      }
    } catch (_) {
      _handleExtractionFailed(trigger, "Gagal mengambil cookies.");
    } finally {
      _extracting = false;
    }
  }

  void _handleExtractionFailed(String trigger, String message) {
    // Auto-extraction (pageFinished/url changes) stays silent: it retries on
    // the next event. Only the manual "Selesai Login" press surfaces a message
    // so the user knows to finish signing in first.
    if (trigger == 'manual' && mounted) {
      setState(() => _statusText = message);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final controller = _controller;
    if (config == null || controller == null) {
      // Unsupported platform: brief placeholder while the post-frame callback
      // pops this route.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final fgColor = theme.textTheme.bodyMedium?.color ?? Colors.white;
    final mutedColor =
        isDark ? AppColors.mutedForegroundDark : AppColors.mutedForegroundLight;

    return BlocListener<AccountBloc, AccountState>(
        listener: (context, state) {
          if (state is LoginSuccess && state.platform == widget.platform) {
            Navigator.of(context).pop(true);
          } else if (state is LoginFailure &&
              state.platform == widget.platform) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message), backgroundColor: AppColors.red),
            );
            setState(() => _extracted = false);
          }
        },
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: cardColor,
            leading: IconButton(
              icon: Icon(Icons.close, color: fgColor),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            title: Text(
              "Login ${config.name}",
              style: TextStyle(color: fgColor, fontSize: 16),
            ),
            actions: [
              if (_isManual)
                TextButton(
                  onPressed: () {
                    setState(() => _statusText = 'Mengambil cookies...');
                    _tryExtractCookies('manual');
                  },
                  child: const Text('Selesai Login'),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: WebViewWidget(controller: controller)),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: cardColor,
                child: Text(
                  _statusText,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ));
  }
}
