import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reusable glassmorphic container: blurred backdrop, translucent fill, and
/// a soft gradient border. Presentation-only — carries no business logic.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.blurSigma = 24,
    this.padding = const EdgeInsets.all(16),
    this.tint,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final EdgeInsets padding;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: tint ?? AppColors.glassFill,
            border: Border.all(color: AppColors.glassBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.glassHighlight, Colors.transparent],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
