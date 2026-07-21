import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../domain/entities/echo_node.dart';

/// A floating glass readout for a single [EchoNode]. Scale/opacity are
/// driven by [node.depth] so nearer nodes read as larger and sharper —
/// the pseudo-3D depth cue that sells the "spatial" feel without any real
/// 3D geometry.
class EchoNodeCard extends StatelessWidget {
  const EchoNodeCard({super.key, required this.node, required this.index});

  final EchoNode node;
  final int index;

  @override
  Widget build(BuildContext context) {
    final depthScale = 0.75 + node.depth * 0.35;
    final depthOpacity = (0.55 + node.depth * 0.45).clamp(0.0, 1.0);

    return Opacity(
      opacity: depthOpacity,
      child: Transform.scale(
        scale: depthScale,
        child: GlassSurface(
          borderRadius: 14,
          blurSigma: 18,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _colorForCategory(node.category),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      node.label,
                      style: AppTextTheme.title.copyWith(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      '${(node.intensity * 100).round()}% · ${node.category.name}',
                      style: AppTextTheme.hudLabel.copyWith(fontSize: 9),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 120 * index))
        .fadeIn(duration: 420.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack)
        .then()
        .shimmer(duration: 900.ms, color: AppColors.cyanPulse.withValues(alpha: 0.25));
  }

  Color _colorForCategory(EchoCategory category) {
    switch (category) {
      case EchoCategory.signal:
        return AppColors.cyanPulse;
      case EchoCategory.presence:
        return AppColors.violetGlow;
      case EchoCategory.environment:
        return AppColors.signalGreen;
      case EchoCategory.anomaly:
        return AppColors.magentaEdge;
    }
  }
}
