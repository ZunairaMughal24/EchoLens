import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/nebula_background.dart';
import '../../domain/entities/echo_node.dart';
import '../viewmodels/spatial_scan_viewmodel.dart';
import '../widgets/echo_guide_sheet.dart';
import '../widgets/echo_node_card.dart';
import '../widgets/pulse_core_radar.dart';
import 'my_echoes_screen.dart';
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
                    onMyEchoes: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MyEchoesScreen(),
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
                        playedNodeIds: state.playedNodeIds,
                        onPlayTap: viewModel.playSignal,
                      ),
                    ),
                  ),
                  const _PitchCarousel(),
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
    required this.onMyEchoes,
  });

  final bool isScanning;
  final VoidCallback onToggle;
  final VoidCallback onPlant;
  final VoidCallback onMyEchoes;

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
                      // caption (Nunito) rather than hudLabel: header and
                      // status panel are Nunito per request — hudLabel
                      // stays monospace since the card subtitle still uses
                      // it and that's meant to stay untouched.
                      style: AppTextTheme.caption.copyWith(letterSpacing: 1.2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: onMyEchoes,
                    // Green — distinct from violet (create) and cyan
                    // (scan): this is "your own content," closer in spirit
                    // to the unlocked/success accent than either of those.
                    child: GlassSurface(
                      borderRadius: 12,
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        Icons.library_music_rounded,
                        color: AppColors.signalGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onPlant,
                    // Violet, not cyan — plant/create reads as its own action
                    // distinct from scanning, not just another cyan button.
                    //
                    // Square-with-rounded-corners, not a circle: padding is
                    // now symmetric (was horizontal:14/vertical:10, which
                    // made a wide rectangle that a large radius then read
                    // as a pill) and radius dropped from 30 to 12.
                    child: GlassSurface(
                      borderRadius: 12,
                      padding: const EdgeInsets.all(10),
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
                      borderRadius: 12,
                      padding: const EdgeInsets.all(10),
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

class _PulseField extends StatelessWidget {
  const _PulseField({
    required this.nodes,
    required this.isScanning,
    required this.fieldSize,
    required this.playingNodeId,
    required this.playedNodeIds,
    required this.onPlayTap,
  });

  final List<EchoNode> nodes;
  final bool isScanning;
  final double fieldSize;
  final String? playingNodeId;
  final Set<String> playedNodeIds;
  final ValueChanged<EchoNode> onPlayTap;

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
    // Cards are 140px wide and can scale up to ~1.1x by depth (see
    // depthScale in EchoNodeCard) — 154px at their largest. 84 was smaller
    // than the card's own resting width, so this pass could report "far
    // enough apart" while cards still visibly overlapped; that's the actual
    // cause of the reported clustering, not just a busy layout. 168 clears
    // the card's largest rendered footprint with a little margin to spare.
    const minSeparationPx = 168.0;
    const maxPushPerPass =
        pi / 6; // clamp so near-center nodes (small radius) don't swing wildly

    // 6 passes (was 4) — the larger separation target above needs a bit
    // more iteration headroom to actually converge for a full node list.
    for (var pass = 0; pass < 6; pass++) {
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

  bool _shouldBloom(EchoNode node) =>
      node.isGeoAnchored &&
      !node.isLocked &&
      node.hasVoiceNote &&
      !playedNodeIds.contains(node.id);

  @override
  Widget build(BuildContext context) {
    // 0.86 (was 0.62): the drawn radar disk itself now fills most of the
    // field rather than being a noticeably smaller circle floating inside
    // a mostly-empty square. Card placement math is unaffected — it's
    // driven by fieldSize, not radarSize, so this doesn't change how
    // cards are laid out or clamped, only how big the radar reads visually.
    final radarSize = fieldSize * 0.85;
    // Declutter every build (cheap: a handful of nodes, a few passes) so
    // the radar dot and its card always agree — both are derived from
    // this same adjusted list, never the raw widget.nodes directly.
    final declutteredNodes = _declutterNodes(nodes, fieldSize);
    return SizedBox.square(
      dimension: fieldSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PulseCoreRadar(
            nodes: declutteredNodes,
            isScanning: isScanning,
            size: radarSize,
          ),
          // Not wrapped in Positioned — the Stack's own
          // `alignment: Alignment.center` lands this exactly on the radar's
          // visual center with no offset math needed, same spot the core
          // glow occupies. Explicit "you are here" reference point: before
          // this, the center was just ambient glow, nothing concretely read
          // as the user's own live position the way each node dot reads as
          // an echo's position — which is what actually makes a node's
          // inward drift toward center legible as "I'm getting closer."
          _SelfPositionMarker(isScanning: isScanning),
          // Bloom is purely derived from each node's current state, not a
          // triggered "event" — so it needs no listener/list bookkeeping.
          // A node either currently qualifies (renders, animating) or it
          // doesn't (isn't in the tree at all), so the repeating bloom
          // naturally starts the instant a node unlocks and stops the
          // instant it's played, just by mounting/unmounting.
          for (final node in declutteredNodes)
            if (_shouldBloom(node))
              _positionedBloom(node, fieldSize, radarSize),
          for (var i = 0; i < declutteredNodes.length; i++)
            _positionedNode(
              context,
              declutteredNodes[i],
              i,
              fieldSize,
              radarSize,
            ),
        ],
      ),
    );
  }

  /// Shared with [_positionedBloom] so the bloom lands exactly where the
  /// card is, using the *same* clamped placement math.
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
    BuildContext context,
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
          isPlaying: node.id == playingNodeId,
          hasBeenPlayed: playedNodeIds.contains(node.id),
          onPlayTap: () => onPlayTap(node),
          // Only locked geo-anchored nodes have anything to guide toward —
          // unlocked/ambient cards get no tap handler at all rather than a
          // no-op one, so they don't show a false affordance.
          onCardTap: node.isGeoAnchored && node.isLocked
              ? () => _handleCardTap(context, node)
              : null,
        ),
      ),
    );
  }

  void _handleCardTap(BuildContext context, EchoNode node) {
    if (node.isGuided) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => EchoGuideSheet(node: node),
      );
      return;
    }
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'This echo is trackless — no guidance. Keep scanning to find it.',
          style: AppTextTheme.body.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.nebulaSurface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _positionedBloom(EchoNode node, double fieldSize, double radarSize) {
    final center = _nodeCenter(node, fieldSize, radarSize);
    const baseSize = 56.0;
    return Positioned(
      key: ValueKey('bloom_${node.id}'),
      left: center.dx - baseSize / 2,
      top: center.dy - baseSize / 2,
      child: _BloomPulse(color: AppColors.signalGreen, size: baseSize),
    );
  }
}

/// A ring that expands outward and fades, then resets and blooms again —
/// repeating for as long as it's mounted. Deliberately driven by presence
/// in the widget tree rather than an internal "active" flag: [_PulseField]
/// only includes this for nodes that currently qualify (unlocked, has a
/// voice note, not yet played), so it starts the instant a node unlocks
/// and stops — its AnimationController disposed along with it — the
/// instant that condition stops holding, with no separate synchronization
/// logic needed here.
class _BloomPulse extends StatefulWidget {
  const _BloomPulse({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_BloomPulse> createState() => _BloomPulseState();
}

class _BloomPulseState extends State<_BloomPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final scale = 0.5 + t * 3.1;
          final opacity = (1 - t) * 0.85;
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.color, width: 2.5),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A crisp white "you are here" dot with a slow outward sonar-style pulse
/// ring, centered on the radar. Deliberately white/[AppColors.textPrimary],
/// not cyan — the ambient core glow and sweep are already cyan, so a cyan
/// marker here would just blend into them instead of reading as a distinct
/// "this one is you" reference point. Pauses in step with the radar's own
/// sweep when scanning is paused, rather than pulsing on regardless.
class _SelfPositionMarker extends StatefulWidget {
  const _SelfPositionMarker({required this.isScanning});

  final bool isScanning;

  @override
  State<_SelfPositionMarker> createState() => _SelfPositionMarkerState();
}

class _SelfPositionMarkerState extends State<_SelfPositionMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isScanning) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _SelfPositionMarker oldWidget) {
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
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: (1 - t) * 0.6,
                  child: Transform.scale(
                    scale: 0.3 + t * 1.7,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.textPrimary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                child!,
              ],
            ),
          );
        },
        // Built once, reused every frame — only the ring around it animates.
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textPrimary,
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.8),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rotates through the mechanic explanation plus every pitch angle the app
/// could be framed around — a single static line only ever tells one story;
/// a demo video (or a viewer who lingers) gets to see all of them without
/// committing this screen to just one positioning before that's decided.
class _PitchCarousel extends StatefulWidget {
  const _PitchCarousel();

  @override
  State<_PitchCarousel> createState() => _PitchCarouselState();
}

class _PitchCarouselState extends State<_PitchCarousel> {
  static const _lines = [
    'Signals are hidden nearby. Walk closer to unlock them.',
    'Leave a message where your story began.',
    'A voice note waiting for your future self.',
    'Hidden stories, told by the people who live here.',
    'A tribute that lives exactly where it matters....',
  ];

  // One gradient per line, not one for the whole card — this is how the
  // color lives on-screen now instead of as a tinted box.
  static const _gradients = [
    [AppColors.cyanPulse, AppColors.violetGlow],
    [AppColors.violetGlow, AppColors.magentaEdge],
    [AppColors.cyanPulse, AppColors.signalGreen],
    [AppColors.amberWarn, AppColors.magentaEdge],
    [AppColors.violetGlow, AppColors.magentaEdge],
  ];

  late final Timer _timer;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      setState(() => _index = (_index + 1) % _lines.length);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      // Fixed width (fills the row) and a fixed-height inner box — without
      // both, the card resized itself on every rotation since the lines
      // vary a lot in length ("A tribute that lives exactly where it
      // matters." vs. "Hidden stories, told by the people who live here."),
      // which read as the layout jittering rather than a clean crossfade.
      child: SizedBox(
        width: double.infinity,
        child: GlassSurface(
          // No tint — every other neutral (non-state) surface in the app,
          // like the status panel below, uses the plain default glass.
          // Coloring just this one card was what made it look out of place
          // against an otherwise consistently dark, monochrome-glass UI.
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: SizedBox(
            height: 40,
            child: Center(
              child: AnimatedSwitcher(
                duration: 450.ms,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                // ShaderMask paints the gradient, but only where the child
                // already has opaque pixels — the child's own color is
                // irrelevant (blended away by BlendMode.modulate), only its
                // alpha/shape matters, which is why plain white here still
                // ends up fully gradient-colored on screen.
                child: ShaderMask(
                  key: ValueKey(_index),
                  shaderCallback: (bounds) => LinearGradient(
                    colors: _gradients[_index],
                  ).createShader(bounds),
                  child: Text(
                    _lines[_index],
                    style: AppTextTheme.caption.copyWith(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    // textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 500.ms);
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
                  children: [
                    // Expanded + Center (was spaceBetween with left-aligned
                    // text) — the two readouts sat flush against the outer
                    // edges of the card with their text hugging the left,
                    // which read as lopsided rather than a clean two-up
                    // stat row. Each now centers within its own half.
                    Expanded(
                      child: Center(
                        child: _StatusReadout(
                          label: 'ECHOES DETECTED',
                          value: '$nodeCount',
                          valueColor: isScanning
                              ? AppColors.cyanPulse
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: AppColors.glassBorder,
                    ),
                    Expanded(
                      child: Center(
                        child: _StatusReadout(
                          label: 'FIELD STATUS',
                          value: isScanning ? 'LIVE' : 'PAUSED',
                          // The one deliberately-accented value on this
                          // screen — tied to actual state (cyan = actively
                          // scanning), not decoration.
                          valueColor: isScanning ? AppColors.cyanPulse : null,
                        ),
                      ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        // caption/title (Nunito), not hudLabel/hudValue — this is "the
        // bottom widget where we show live," explicitly asked to be
        // Nunito, distinct from the card subtitles which stay monospace.
        Text(
          label,
          style: AppTextTheme.caption.copyWith(
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextTheme.title.copyWith(fontSize: 16, color: valueColor),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
