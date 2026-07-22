import 'package:flutter/material.dart';

/// EchoLens design system palette — deep-space base with dual signal accents.
/// Never reference raw Color(...) values outside this file; extend here instead.
abstract final class AppColors {
  // Base surfaces
  static const voidBlack = Color(0xFF05070D);
  static const deepSpace = Color(0xFF0B0F1C);
  static const nebulaSurface = Color(0xFF121729);

  // Signal accents
  static const cyanPulse = Color(0xFF00F5FF);
  static const violetGlow = Color(0xFF9B5CFF);
  static const magentaEdge = Color(0xFFFF3DAD);
  static const signalGreen = Color(0xFF3DFFB0);
  static const amberWarn = Color(0xFFFFB23D);

  // Glass surfaces
  static const glassFill = Color(0x14FFFFFF); // white @ 8%
  static const glassBorder = Color(0x33FFFFFF); // white @ 20%
  static const glassHighlight = Color(0x1FFFFFFF); // white @ 12%

  // Text
  static const textPrimary = Color(0xFFF4F6FF);
  static const textSecondary = Color(0xFFA6ADC8);
  // Was 0xFF6B7290 — measured ~4.4:1 against voidBlack, just under the
  // 4.5:1 WCAG AA floor for small text (this is used at 9-12px throughout
  // the HUD). Brightened to a comfortable ~6.6:1 while keeping it visibly
  // dimmer than textSecondary for hierarchy.
  static const textMuted = Color(0xFF8791AD);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [deepSpace, voidBlack],
  );

  static const coreGlowGradient = RadialGradient(
    colors: [cyanPulse, violetGlow, Colors.transparent],
    stops: [0.0, 0.4, 1.0],
  );
}
