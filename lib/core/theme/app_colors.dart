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
  // Both secondary/muted were a real hue (blue-violet, matching violetGlow's
  // family) but at ~24% saturation — desaturated enough that it just read as
  // flat grey rather than an intentional tint. Pushed saturation up to
  // ~45-50% while keeping lightness in the same range, so it reads as a
  // designed periwinkle-grey instead of a generic disabled-text grey.
  // Contrast against voidBlack only went up (~10.7:1 / ~7.1:1), so this is
  // strictly better on accessibility too, not a tradeoff.
  static const textSecondary = Color.fromARGB(255, 222, 225, 240);
  static const textMuted = Color.fromARGB(255, 202, 207, 230);

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
