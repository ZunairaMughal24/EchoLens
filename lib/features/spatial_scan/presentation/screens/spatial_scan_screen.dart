import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/nebula_background.dart';
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

    // One-shot side effect on state *changes* (not current state) — a
    // persistent banner sat under the header indefinitely; a SnackBar with
    // a direct settings action is less intrusive and actually actionable.
    ref.listen(spatialScanViewModelProvider, (previous, next) {
      final failure = next.locationFailure;
      if (failure == null) return;
      if (previous?.locationFailure?.message == failure.message) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure.message,
            style: AppTextTheme.body.copyWith(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.nebulaSurface,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: failure.action == LocationErrorAction.openLocationSettings
                ? 'ENABLE'
                : 'SETTINGS',
            textColor: AppColors.cyanPulse,
            onPressed: viewModel.resolveLocationFailure,
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    });

    return Scaffold(
      body: NebulaBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 0.85 (was 0.62): the field claims most of the Expanded
              // region's height now rather than leaving a wide margin —
              // still safely bounded, since Expanded already constrains
              // constraints.maxHeight to whatever's left after the header
              // and status panel.
              //
              // Width is capped below the full available width (not just
              // constraints.maxWidth) so cards — clamped to stay within
              // fieldSize's bounds in _PulseField — keep a real margin
              // from the screen edges no matter how large radarSize gets;
              // clamping to fieldSize alone doesn't guarantee that once
              // fieldSize itself is allowed to equal the full screen
              // width. 20px matches the header/status panel's own
              // horizontal padding, so the edges all line up.
              const horizontalMargin = 6.0;
              final fieldSize = min(
                constraints.maxWidth - horizontalMargin * 2,
                constraints.maxHeight * 0.85,
              );
              return Column(
                children: [
                  _Header(
                    isScanning: state.isScanning,
                    onToggle: viewModel.toggleScanning,
                    onPlant: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PlantSignalScreen(),
                      ),
                    ),
                  ),
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
                  _StatusPanel(
                    nodeCount: state.nodes.length,
                    isScanning: state.isScanning,
                  ),
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
  const _Header({
    required this.isScanning,
    required this.onToggle,
    required this.onPlant,
  });

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
                    Text(
                      'EchoLens',
                      style: AppTextTheme.display,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                    // Violet, not cyan — plant/create reads as its own action
                    // distinct from scanning, not just another cyan button.
                    child: GlassSurface(
                      borderRadius: 30,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppColors.violetGlow,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onToggle,
                    child: GlassSurface(
                      borderRadius: 30,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Icon(
                        isScanning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AppColors.cyanPulse,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.15, curve: Curves.easeOut);
  }
}

class _PulseField extends ConsumerStatefulWidget {
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
  ConsumerState<_PulseField> createState() => _PulseFieldState();
}

class _PulseFieldState extends ConsumerState<_PulseField> {
  final List<UnlockEvent> _shockwaves = [];
  ProviderSubscription<SpatialScanUiState>? _unlockSubscription;

  @override
  void initState() {
    super.initState();
    // listenManual (not the ref.listen-in-build form) because this needs to
    // live for the whole State's lifetime, not re-registered every build —
    // it drives transient overlay widgets that manage their own removal.
    _unlockSubscription = ref.listenManual(spatialScanViewModelProvider, (
      previous,
      next,
    ) {
      final event = next.unlockEvent;
      if (event == null || identical(event, previous?.unlockEvent)) return;
      setState(() => _shockwaves.add(event));
    });
  }

  @override
  void dispose() {
    _unlockSubscription?.close();
    super.dispose();
  }

  void _removeShockwave(UnlockEvent event) {
    if (mounted) setState(() => _shockwaves.remove(event));
  }

  @override
  Widget build(BuildContext context) {
    // 0.86 (was 0.62): the drawn radar disk itself now fills most of the
    // field rather than being a noticeably smaller circle floating inside
    // a mostly-empty square. Card placement math is unaffected — it's
    // driven by fieldSize, not radarSize, so this doesn't change how
    // cards are laid out or clamped, only how big the radar reads visually.
    final radarSize = widget.fieldSize * 0.85;
    // Declutter every build (cheap: a handful of nodes, a few passes) so
    // the radar dot and its card always agree — both are derived from
    // this same adjusted list, never the raw widget.nodes directly.
    final nodes = _declutterNodes(widget.nodes, widget.fieldSize);
    return SizedBox.square(
      dimension: widget.fieldSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PulseCoreRadar(
            nodes: nodes,
            isScanning: widget.isScanning,
            size: radarSize,
          ),
          for (var i = 0; i < nodes.length; i++)
            _positionedNode(nodes[i], i, widget.fieldSize, radarSize),
          for (final shockwave in _shockwaves)
            _positionedShockwave(shockwave, widget.fieldSize, radarSize),
        ],
      ),
    );
  }

  /// Nudges node angles apart when their projected radar positions would
  /// overlap, so glass cards never stack on each other. Radius (how far
  /// from center) is left untouched — for geo-anchored nodes that's real
  /// GPS proximity, meaningful data; only the angle is free to adjust
  /// purely for layout. Cheap enough to run every build: a handful of
  /// nodes, a few passes of pairwise pixel-distance checks.
  List<EchoNode> _declutterNodes(List<EchoNode> nodes, double fieldSize) {
    if (nodes.length < 2) return nodes;

    double placementRadiusFor(EchoNode node) {
      final maxRadius = fieldSize / 2;
      const cardHalfWidthAtMaxScale = 140 / 2 * 1.1;
      final maxPlacementRadius = (maxRadius - cardHalfWidthAtMaxScale).clamp(
        0.0,
        maxRadius,
      );
      return (node.distance * maxRadius * 1.05).clamp(0.0, maxPlacementRadius);
    }

    final angles = [for (final node in nodes) node.angleRadians];
    final radii = [for (final node in nodes) placementRadiusFor(node)];
    const minSeparationPx = 84.0; // card footprint + a little breathing room
    const maxPushPerPass =
        pi / 6; // clamp so near-center nodes (small radius) don't swing wildly

    for (var pass = 0; pass < 4; pass++) {
      for (var i = 0; i < nodes.length; i++) {
        for (var j = i + 1; j < nodes.length; j++) {
          final posA = Offset(
            cos(angles[i]) * radii[i],
            sin(angles[i]) * radii[i],
          );
          final posB = Offset(
            cos(angles[j]) * radii[j],
            sin(angles[j]) * radii[j],
          );
          final gap = (posA - posB).distance;
          if (gap >= minSeparationPx) continue;

          final avgRadius = (radii[i] + radii[j]) / 2 + 1;
          final push = gap < 0.5
              ? 0.12 // exactly coincident — nudge arbitrarily to break the tie
              : ((minSeparationPx - gap) / avgRadius * 0.5).clamp(
                  0.0,
                  maxPushPerPass,
                );
          angles[i] -= push;
          angles[j] += push;
        }
      }
    }

    return [
      for (var i = 0; i < nodes.length; i++)
        nodes[i].copyWith(angleRadians: angles[i]),
    ];
  }

  /// Shared with [_positionedShockwave] so the burst lands exactly where
  /// the card is, using the *same* clamped placement math.
  Offset _nodeCenter(EchoNode node, double fieldSize, double radarSize) {
    final maxRadius = fieldSize / 2;
    const cardHalfWidthAtMaxScale = 140 / 2 * 1.1;
    final maxPlacementRadius = (maxRadius - cardHalfWidthAtMaxScale).clamp(
      0.0,
      maxRadius,
    );
    final placementRadius = (node.distance * maxRadius * 1.05).clamp(
      0.0,
      maxPlacementRadius,
    );
    final center = fieldSize / 2;
    return Offset(
      center + cos(node.angleRadians) * placementRadius,
      center + sin(node.angleRadians) * placementRadius,
    );
  }

  Widget _positionedNode(
    EchoNode node,
    int index,
    double fieldSize,
    double radarSize,
  ) {
    // Nodes read past the radar's own drawn radius so the glass cards feel
    // like they float in a layer above the raw scan, not glued to the rings.
    //
    // Clamped (inside _nodeCenter) so the card's bounding box (140 wide,
    // can scale up to ~1.1x by depth) never crosses the Stack's edge —
    // Stack clips by default, and at distance ~0.95 (common with the mock
    // data) an unclamped radius pushes a card's edge past the field
    // boundary, visibly cutting it off.
    final center = _nodeCenter(node, fieldSize, radarSize);

    // AnimatedPositioned (not plain Positioned) so declutter nudges, drift,
    // and proximity-driven movement all glide smoothly instead of
    // snapping — keyed by node id so Flutter tracks "this is the same
    // card" across rebuilds even if the list order shifts.
    return AnimatedPositioned(
      key: ValueKey(node.id),
      duration: 600.ms,
      curve: Curves.easeOutCubic,
      left: center.dx - 70,
      top: center.dy - 16,
      child: SizedBox(
        width: 140,
        child: EchoNodeCard(
          node: node,
          index: index,
          isPlaying: node.id == widget.playingNodeId,
          onPlayTap: () => widget.onPlayTap(node),
        ),
      ),
    );
  }

  Widget _positionedShockwave(
    UnlockEvent event,
    double fieldSize,
    double radarSize,
  ) {
    final center = _nodeCenter(event.node, fieldSize, radarSize);
    const baseSize = 56.0;
    return Positioned(
      left: center.dx - baseSize / 2,
      top: center.dy - baseSize / 2,
      child: IgnorePointer(
        child:
            Container(
                  width: baseSize,
                  height: baseSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.signalGreen,
                      width: 2.5,
                    ),
                  ),
                )
                .animate(onComplete: (_) => _removeShockwave(event))
                .scaleXY(
                  begin: 0.4,
                  end: 4.5,
                  duration: 750.ms,
                  curve: Curves.easeOut,
                )
                .fadeOut(begin: 0.9, duration: 750.ms, curve: Curves.easeOut),
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
      child:
          GlassSurface(
                borderRadius: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatusReadout(
                      label: 'ECHOES DETECTED',
                      value: '$nodeCount',
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: AppColors.glassBorder,
                    ),
                    _StatusReadout(
                      label: 'FIELD STATUS',
                      value: isScanning ? 'LIVE' : 'PAUSED',
                      // The one deliberately-accented value on this screen — tied
                      // to actual state (cyan = actively scanning), not decoration.
                      valueColor: isScanning ? AppColors.cyanPulse : null,
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(delay: 300.ms, duration: 500.ms)
              .slideY(begin: 0.15, curve: Curves.easeOut),
    );
  }
}

class _StatusReadout extends StatelessWidget {
  const _StatusReadout({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextTheme.hudLabel.copyWith(fontSize: 9)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextTheme.hudValue.copyWith(
            fontSize: 16,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
