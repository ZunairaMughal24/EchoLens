import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Central typography scale for EchoLens. UI code must style text through
/// this class (e.g. `AppTextTheme.hudLabel`) — never inline a raw TextStyle.
///
/// Fonts are fetched at runtime via google_fonts (falls back to a system
/// font offline, see `GoogleFonts.config.allowRuntimeFetching` in main.dart).
/// For a release build, prefer bundling the .ttf files under `assets/fonts/`
/// and declaring them in pubspec.yaml's `fonts:` section instead, so
/// typography doesn't depend on network access at all.
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
  static TextStyle get hudLabel => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
    color: AppColors.cyanPulse,
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
