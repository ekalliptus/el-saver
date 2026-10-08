import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

/// Three bouncing dots in the brand color — replaces plain
/// CircularProgressIndicator spinners. Scale [size] for buttons (small) or
/// full-page waits (large).
class FancyLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const FancyLoader({super.key, this.size = 28, this.color});

  @override
  State<FancyLoader> createState() => _FancyLoaderState();
}

class _FancyLoaderState extends State<FancyLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = widget.size / 3.4;
    final color = widget.color ?? AppColors.primaryColor;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot by 1/3 of the cycle; bounce = eased sine.
            final phase = (_c.value - i / 3) % 1;
            final lift = _bounce(phase);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: dot * 0.28),
              child: Transform.translate(
                offset: Offset(0, -lift * dot * 0.9),
                child: Opacity(
                  opacity: 0.45 + 0.55 * lift,
                  child: Container(
                    width: dot,
                    height: dot,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _bounce(double phase) {
    // 0..1..0 arc, clamped so only a third of the cycle is active per dot.
    if (phase < 0 || phase > 0.5) return 0;
    final t = phase / 0.5;
    return 1.0 - (2.0 * t - 1.0).abs();
  }
}
