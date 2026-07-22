import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/nebula_background.dart';
import '../viewmodels/plant_signal_viewmodel.dart';

/// "Plant an echo": record a short voice note and anchor it to wherever the
/// user is standing. Pure presentation — all state and side effects live in
/// [PlantSignalViewModel].
class PlantSignalScreen extends ConsumerWidget {
  const PlantSignalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(plantSignalViewModelProvider);
    final viewModel = ref.read(plantSignalViewModelProvider.notifier);

    return Scaffold(
      body: NebulaBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(onClose: () => Navigator.of(context).maybePop()),
              Expanded(
                // ConstrainedBox + SingleChildScrollView (rather than a bare
                // Center) so the recording panel stays centered when it
                // fits, but scrolls instead of overflowing when the
                // on-screen keyboard shrinks available height while the
                // label TextField is focused.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: switch (state.status) {
                            RecordingStatus.planted =>
                              const _PlantedConfirmation(),
                            _ => _RecordingPanel(
                              state: state,
                              viewModel: viewModel,
                            ),
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plant an Echo',
                  style: AppTextTheme.headline,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'LEAVE A VOICE NOTE HERE',
                  // Matches the main screen's header subtitle treatment.
                  style: AppTextTheme.caption.copyWith(letterSpacing: 1.2),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onClose,
            // 12, not 30 — a square-with-rounded-corners badge, not a
            // circle (padding is already symmetric, so it's the radius
            // alone that was making this read as a circle before).
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
    );
  }
}

class _RecordingPanel extends StatelessWidget {
  const _RecordingPanel({required this.state, required this.viewModel});

  final PlantSignalUiState state;
  final PlantSignalViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isRecording = state.status == RecordingStatus.recording;
    final isRecorded = state.status == RecordingStatus.recorded;
    final isPlanting = state.status == RecordingStatus.planting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RecordButton(
            isRecording: isRecording,
            isBusy: isPlanting,
            onTap: () {
              if (isRecording) {
                viewModel.stopRecording();
              } else if (!isRecorded && !isPlanting) {
                viewModel.startRecording();
              }
            },
          ),
          const SizedBox(height: 24),
          Text(
            _statusLabel(state.status),
            style: AppTextTheme.body,
            textAlign: TextAlign.center,
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              state.errorMessage!,
              style: AppTextTheme.caption.copyWith(color: AppColors.amberWarn),
              textAlign: TextAlign.center,
            ),
          ],
          if (isRecorded) ...[
            const SizedBox(height: 32),
            _LabelAndPlant(viewModel: viewModel),
          ],
        ],
      ),
    );
  }

  String _statusLabel(RecordingStatus status) => switch (status) {
    RecordingStatus.idle => 'Tap the mic to record a short voice note.',
    RecordingStatus.recording => 'Recording… tap again to stop.',
    RecordingStatus.recorded => 'Recorded. Name your echo and plant it here.',
    RecordingStatus.planting => 'Anchoring to your current location…',
    RecordingStatus.error => 'Something went wrong.',
    RecordingStatus.planted => '',
  };
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.isRecording,
    required this.isBusy,
    required this.onTap,
  });

  final bool isRecording;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: isBusy ? null : onTap,
      child: SizedBox.square(
        dimension: 140,
        child: GlassSurface(
          borderRadius: 70,
          blurSigma: 20,
          tint: isRecording
              ? AppColors.magentaEdge.withValues(alpha: 0.18)
              : null,
          child: Center(
            child: isBusy
                ? const CircularProgressIndicator(
                    color: AppColors.violetGlow,
                    strokeWidth: 2,
                  )
                : Icon(
                    isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 42,
                    color: isRecording
                        ? AppColors.magentaEdge
                        : AppColors.violetGlow,
                  ),
          ),
        ),
      ),
    );

    if (!isRecording) return button;

    return button
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.06, 1.06),
          duration: 700.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _LabelAndPlant extends StatefulWidget {
  const _LabelAndPlant({required this.viewModel});

  final PlantSignalViewModel viewModel;

  @override
  State<_LabelAndPlant> createState() => _LabelAndPlantState();
}

class _LabelAndPlantState extends State<_LabelAndPlant> {
  final _controller = TextEditingController();
  bool _isGuided = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlassSurface(
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _controller,
            style: AppTextTheme.body.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Name this echo (optional)',
              hintStyle: AppTextTheme.body,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _GuidedToggle(
          isGuided: _isGuided,
          onChanged: (value) => setState(() => _isGuided = value),
        ),
        const SizedBox(height: 8),
        Text(
          _isGuided
              ? 'Finder gets a live compass arrow to walk toward.'
              : 'Finder gets no directional help — pure exploration.',
          style: AppTextTheme.caption.copyWith(fontSize: 11),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => widget.viewModel.plant(
            label: _controller.text,
            isGuided: _isGuided,
          ),
          child: GlassSurface(
            borderRadius: 14,
            tint: AppColors.violetGlow.withValues(alpha: 0.14),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                'Plant Echo',
                style: AppTextTheme.title.copyWith(color: AppColors.violetGlow),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Segmented Guided/Trackless picker for the planting flow — matches the
/// app's glass/segment visual language rather than a stock [Switch], which
/// would clash with the rest of this screen.
class _GuidedToggle extends StatelessWidget {
  const _GuidedToggle({required this.isGuided, required this.onChanged});

  final bool isGuided;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: 14,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Guided',
              icon: Icons.explore_rounded,
              selected: isGuided,
              color: AppColors.cyanPulse,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'Trackless',
              icon: Icons.visibility_off_rounded,
              selected: !isGuided,
              color: AppColors.violetGlow,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? color : AppColors.textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextTheme.caption.copyWith(
                color: selected ? color : AppColors.textMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantedConfirmation extends StatelessWidget {
  const _PlantedConfirmation();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Was a bare Icon — the one icon on this screen still missing the
        // rounded glass treatment everything else has. Sized as a circular
        // badge (padding + borderRadius = half the resulting box) rather
        // than a rectangle, matching the icon-button rounding language
        // used elsewhere (mic button, close button).
        GlassSurface(
              borderRadius: 52,
              padding: const EdgeInsets.all(10),
              tint: AppColors.signalGreen.withValues(alpha: 0.14),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 64,
                color: AppColors.signalGreen,
              ),
            )
            .animate()
            .scale(begin: const Offset(0.5, 0.5), curve: Curves.easeOutBack)
            .fadeIn(),
        const SizedBox(height: 16),
        Text(
          'Echo planted',
          style: AppTextTheme.headline,
        ).animate().fadeIn(delay: 150.ms),
        const SizedBox(height: 4),
        Text(
          'Anyone scanning within 5m will unlock it.',
          style: AppTextTheme.body,
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 250.ms),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: GlassSurface(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: Text(
              'Done',
              style: AppTextTheme.title.copyWith(color: AppColors.violetGlow),
            ),
          ),
        ),
      ],
    );
  }
}
