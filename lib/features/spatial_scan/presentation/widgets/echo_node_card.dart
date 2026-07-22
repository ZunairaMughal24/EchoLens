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
///
/// Geo-anchored nodes additionally show a lock/unlock state driven by live
/// GPS proximity (see EvaluateSignalProximity): the label crossfades from
/// its encrypted placeholder to the real name the moment the node unlocks.
class EchoNodeCard extends StatelessWidget {
  const EchoNodeCard({
    super.key,
    required this.node,
    required this.index,
    this.isPlaying = false,
    this.onPlayTap,
  });

  final EchoNode node;
  final int index;

  /// Whether this node's voice note is the one currently playing.
  final bool isPlaying;

  /// Called when the play/stop affordance is tapped. Only shown for
  /// unlocked nodes with a voice note attached.
  final VoidCallback? onPlayTap;

  @override
  Widget build(BuildContext context) {
    final depthScale = 0.75 + node.depth * 0.35;
    final depthOpacity = (0.55 + node.depth * 0.45).clamp(0.0, 1.0);
    final isPendingUnlock = node.isGeoAnchored && node.isLocked;
    final isUnlocked = node.isGeoAnchored && !node.isLocked;
    final showPlayButton = isUnlocked && node.hasVoiceNote;

    return Opacity(
      opacity: depthOpacity,
      child: Transform.scale(
        scale: depthScale,
        child: GlassSurface(
          borderRadius: 14,
          blurSigma: 18,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          tint: isUnlocked ? AppColors.signalGreen.withValues(alpha: 0.12) : null,
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPendingUnlock)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.lock_outline, size: 11, color: AppColors.amberWarn),
                          )
                        else if (isUnlocked)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.lock_open_rounded, size: 11, color: AppColors.signalGreen),
                          ),
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: 400.ms,
                            child: Text(
                              node.displayLabel,
                              key: ValueKey(node.displayLabel),
                              style: AppTextTheme.title.copyWith(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _subtitle(node),
                      style: AppTextTheme.hudLabel.copyWith(
                        fontSize: 9,
                        color: isUnlocked ? AppColors.signalGreen : AppColors.cyanPulse,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              if (showPlayButton) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onPlayTap,
                  child: Icon(
                    isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                    size: 20,
                    color: AppColors.signalGreen,
                  ),
                ),
              ],
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

  String _subtitle(EchoNode node) {
    if (node.isGeoAnchored) {
      final meters = node.distanceMeters;
      if (node.isLocked) {
        return meters == null ? 'locating…' : '${meters.toStringAsFixed(0)}m to unlock';
      }
      return meters == null ? 'unlocked' : 'unlocked · ${meters.toStringAsFixed(0)}m';
    }
    return '${(node.intensity * 100).round()}% · ${node.category.name}';
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
