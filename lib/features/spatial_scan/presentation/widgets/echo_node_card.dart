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
/// and the card plays a one-shot bounce + glow flash at that exact instant
/// ([_unlockPulseController]) — that transition is the app's actual payoff
/// moment. After that, as long as [hasBeenPlayed] is false, it keeps a
/// gentle continuous "breathing" glow going ([_breathingController]) — an
/// unplayed note sitting right next to the user shouldn't just flash once
/// and go quiet; it should keep asking to be heard until it actually is.
/// [hasBeenPlayed] is owned by the ViewModel (not tracked locally here) so
/// this card and the radar's repeating bloom effect ([_BloomPulse] in
/// spatial_scan_screen.dart) read the exact same "has this been heard"
/// state and stop together.
class EchoNodeCard extends StatefulWidget {
  const EchoNodeCard({
    super.key,
    required this.node,
    required this.index,
    this.isPlaying = false,
    this.hasBeenPlayed = false,
    this.onPlayTap,
  });

  final EchoNode node;
  final int index;

  /// Whether this node's voice note is the one currently playing.
  final bool isPlaying;

  /// Whether this node's voice note has been played at least once since
  /// its most recent unlock — see [SpatialScanUiState.playedNodeIds].
  final bool hasBeenPlayed;

  /// Called when the play/stop affordance is tapped. Only shown for
  /// unlocked nodes with a voice note attached.
  final VoidCallback? onPlayTap;

  @override
  State<EchoNodeCard> createState() => _EchoNodeCardState();
}

class _EchoNodeCardState extends State<EchoNodeCard> with TickerProviderStateMixin {
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

  // Continuous "unheard note" indicator. Composes with the one-shot pulse
  // above rather than replacing it: scale multiplies (both at rest = 1.0,
  // so it's a no-op when not breathing), glow adds (both at rest = base
  // alpha, so it's additive on top of whatever the pulse already settled
  // to).
  late final AnimationController _breathingController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  late final Animation<double> _breathingScale = Tween<double>(begin: 1.0, end: 1.045)
      .chain(CurveTween(curve: Curves.easeInOut))
      .animate(_breathingController);

  late final Animation<double> _breathingGlowDelta = Tween<double>(begin: 0.0, end: 0.24)
      .chain(CurveTween(curve: Curves.easeInOut))
      .animate(_breathingController);

  bool get _shouldBreathe =>
      widget.node.isGeoAnchored && !widget.node.isLocked && widget.node.hasVoiceNote && !widget.hasBeenPlayed;

  void _syncBreathing() {
    if (_shouldBreathe && !_breathingController.isAnimating) {
      _breathingController.repeat(reverse: true);
    } else if (!_shouldBreathe && _breathingController.isAnimating) {
      _breathingController.animateTo(0, duration: 300.ms, curve: Curves.easeOut);
    }
  }

  @override
  void initState() {
    super.initState();
    // A card that's *already* unlocked the first time it's built (e.g.
    // restored on app resume) should just show the resting glow, not
    // replay the pop — only a live transition should do that.
    if (!widget.node.isLocked && widget.node.isGeoAnchored) {
      _unlockPulseController.value = 1.0;
    }
    _syncBreathing();
  }

  @override
  void didUpdateWidget(covariant EchoNodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final justUnlocked = oldWidget.node.isLocked && !widget.node.isLocked;
    if (justUnlocked) {
      _unlockPulseController.forward(from: 0);
    }
    _syncBreathing();
  }

  @override
  void dispose() {
    _unlockPulseController.dispose();
    _breathingController.dispose();
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
                        style: AppTextTheme.cardLabel.copyWith(fontSize: 12),
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
                  color: _subtitleColor(node),
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
            // Was a bare Icon with no container — every other tappable
            // icon in the app (header buttons, plant screen controls) is
            // a rounded glass box; this one wasn't. Small blurSigma since
            // it's a compact ~28px button, not a full-size button.
            child: GlassSurface(
              borderRadius: 14,
              blurSigma: 10,
              padding: const EdgeInsets.all(4),
              child: Icon(
                widget.isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                size: 20,
                color: AppColors.signalGreen,
              ),
            ),
          ),
        ],
      ],
    );

    return Opacity(
      opacity: depthOpacity,
      // Both controllers drive the same two visual properties (scale,
      // glow), so one AnimatedBuilder listening to both recomputes them
      // together each frame. GlassSurface has to rebuild every frame (its
      // tint is changing), but `content` doesn't — passed as `child` so
      // it's built once and reused across every animation frame from
      // either controller.
      child: AnimatedBuilder(
        animation: Listenable.merge([_unlockPulseController, _breathingController]),
        builder: (context, child) {
          final scale = depthScale * _pulseScale.value * _breathingScale.value;
          final glowAlpha = (_glowAlpha.value + _breathingGlowDelta.value).clamp(0.0, 0.7);
          return Transform.scale(
            scale: scale,
            child: GlassSurface(
              borderRadius: 14,
              blurSigma: 18,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tint: isUnlocked ? AppColors.signalGreen.withValues(alpha: glowAlpha) : null,
              child: child!,
            ),
          );
        },
        child: content,
      ),
    )
        .animate(delay: Duration(milliseconds: 120 * widget.index))
        .fadeIn(duration: 420.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack)
        .then()
        .shimmer(duration: 900.ms, color: AppColors.cyanPulse.withValues(alpha: 0.25));
  }

  /// Locked/unlocked geo-anchored nodes match their lock icon's color
  /// (amber pending, green unlocked); ambient nodes reflect their own
  /// category color instead of a single blanket accent — the "everything
  /// on this card is cyan" issue, seen across the whole app not just here.
  Color _subtitleColor(EchoNode node) {
    if (node.isGeoAnchored) {
      return node.isLocked ? AppColors.amberWarn : AppColors.signalGreen;
    }
    return _colorForCategory(node.category).withValues(alpha: 0.85);
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
