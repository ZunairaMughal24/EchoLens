import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/nebula_background.dart';
import '../../domain/entities/echo_node.dart';
import '../viewmodels/my_echoes_viewmodel.dart';

String _relativeTime(DateTime? dateTime) {
  if (dateTime == null) return '';
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}

/// Lists the user's own planted voice notes — separate from the ambient
/// radar view — so they can be played back or deleted. Without this, a
/// planted echo just stays anchored in physical space forever with no way
/// to take it back.
class MyEchoesScreen extends ConsumerWidget {
  const MyEchoesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myEchoesViewModelProvider);
    final viewModel = ref.read(myEchoesViewModelProvider.notifier);

    return Scaffold(
      body: NebulaBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(onClose: () => Navigator.of(context).maybePop()),
              Expanded(
                child: state.echoes.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        itemCount: state.echoes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final node = state.echoes[index];
                          return _MyEchoTile(
                            node: node,
                            index: index,
                            isPlaying: node.id == state.playingId,
                            onPlayTap: () => viewModel.play(node),
                            onDeleteTap: () async {
                              final confirmed = await _confirmDelete(context, node);
                              if (confirmed) viewModel.delete(node.id);
                            },
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

  Future<bool> _confirmDelete(BuildContext context, EchoNode node) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: GlassSurface(
          borderRadius: 20,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Delete this echo?', style: AppTextTheme.headline),
              const SizedBox(height: 8),
              Text(
                'This permanently removes "${node.label}" and its voice note. It can\'t be undone.',
                style: AppTextTheme.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      child: GlassSurface(
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Cancel',
                          style: AppTextTheme.title.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(true),
                      child: GlassSurface(
                        borderRadius: 14,
                        tint: AppColors.magentaEdge.withValues(alpha: 0.16),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Delete',
                          style: AppTextTheme.title.copyWith(color: AppColors.magentaEdge),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed ?? false;
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
                Text('My Echoes', style: AppTextTheme.headline, overflow: TextOverflow.ellipsis),
                Text(
                  'EVERYTHING YOU\'VE PLANTED',
                  style: AppTextTheme.caption.copyWith(letterSpacing: 1.2),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onClose,
            child: GlassSurface(
              borderRadius: 12,
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.15, curve: Curves.easeOut);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              "You haven't planted any echoes yet.",
              style: AppTextTheme.title.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Plant one from the main screen and it\'ll show up here.',
              style: AppTextTheme.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _MyEchoTile extends StatelessWidget {
  const _MyEchoTile({
    required this.node,
    required this.index,
    required this.isPlaying,
    required this.onPlayTap,
    required this.onDeleteTap,
  });

  final EchoNode node;
  final int index;
  final bool isPlaying;
  final VoidCallback onPlayTap;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: onPlayTap,
                child: GlassSurface(
                  borderRadius: 14,
                  blurSigma: 10,
                  padding: const EdgeInsets.all(8),
                  tint: AppColors.signalGreen.withValues(alpha: 0.12),
                  child: Icon(
                    isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                    size: 26,
                    color: AppColors.signalGreen,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      node.label,
                      style: AppTextTheme.cardLabel.copyWith(fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          node.isGuided ? Icons.explore_rounded : Icons.visibility_off_rounded,
                          size: 11,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(_relativeTime(node.plantedAt), style: AppTextTheme.caption),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDeleteTap,
                child: GlassSurface(
                  borderRadius: 14,
                  blurSigma: 10,
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 22,
                    color: AppColors.magentaEdge,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: 60 * index))
        .fadeIn(duration: 350.ms, curve: Curves.easeOut)
        .slideX(begin: 0.08, curve: Curves.easeOut);
  }
}
