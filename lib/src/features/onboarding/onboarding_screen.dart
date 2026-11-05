import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/routes_manager.dart';
import 'package:el_saver/src/core/screens/permission_setup_screen.dart';
import 'package:el_saver/src/core/services/permission_service.dart';
import 'package:el_saver/src/core/utils/app_colors.dart';

/// First-launch 3-slide onboarding. Shown once (flag in SharedPreferences)
/// between the splash and the downloader.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static final List<({IconData icon, Color color, String title, String body})> _slides = [
    (
      icon: Icons.link_rounded,
      color: Color(0xFF38BDF8),
      title: 'Tempel Tautannya',
      body: 'Salin tautan video dari YouTube, TikTok, Instagram '
          '& 40+ platform lainnya',
    ),
    (
      icon: Icons.download_done_rounded,
      color: AppColors.primaryColor,
      title: 'Pilih Kualitas',
      body: 'Pilih resolusi atau ekstrak audionya sebagai MP3 — '
          'unduhan berjalan di latar belakang dengan progres real-time.',
    ),
    (
      icon: Icons.photo_library_rounded,
      color: AppColors.success,
      title: 'Simpan Status WA',
      body: 'Lihat & simpan status WhatsApp temanmu ke galeri '
          'dengan sekali ketuk.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    // First-run users still need the guided permission flow before the
    // downloader is usable.
    final granted =
        await PermissionService().areAllPermissionsGranted();
    if (!mounted) return;
    if (granted) {
      Navigator.of(context).pushReplacementNamed(Routes.downloader);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PermissionSetupScreen()),
      );
    }
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    'Lewati',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Illustration card: soft glow + icon on glass.
                        Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  slide.color.withValues(alpha: 0.25),
                                  slide.color.withValues(alpha: 0.0),
                                ]),
                              ),
                            ),
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: slide.color
                                        .withValues(alpha: 0.2),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(slide.icon,
                                  size: 56, color: slide.color),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Dots
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? _slides[_page].color
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _slides[_page].color,
                        _slides[_page].color.withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: TextButton(
                    onPressed: _next,
                    child: Text(
                      isLast ? 'Mulai Sekarang' : 'Lanjut',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B1220),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
