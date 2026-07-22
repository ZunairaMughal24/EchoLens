import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../domain/entities/echo_node.dart';
import '../viewmodels/spatial_scan_viewmodel.dart';
import '../widgets/echo_node_card.dart';
import '../widgets/pulse_core_radar.dart';
import 'plant_signal_screen.dart';

/// Main EchoLens screen — the Pulse Field. Pure presentation: all state
/// comes from [spatialScanViewModelProvider]; this widget only lays things
/// out and forwards user intents to the ViewModel.
class SpatialScanScreen extends ConsumerWidget {
  const SpatialScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spatialScanViewModelProvider);
    final viewModel = ref.read(spatialScanViewModelProvider.notifier);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fieldSize = min(constraints.maxWidth, constraints.maxHeight * 0.62);
              return Column(
                children: [
                  _Header(
                    isScanning: state.isScanning,
                    onToggle: viewModel.toggleScanning,
                    onPlant: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PlantSignalScreen()),
                    ),
                  ),
                  if (state.locationErrorMessage != null)
                    _LocationErrorBanner(message: state.locationErrorMessage!),
                  Expanded(
                    child: Center(
                      child: _PulseField(
                        nodes: state.nodes,
                        isScanning: state.isScanning,
                        fieldSize: fieldSize,
                        playingNodeId: state.playingNodeId,
                        onPlayTap: viewModel.playSignal,
                      ),
                    ),
                  ),
                  _StatusPanel(nodeCount: state.nodes.length, isScanning: state.isScanning),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isScanning, required this.onToggle, required this.onPlant});

  final bool isScanning;
  final VoidCallback onToggle;
  final VoidCallback onPlant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Expanded + ellipsis rather than a bare Column: on narrow
          // devices "EchoLens" + the two header buttons can outgrow the
          // available width — this guarantees the title truncates instead
          // of throwing a RenderFlex overflow.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EchoLens', style: AppTextTheme.display, overflow: TextOverflow.ellipsis),
                Text(
                  'SCANNING PHYSICAL SPACE',
                  style: AppTextTheme.hudLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              GestureDetector(
                onTap: onPlant,
                child: GlassSurface(
                  borderRadius: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: const Icon(Icons.add_rounded, color: AppColors.cyanPulse),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onToggle,
                child: GlassSurface(
                  borderRadius: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Icon(
                    isScanning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppColors.cyanPulse,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.15, curve: Curves.easeOut);
  }
}

class _LocationErrorBanner extends StatelessWidget {
  const _LocationErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GlassSurface(
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        tint: AppColors.amberWarn.withValues(alpha: 0.12),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded, size: 16, color: AppColors.amberWarn),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextTheme.caption.copyWith(color: AppColors.amberWarn),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _PulseField extends StatelessWidget {
  const _PulseField({
    required this.nodes,
    required this.isScanning,
    required this.fieldSize,
    required this.playingNodeId,
    required this.onPlayTap,
  });

  final List<EchoNode> nodes;
  final bool isScanning;
  final double fieldSize;
  final String? playingNodeId;
  final ValueChanged<EchoNode> onPlayTap;

  @override
  Widget build(BuildContext context) {
    final radarSize = fieldSize * 0.62;
    return SizedBox.square(
      dimension: fieldSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PulseCoreRadar(nodes: nodes, isScanning: isScanning, size: radarSize),
          for (var i = 0; i < nodes.length; i++)
            _positionedNode(nodes[i], i, fieldSize, radarSize),
        ],
      ),
    );
  }

  Widget _positionedNode(EchoNode node, int index, double fieldSize, double radarSize) {
    final maxRadius = fieldSize / 2;
    // Nodes read past the radar's own drawn radius so the glass cards feel
    // like they float in a layer above the raw scan, not glued to the rings.
    //
    // Clamped so the card's bounding box (140 wide, can scale up to ~1.1x by
    // depth) never crosses the Stack's edge — Stack clips by default, and at
    // distance ~0.95 (common with the mock data) an unclamped radius pushes
    // a card's edge past the field boundary, visibly cutting it off.
    const cardHalfWidthAtMaxScale = 140 / 2 * 1.1;
    final maxPlacementRadius = (maxRadius - cardHalfWidthAtMaxScale).clamp(0.0, maxRadius);
    final placementRadius = (node.distance * maxRadius * 1.05).clamp(0.0, maxPlacementRadius);
    final center = fieldSize / 2;
    final dx = center + cos(node.angleRadians) * placementRadius;
    final dy = center + sin(node.angleRadians) * placementRadius;

    return Positioned(
      left: dx - 70,
      top: dy - 16,
      child: SizedBox(
        width: 140,
        child: EchoNodeCard(
          node: node,
          index: index,
          isPlaying: node.id == playingNodeId,
          onPlayTap: () => onPlayTap(node),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.nodeCount, required this.isScanning});

  final int nodeCount;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: GlassSurface(
        borderRadius: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StatusReadout(label: 'ECHOES DETECTED', value: '$nodeCount'),
            Container(width: 1, height: 28, color: AppColors.glassBorder),
            _StatusReadout(label: 'FIELD STATUS', value: isScanning ? 'LIVE' : 'PAUSED'),
          ],
        ),
      ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(begin: 0.15, curve: Curves.easeOut),
    );
  }
}

class _StatusReadout extends StatelessWidget {
  const _StatusReadout({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextTheme.hudLabel.copyWith(fontSize: 9)),
        const SizedBox(height: 2),
        Text(value, style: AppTextTheme.hudValue.copyWith(fontSize: 16)),
      ],
    );
  }
}
