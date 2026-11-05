import 'package:flutter/material.dart';

/// Shared page-transition builders so every navigation feels like one app.
class PageTransitions {
  PageTransitions._();

  /// Slide-up + fade: used for pushed detail screens (downloads, settings).
  static Route<T> slideUp<T>(Widget page, RouteSettings? settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
            parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  /// Scale+fade: used for dialogs-as-screens (premium purchase).
  static Route<T> scale<T>(Widget page, RouteSettings? settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
            parent: animation, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: CurvedAnimation(
                parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }
}
