import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Plain near-black base (see [AppColors.backgroundGradient]) plus a
/// couple of very faint color blooms — just enough presence to avoid pure
/// flatness without the background competing with the actual content.
/// Kept deliberately subtle: a previous pass pushed opacity much higher
/// and it read as too much, not "atmospheric."
class NebulaBackground extends StatelessWidget {
  const NebulaBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.backgroundGradient)),
        const IgnorePointer(
          child: Stack(
            children: [
              Positioned(top: 20, left: -80, child: _Bloom(color: AppColors.violetGlow, size: 420, opacity: 0.07)),
              Positioned(bottom: 40, right: -90, child: _Bloom(color: AppColors.magentaEdge, size: 380, opacity: 0.05)),
              Positioned(top: 340, right: -50, child: _Bloom(color: AppColors.cyanPulse, size: 320, opacity: 0.04)),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}
