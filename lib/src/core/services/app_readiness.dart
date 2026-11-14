import 'dart:async';

/// Global startup gate. Becomes ready once the user has reached the main
/// shell — after splash → onboarding → permission setup has settled.
///
/// Everything that surfaces UI on its own schedule (FCM / local notification
/// permission prompts, app-open ads, permission nudge, premium promo, update
/// dialog) waits for this gate so it can never race the first-run setup flow
/// or pop over the splash / permission screens.
class AppReadiness {
  AppReadiness._();

  static bool _ready = false;
  static final Completer<void> _completer = Completer<void>();

  static bool get isReady => _ready;

  static Future<void> waitUntilReady() => _completer.future;

  static void markReady() {
    if (_ready) return;
    _ready = true;
    _completer.complete();
  }
}
