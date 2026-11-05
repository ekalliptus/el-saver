import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

/// Fluid wave loader: three dots riding a sine wave with scale + opacity
/// phase shifts — replaces plain CircularProgressIndicator spinners.
/// [size] scales the whole widget (buttons ~12, full-page ~36).
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
                child: Transform.scale(
                  // Subtle scale pulse in sync with the lift: dots feel
                  // fluid instead of mechanically jumping.
                  scale: 0.8 + 0.25 * lift,
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

/// Spinning orbit loader: a dot orbiting a faded ring — reads as
/// "working" for longer waits where three dots feel too small.
class OrbitLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const OrbitLoader({super.key, this.size = 44, this.color});

  @override
  State<OrbitLoader> createState() => _OrbitLoaderState();
}

class _OrbitLoaderState extends State<OrbitLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primaryColor;
    final r = widget.size / 2;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final angle = _c.value * 2 * math.pi;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.15),
                    width: 2,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(r * math.cos(angle) - r, r * math.sin(angle) - r)
                    .translate(widget.size / 2 - r * 0 + r, widget.size / 2),
                child: Container(
                  width: widget.size * 0.16,
                  height: widget.size * 0.16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
