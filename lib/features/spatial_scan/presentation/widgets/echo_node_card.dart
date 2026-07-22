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
/// its encrypted placeholder to the real name the moment the node unlocks,
/// and the card itself plays a one-shot bounce + glow flash at that exact
/// instant (see [_unlockPulseController]) — that transition is the app's
/// actual payoff moment, so it needed to read as one.
class EchoNodeCard extends StatefulWidget {
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
  State<EchoNodeCard> createState() => _EchoNodeCardState();
}

class _EchoNodeCardState extends State<EchoNodeCard> with SingleTickerProviderStateMixin {
  late final AnimationController _unlockPulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  late final Animation<double> _pulseScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.22).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.22, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_unlockPulseController);

  late final Animation<double> _glowAlpha = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0.5), weight: 12),
    TweenSequenceItem(
      tween: Tween(begin: 0.5, end: 0.12).chain(CurveTween(curve: Curves.easeOut)),
      weight: 88,
    ),
  ]).animate(_unlockPulseController);

  @override
  void initState() {
    super.initState();
    // A card that's *already* unlocked the first time it's built (e.g.
    // restored on app resume) should just show the resting glow, not
    // replay the pulse — only a live transition should do that.
    if (!widget.node.isLocked && widget.node.isGeoAnchored) {
      _unlockPulseController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant EchoNodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final justUnlocked = oldWidget.node.isLocked && !widget.node.isLocked;
    if (justUnlocked) {
      _unlockPulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _unlockPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final depthScale = 0.75 + node.depth * 0.35;
    final depthOpacity = (0.55 + node.depth * 0.45).clamp(0.0, 1.0);
    final isPendingUnlock = node.isGeoAnchored && node.isLocked;
    final isUnlocked = node.isGeoAnchored && !node.isLocked;
    final showPlayButton = isUnlocked && node.hasVoiceNote;

    final content = Row(
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
            onTap: widget.onPlayTap,
            child: Icon(
              widget.isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
              size: 20,
              color: AppColors.signalGreen,
            ),
          ),
        ],
      ],
    );

    return Opacity(
      opacity: depthOpacity,
      // Both the scale bounce and the glow-flash tint are driven by the
      // same controller, so one AnimatedBuilder recomputes both per frame.
      // GlassSurface itself has to be rebuilt each frame (its tint is
      // changing), but `content` above doesn't need to — passed as
      // `child` so it's built once and reused across animation frames.
      child: AnimatedBuilder(
        animation: _unlockPulseController,
        builder: (context, child) => Transform.scale(
          scale: depthScale * _pulseScale.value,
          child: GlassSurface(
            borderRadius: 14,
            blurSigma: 18,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tint: isUnlocked ? AppColors.signalGreen.withValues(alpha: _glowAlpha.value) : null,
            child: child!,
          ),
        ),
        child: content,
      ),
    )
        .animate(delay: Duration(milliseconds: 120 * widget.index))
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
