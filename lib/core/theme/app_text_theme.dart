import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Central typography scale for EchoLens. UI code must style text through
/// this class (e.g. `AppTextTheme.hudLabel`) — never inline a raw TextStyle.
///
/// Fonts are fetched at runtime via google_fonts and cached on-device after
/// the first successful download. If a fetch fails (offline, DNS failure),
/// google_fonts logs a warning and silently falls back to the platform's
/// default font — this is the package's default behavior; do NOT set
/// `GoogleFonts.config.allowRuntimeFetching = false`, since that instead
/// makes it throw for any font not already bundled as a local asset. For a
/// release build that must never depend on network access, bundle the .ttf
/// files under `assets/fonts/` and declare them in pubspec.yaml's `fonts:`
/// section instead.
abstract final class AppTextTheme {
  static TextStyle get display => GoogleFonts.nunito(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static TextStyle get headline => GoogleFonts.sora(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get title => GoogleFonts.sora(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get body => GoogleFonts.sora(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static TextStyle get caption => GoogleFonts.sora(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  /// Monospace readout style for scan data / HUD telemetry.
  ///
  /// Neutral by default — this style is reused for nearly every label in
  /// the app (header subtitles, status panel labels, card subtitles), and
  /// defaulting it to an accent color meant every one of those was cyan
  /// with no variation. Accent color is now opt-in via `.copyWith(color:)`
  /// at the handful of call sites that actually mean to draw the eye.
  static TextStyle get hudLabel => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
    color: AppColors.textMuted,
  );

  static TextStyle get hudValue => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextTheme get materialTextTheme => TextTheme(
    headlineMedium: display,
    headlineSmall: headline,
    titleMedium: title,
    bodyMedium: body,
    bodySmall: caption,
  );
}
