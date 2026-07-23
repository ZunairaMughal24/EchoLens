import 'dart:async';
import 'dart:math';
import 'dart:ui' show lerpDouble;

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
///
/// Stateful (not a plain ConsumerWidget) to drive the right-to-left swipe
/// into My Echoes as a genuinely interactive, finger-following preview: an
/// [OverlayEntry] rendered on top of this screen, reclipped on every single
/// [onHorizontalDragUpdate] so the reveal boundary sits exactly under the
/// finger the whole time it's dragging — not a pre-baked animation that
/// only starts once the gesture has already ended.
class SpatialScanScreen extends ConsumerStatefulWidget {
  const SpatialScanScreen({super.key});

  @override
  ConsumerState<SpatialScanScreen> createState() => _SpatialScanScreenState();
}

class _SpatialScanScreenState extends ConsumerState<SpatialScanScreen>
    with TickerProviderStateMixin {
  // How far (in logical pixels) a drag needs to travel to fully reveal the
  // page — a fixed budget rather than "all the way to the screen edge," so
  // it feels the same regardless of where on the screen you start the swipe.
  static const _revealDragDistance = 260.0;

  Offset? _touchStart;
  double _touchYFraction = 0.5;
  final ValueNotifier<double> _edgeFraction = ValueNotifier(0);
  OverlayEntry? _swipeOverlay;
  AnimationController? _settleController;

  // Disposing an AnimationController twice throws — and _settleController
  // gets disposed from three different places (a new gesture starting, a
  // gesture ending, and this widget itself being torn down), so the field
  // must be nulled out immediately after every dispose, not just here.
  // Route everything through this one method rather than raw `?.dispose()`
  // calls scattered around.
  void _disposeSettleController() {
    _settleController?.dispose();
    _settleController = null;
  }

  @override
  void dispose() {
    _disposeSettleController();
    _swipeOverlay?.remove();
    _edgeFraction.dispose();
    super.dispose();
  }

  void _onSwipeStart(DragStartDetails details) {
    // Defensive cleanup in case a previous gesture's settle animation
    // somehow didn't finish before a new one started.
    _disposeSettleController();
    _swipeOverlay?.remove();

    _touchStart = details.globalPosition;
    _touchYFraction =
        (details.globalPosition.dy / MediaQuery.sizeOf(context).height).clamp(0.0, 1.0);
    _edgeFraction.value = 0;

    _swipeOverlay = OverlayEntry(
      builder: (context) => IgnorePointer(
        // Just a live preview until the gesture commits — real interaction
        // happens on the actual pushed route, a separate widget instance.
        child: ValueListenableBuilder<double>(
          valueListenable: _edgeFraction,
          builder: (context, value, child) {
            return ClipPath(
              clipper: _LiquidWipeClipper(value, touchYFraction: _touchYFraction),
              child: child,
            );
          },
          child: const MyEchoesScreen(),
        ),
      ),
    );
    Overlay.of(context).insert(_swipeOverlay!);
  }

  void _onSwipeUpdate(DragUpdateDetails details) {
    final start = _touchStart;
    if (start == null) return;
    // Directly tied to how far the finger has actually traveled from
    // where it first touched down — this is what makes the boundary
    // follow the finger 1:1 while dragging, rather than animating on a
    // fixed timeline the drag itself has no influence over.
    final dragged = (start.dx - details.globalPosition.dx).clamp(0.0, _revealDragDistance);
    _edgeFraction.value = dragged / _revealDragDistance;
  }

  void _onSwipeEnd(DragEndDetails details) {
    if (_touchStart == null) return;
    _touchStart = null;

    final velocity = details.primaryVelocity ?? 0;
    final shouldCommit = _edgeFraction.value > 0.4 || velocity < -600;

    _disposeSettleController();
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: shouldCommit ? 180 : 240),
    );
    _settleController = controller;
    final tween = Tween<double>(begin: _edgeFraction.value, end: shouldCommit ? 1.0 : 0.0);
    controller.addListener(() => _edgeFraction.value = tween.evaluate(controller));

    controller.forward().whenComplete(() {
      // A newer gesture may have already disposed and replaced this
      // controller (via _onSwipeStart's defensive cleanup) before this
      // one's animation finished — if so, it's already gone; touching or
      // disposing it again here is exactly what caused the crash.
      if (_settleController != controller) return;
      _disposeSettleController();
      if (!mounted) return;
      _swipeOverlay?.remove();
      _swipeOverlay = null;
      if (shouldCommit) {
        Navigator.of(context).push(_liquidSwipeRoute(const MyEchoesScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
      // Whole-screen swipe zone, not just the status bar strip — swipe
      // right-to-left starting from anywhere, including the right edge.
      // translucent (not opaque) so this only *listens*; it doesn't
      // change how anything paints or block taps on cards/buttons beneath
      // it (those are a different recognizer type — tap vs. horizontal
      // drag — competing in the same arena; a plain tap without much
      // sideways movement still resolves as a tap).
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onSwipeStart,
        onHorizontalDragUpdate: _onSwipeUpdate,
        onHorizontalDragEnd: _onSwipeEnd,
        child: NebulaBackground(
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
                          playedNodeIds: state.playedNodeIds,
                          onPlayTap: viewModel.playSignal,
                        ),
                      ),
                    ),
                    const _PitchCarousel(),
                    // No visible change here — swipe right-to-left
                    // anywhere on screen to open My Echoes.
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
      ),
    );
  }
}

/// A liquid, right-to-left wave wipe rather than the platform-default
/// transition — the incoming page is revealed through a wavy (not
/// straight) vertical boundary sweeping from the right edge to the left,
/// matching the direction of the swipe gesture that triggered it. Runs the
/// same way in reverse on pop, since [ClipPath] just reads off `animation`
/// directly rather than a separately-tracked direction flag.
Route<T> _liquidSwipeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    // Zero forward duration — by the time this route actually gets pushed
    // (from _SpatialScanScreenState._onSwipeEnd), the live drag preview has
    // already shown the page fully revealed a frame earlier; replaying the
    // reveal from scratch here would look like a visible double-animation.
    // The reverse (closing) transition still gets the full liquid wave,
    // since there's no live gesture driving that one.
    transitionDuration: Duration.zero,
    reverseTransitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
      return AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (context, child) {
          return ClipPath(
            clipper: _LiquidWipeClipper(curved.value),
            child: child,
          );
        },
      );
    },
  );
}

/// The wavy reveal boundary itself. The previous version moved 3 segments
/// in perfect unison off a single sine wave — that reads as a mechanical
/// "wavy line," not liquid, because every bulge breathes in lockstep. Real
/// liquid motion is *asynchronous*: different points along the edge lag
/// and lead each other, like the ripple is traveling rather than pulsing
/// uniformly. Built here from two sine harmonics at different
/// frequencies/phases summed per point, sampled densely and smoothed
/// through a continuous spline (not 3 independent bezier segments, which
/// looked visibly segmented/blocky up close).
class _LiquidWipeClipper extends CustomClipper<Path> {
  _LiquidWipeClipper(this.progress, {this.touchYFraction = 0.5});

  /// 0 = page fully hidden (about to enter from the right), 1 = fully
  /// revealed.
  final double progress;

  /// Where (0 = top, 1 = bottom) the finger actually touched down — the
  /// ripple is biased to be strongest there and fall off further along the
  /// edge, so the wave visibly originates from wherever you placed your
  /// finger rather than being uniform top-to-bottom. Defaults to center for
  /// the non-interactive uses (the instant push-resolve and the pop
  /// animation), which have no real touch point driving them.
  final double touchYFraction;

  static const _pointCount = 14;

  @override
  Path getClip(Size size) {
    final edgeX = size.width * (1 - progress);
    // 0 at both ends of the swipe, peaks mid-swipe — the liquid settles
    // perfectly flat the instant the page is fully open or fully closed,
    // rather than staying wavy at rest.
    final envelope = sin(progress * pi);

    final points = <Offset>[];
    for (var i = 0; i <= _pointCount; i++) {
      final t = i / _pointCount;
      // Two harmonics, deliberately mismatched in both frequency and
      // phase-drift-over-progress — that mismatch is what stops every
      // point from bulging at the same moment.
      final wobble = sin(t * 2 * pi * 1.7 + progress * 3.6) * 0.6 +
          sin(t * 2 * pi * 0.9 - progress * 2.3) * 0.4;
      // Gaussian falloff centered on the touch point — amplitude peaks
      // right where the finger is/was, fading out further along the edge.
      final distanceFromTouch = t - touchYFraction;
      final proximity = exp(-pow(distanceFromTouch * 3.2, 2));
      final amplitude = 34 * (0.35 + 0.65 * proximity);
      points.add(Offset(edgeX + wobble * amplitude * envelope, t * size.height));
    }

    final path = Path()..moveTo(size.width, 0)..lineTo(points.first.dx, points.first.dy);
    // Quadratic-through-midpoints: a standard trick for a smooth
    // continuous curve through a point set, rather than sharp corners at
    // every sample point.
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    path
      ..lineTo(size.width, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _LiquidWipeClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.touchYFraction != touchYFraction;
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

  /// 0 (nothing locked nearby) to 1 (standing right on top of one) — drives
  /// the self-marker's "heartbeat quickens as you approach" behavior.
  /// Reuses [EchoNode.distance] (the same real-GPS-derived value that
  /// already positions a card near the radar's center as you close in)
  /// rather than recomputing proximity separately, so the marker's
  /// urgency and the card's own inward drift always agree. Only locked
  /// nodes count — once something's already unlocked, the hunt for it is
  /// over, so it shouldn't keep the marker's pulse racing.
  double _nearestLockedIntensity(List<EchoNode> nodes) {
    double? closest;
    for (final node in nodes) {
      if (!node.isGeoAnchored || !node.isLocked) continue;
      if (closest == null || node.distance < closest) closest = node.distance;
    }
    if (closest == null) return 0.0;
    return (1 - closest).clamp(0.0, 1.0);
  }

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
          _SelfPositionMarker(
            isScanning: isScanning,
            proximityIntensity: _nearestLockedIntensity(declutteredNodes),
          ),
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

/// A crisp "you are here" dot with a slow outward sonar-style pulse ring,
/// centered on the radar. Doubles as a "hot/cold" indicator: the pulse
/// quickens, glows brighter, and warms from white toward amber — the same
/// color this app already uses for "pending unlock" on card lock icons —
/// as [proximityIntensity] rises, plus a matching haptic buzz. Pauses in
/// step with the radar's own sweep when scanning is paused, rather than
/// pulsing on regardless.
class _SelfPositionMarker extends StatefulWidget {
  const _SelfPositionMarker({
    required this.isScanning,
    required this.proximityIntensity,
  });

  final bool isScanning;

  /// 0 (nothing locked nearby) to 1 (standing right on top of one).
  final double proximityIntensity;

  @override
  State<_SelfPositionMarker> createState() => _SelfPositionMarkerState();
}

class _SelfPositionMarkerState extends State<_SelfPositionMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pulseDuration(widget.proximityIntensity),
  );

  Timer? _hapticTimer;

  // 2200ms resting, down to 650ms standing right on top of a locked echo —
  // a heartbeat that visibly quickens as you approach, not just a number
  // changing on a card.
  Duration _pulseDuration(double intensity) {
    final ms = lerpDouble(2200, 650, intensity)!;
    return Duration(milliseconds: ms.round());
  }

  @override
  void initState() {
    super.initState();
    if (widget.isScanning) _controller.repeat();
    _syncHaptics();
  }

  @override
  void didUpdateWidget(covariant _SelfPositionMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isScanning && _controller.isAnimating) {
      _controller.stop();
    }
    if (oldWidget.proximityIntensity != widget.proximityIntensity ||
        oldWidget.isScanning != widget.isScanning) {
      _controller.duration = _pulseDuration(widget.proximityIntensity);
      _syncHaptics();
    }
  }

  void _syncHaptics() {
    _hapticTimer?.cancel();
    _hapticTimer = null;
    // Below this, "closing in" doesn't feel meaningful yet — stays quiet
    // rather than buzzing constantly whenever anything is even vaguely
    // geo-anchored somewhere on the map.
    const hapticThreshold = 0.15;
    if (!widget.isScanning || widget.proximityIntensity < hapticThreshold) return;
    final intervalMs = lerpDouble(1400, 300, widget.proximityIntensity)!.round();
    _hapticTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => HapticFeedback.lightImpact(),
    );
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markerColor = Color.lerp(
      AppColors.textPrimary,
      AppColors.amberWarn,
      widget.proximityIntensity,
    )!;

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
                  opacity: (1 - t) * (0.6 + 0.3 * widget.proximityIntensity),
                  child: Transform.scale(
                    scale: 0.3 + t * 1.7,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: markerColor,
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
        // Rebuilt whenever proximityIntensity/color changes (a normal
        // widget rebuild, driven by location updates) but still only once
        // per *animation frame* — the `child` optimization here is about
        // not rebuilding 60x/second while the ring animates, not about
        // never rebuilding at all.
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: markerColor,
            boxShadow: [
              BoxShadow(
                color: markerColor.withValues(alpha: 0.8),
                blurRadius: 8 + 6 * widget.proximityIntensity,
                spreadRadius: 1 + 2 * widget.proximityIntensity,
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
