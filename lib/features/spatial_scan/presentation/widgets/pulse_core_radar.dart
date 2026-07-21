import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/echo_node.dart';

/// The screen's visual centerpiece: a continuously rotating radar/sonar HUD
/// with a glowing core, concentric depth rings, and floating echo nodes.
///
/// Deliberately built on a raw [AnimationController] + [CustomPainter]
/// rather than `flutter_animate`: this animation runs forever at 60fps and
/// only needs to repaint a canvas, so driving it via the painter's `repaint`
/// Listenable avoids rebuilding the widget subtree every frame.
/// `flutter_animate` is used instead for the one-shot entrance choreography
/// of the surrounding glass cards (see [EchoNodeCard]) — the right tool for
/// "animate in once" vs. "animate forever," respectively.
class PulseCoreRadar extends StatefulWidget {
  const PulseCoreRadar({
    super.key,
    required this.nodes,
    this.isScanning = true,
    this.size = 320,
  });

  final List<EchoNode> nodes;
  final bool isScanning;
  final double size;

  @override
  State<PulseCoreRadar> createState() => _PulseCoreRadarState();
}

class _PulseCoreRadarState extends State<PulseCoreRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void didUpdateWidget(covariant PulseCoreRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isScanning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _PulseCorePainter(
            animation: _controller,
            nodes: widget.nodes,
          ),
        ),
      ),
    );
  }
}

class _PulseCorePainter extends CustomPainter {
  _PulseCorePainter({required this.animation, required this.nodes})
      : super(repaint: animation);

  final Animation<double> animation;
  final List<EchoNode> nodes;

  static const _ringFractions = [0.35, 0.55, 0.78, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    final t = animation.value;

    _paintCoreGlow(canvas, center, maxRadius);
    _paintRings(canvas, center, maxRadius);
    _paintTicks(canvas, center, maxRadius);
    _paintSweep(canvas, center, maxRadius, t);
    _paintNodes(canvas, center, maxRadius, t);
  }

  void _paintCoreGlow(Canvas canvas, Offset center, double maxRadius) {
    final glowRadius = maxRadius * 0.28;
    final paint = Paint()
      ..shader = AppColors.coreGlowGradient.createShader(
        Rect.fromCircle(center: center, radius: glowRadius),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(center, glowRadius, paint);
  }

  void _paintRings(Canvas canvas, Offset center, double maxRadius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < _ringFractions.length; i++) {
      final opacity = 0.35 - (i * 0.07);
      paint.color = AppColors.cyanPulse.withValues(alpha: opacity.clamp(0.05, 1));
      canvas.drawCircle(center, maxRadius * _ringFractions[i], paint);
    }
  }

  void _paintTicks(Canvas canvas, Offset center, double maxRadius) {
    final paint = Paint()
      ..color = AppColors.cyanPulse.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    const tickCount = 36;
    for (var i = 0; i < tickCount; i++) {
      final angle = (2 * pi / tickCount) * i;
      final isMajor = i % 9 == 0;
      final outer = maxRadius * 1.0;
      final inner = maxRadius * (isMajor ? 0.93 : 0.97);
      canvas.drawLine(
        center + Offset(cos(angle), sin(angle)) * inner,
        center + Offset(cos(angle), sin(angle)) * outer,
        paint,
      );
    }
  }

  void _paintSweep(Canvas canvas, Offset center, double maxRadius, double t) {
    final sweepAngle = t * 2 * pi;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle);
    final paint = Paint()
      ..shader = SweepGradient(
        colors: [
          AppColors.cyanPulse.withValues(alpha: 0.0),
          AppColors.cyanPulse.withValues(alpha: 0.45),
          AppColors.cyanPulse.withValues(alpha: 0.0),
          Colors.transparent,
        ],
        stops: const [0.0, 0.04, 0.16, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: maxRadius));
    canvas.drawCircle(Offset.zero, maxRadius, paint);
    canvas.restore();
  }

  void _paintNodes(Canvas canvas, Offset center, double maxRadius, double t) {
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final pos = center +
          Offset(cos(node.angleRadians), sin(node.angleRadians)) *
              (node.distance * maxRadius);

      final pulsePhase = (t * 2 * pi) + (i * 0.9);
      final pulse = 0.85 + 0.15 * sin(pulsePhase);
      final baseRadius = 3.0 + (node.depth * 4.0) + (node.intensity * 2.0);
      final radius = baseRadius * pulse;
      final color = _colorForCategory(node.category);
      final alpha = (0.5 + node.depth * 0.5).clamp(0.0, 1.0);

      final glowPaint = Paint()
        ..color = color.withValues(alpha: alpha * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(pos, radius * 2.2, glowPaint);

      final dotPaint = Paint()..color = color.withValues(alpha: alpha);
      canvas.drawCircle(pos, radius, dotPaint);
    }
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

  @override
  bool shouldRepaint(covariant _PulseCorePainter oldDelegate) {
    return oldDelegate.nodes != nodes;
  }
}
