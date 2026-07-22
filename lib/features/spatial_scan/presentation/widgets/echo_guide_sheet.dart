import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../domain/entities/echo_node.dart';
import '../viewmodels/echo_guidance_provider.dart';

/// Modal shown when tapping a locked, guided echo: a live compass-relative
/// arrow plus distance, both recomputed as the user walks and turns. Closes
/// itself the moment the node actually unlocks — no need to keep guiding
/// once you've arrived.
class EchoGuideSheet extends ConsumerWidget {
  const EchoGuideSheet({super.key, required this.node});

  final EchoNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guidance = ref.watch(echoGuidanceProvider(node.id));

    ref.listen(echoGuidanceProvider(node.id), (previous, next) {
      final justUnlocked = !(previous?.isUnlocked ?? false) && next.isUnlocked;
      if (justUnlocked && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: GlassSurface(
          borderRadius: 24,
          blurSigma: 24,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      node.displayLabel,
                      style: AppTextTheme.headline,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: GlassSurface(
                      borderRadius: 12,
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _GuidanceArrow(relativeBearingDegrees: guidance.relativeBearingDegrees),
              const SizedBox(height: 20),
              Text(
                guidance.distanceMeters == null
                    ? 'Locating…'
                    : '${guidance.distanceMeters!.toStringAsFixed(0)}m away',
                style: AppTextTheme.title.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                guidance.relativeBearingDegrees == null
                    ? 'Orienting compass…'
                    : 'Follow the arrow to walk toward it.',
                style: AppTextTheme.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, curve: Curves.easeOut);
  }
}

/// The rotating arrow itself. Deliberately a [StatefulWidget] tracking a
/// continuously-accumulating turn count rather than feeding
/// `relativeBearingDegrees / 360` straight into [AnimatedRotation]: a raw
/// mapping snaps the arrow almost a full turn backwards every time the
/// bearing wraps past 0/360 (350° -> 10° is really a 20° turn, not a 340°
/// one) — accumulating the shortest delta each update keeps it smooth.
class _GuidanceArrow extends StatefulWidget {
  const _GuidanceArrow({required this.relativeBearingDegrees});

  final double? relativeBearingDegrees;

  @override
  State<_GuidanceArrow> createState() => _GuidanceArrowState();
}

class _GuidanceArrowState extends State<_GuidanceArrow> {
  double _turns = 0;
  double? _lastDegrees;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _GuidanceArrow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final degrees = widget.relativeBearingDegrees;
    if (degrees == null) return;
    if (_lastDegrees == null) {
      _turns = degrees / 360;
    } else {
      var delta = degrees - _lastDegrees!;
      delta = ((delta + 180) % 360 + 360) % 360 - 180;
      _turns += delta / 360;
    }
    _lastDegrees = degrees;
  }

  @override
  Widget build(BuildContext context) {
    final hasBearing = widget.relativeBearingDegrees != null;
    return GlassSurface(
      borderRadius: 52,
      blurSigma: 16,
      padding: const EdgeInsets.all(28),
      tint: hasBearing ? AppColors.cyanPulse.withValues(alpha: 0.1) : null,
      child: AnimatedRotation(
        turns: _turns,
        duration: 350.ms,
        curve: Curves.easeOut,
        child: Icon(
          Icons.navigation_rounded,
          size: 48,
          color: hasBearing ? AppColors.cyanPulse : AppColors.textMuted,
        ),
      ),
    );
  }
}
