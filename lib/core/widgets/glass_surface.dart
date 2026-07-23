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
    this.tintGradient,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final EdgeInsets padding;
  final Color? tint;

  /// Multi-color alternative to [tint], for surfaces that want to read as
  /// genuinely colorful rather than a single flat accent wash. Takes over
  /// the fill entirely when set — [tint] is ignored.
  final Gradient? tintGradient;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    // The shadow has to live outside the ClipRRect/BackdropFilter — a
    // BoxShadow drawn *inside* a clipped blur container gets clipped away
    // with everything else, so it'd never actually render. Without this,
    // every glass surface in the app was flat against the background
    // instead of visibly floating above it, no matter how good the blur
    // and border looked up close.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: tintGradient == null ? (tint ?? AppColors.glassFill) : null,
              border: Border.all(color: AppColors.glassBorder, width: 1),
              gradient: tintGradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.glassHighlight, Colors.transparent],
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
