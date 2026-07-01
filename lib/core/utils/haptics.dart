/// lib/core/utils/haptics.dart
///
/// Thin wrapper around Flutter's built-in HapticFeedback — no-op on web.
/// package. No-op on web.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class Haptics {
  Haptics._();

  /// Light tap — button presses, selections
  static Future<void> light() async {
    if (kIsWeb) return;
    try { await HapticFeedback.lightImpact(); } catch (_) {}
  }

  /// Medium — confirms, toggles
  static Future<void> medium() async {
    if (kIsWeb) return;
    try { await HapticFeedback.mediumImpact(); } catch (_) {}
  }

  /// Heavy — destructive actions
  static Future<void> heavy() async {
    if (kIsWeb) return;
    try { await HapticFeedback.heavyImpact(); } catch (_) {}
  }

  /// Success pattern — order accepted, payment confirmed
  static Future<void> success() async {
    if (kIsWeb) return;
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Error pattern — failed action, rejection
  static Future<void> error() async {
    if (kIsWeb) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Warning
  static Future<void> warning() async {
    if (kIsWeb) return;
    try { await HapticFeedback.mediumImpact(); } catch (_) {}
  }

  /// Pull to refresh
  static Future<void> refresh() => medium();

  /// Swipe action revealed
  static Future<void> swipe() => light();

  /// Selection changed
  static Future<void> selection() async {
    if (kIsWeb) return;
    try { await HapticFeedback.selectionClick(); } catch (_) {}
  }
}
