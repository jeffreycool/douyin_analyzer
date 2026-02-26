import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../models/video_info.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          _buildTitleBar(theme),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      _buildHeroSection(theme),
                      const SizedBox(height: 32),
                      _buildInputSection(theme),
                      const SizedBox(height: 24),
                      _buildStatusSection(theme),
                      const SizedBox(height: 40),
                      _buildHistorySection(theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar(ThemeData theme) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Text(
            'Douyin Analyzer',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          _buildTitleBarButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onPressed: () => Get.toNamed('/settings'),
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.15),
                theme.colorScheme.tertiary.withValues(alpha: 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.smart_display_outlined,
            size: 32,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Analyze Douyin Videos',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Paste a Douyin share link below to extract audio, transcribe, and generate an AI summary.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            color: theme.colorScheme.surfaceContainerLowest,
          ),
          child: TextField(
            controller: controller.urlController,
            maxLines: 4,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: '.AppleSystemUIFont',
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText:
                  'Paste Douyin share text or URL here...\ne.g. https://v.douyin.com/xxxxxxx/',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                height: 1.5,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Obx(() {
          final processing = controller.isProcessing;
          return SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: processing
                  ? null
                  : () =>
                      controller.processUrl(controller.urlController.text),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                disabledBackgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
              child: processing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Analyzing...',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    )
                  : const Text('Start Analysis'),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatusSection(ThemeData theme) {
    return Obx(() {
      final currentStatus = controller.status.value;
      final error = controller.errorMessage.value;
      final progress = controller.progressMessage.value;

      if (currentStatus == PipelineStatus.idle && error.isEmpty) {
        return const SizedBox.shrink();
      }

      if (error.isNotEmpty && currentStatus == PipelineStatus.error) {
        return _buildErrorCard(theme, error);
      }

      if (currentStatus == PipelineStatus.completed) {
        return _buildCompletedCard(theme);
      }

      if (controller.isProcessing) {
        return _buildProgressCard(theme, currentStatus, progress);
      }

      return const SizedBox.shrink();
    });
  }

  Widget _buildProgressCard(
    ThemeData theme,
    PipelineStatus currentStatus,
    String progressMessage,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          _buildPipelineSteps(theme, currentStatus),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            borderRadius: BorderRadius.circular(4),
            backgroundColor:
                theme.colorScheme.primary.withValues(alpha: 0.1),
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            progressMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineSteps(ThemeData theme, PipelineStatus currentStatus) {
    final steps = [
      _PipelineStep(
        label: 'Download',
        icon: Icons.download_outlined,
        status: currentStatus,
        activeAt: PipelineStatus.downloading,
      ),
      _PipelineStep(
        label: 'Audio',
        icon: Icons.audiotrack_outlined,
        status: currentStatus,
        activeAt: PipelineStatus.extractingAudio,
      ),
      _PipelineStep(
        label: 'Transcribe',
        icon: Icons.record_voice_over_outlined,
        status: currentStatus,
        activeAt: PipelineStatus.transcribing,
      ),
      _PipelineStep(
        label: 'Summarize',
        icon: Icons.auto_awesome_outlined,
        status: currentStatus,
        activeAt: PipelineStatus.summarizing,
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Container(
              width: 32,
              height: 1.5,
              color: steps[i].isCompleted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          _buildStepIndicator(theme, steps[i]),
        ],
      ],
    );
  }

  Widget _buildStepIndicator(ThemeData theme, _PipelineStep step) {
    final isActive = step.isActive;
    final isCompleted = step.isCompleted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? theme.colorScheme.primary
                : isActive
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
          ),
          child: isActive
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : Icon(
                  isCompleted ? Icons.check : step.icon,
                  size: 16,
                  color: isCompleted
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          step.label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isActive || isCompleted
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontWeight:
                isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(ThemeData theme, String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          TextButton(
            onPressed: controller.resetForNewAnalysis,
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Analysis complete! View the result below or in the result page.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green.shade700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Get.toNamed('/result'),
            child: const Text('View Result'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(ThemeData theme) {
    return Obx(() {
      final items = controller.history;
      if (items.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent Analyses',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: controller.clearHistory,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  textStyle: theme.textTheme.labelSmall,
                ),
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _buildHistoryTile(theme, item)),
        ],
      );
    });
  }

  Widget _buildHistoryTile(ThemeData theme, VideoInfo item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Dismissible(
        key: ValueKey('${item.url}_${item.createdAt?.toIso8601String()}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => controller.removeHistoryItem(item),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.delete_outline,
              color: theme.colorScheme.error, size: 20),
        ),
        child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.viewHistoryItem(item),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.play_circle_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title ?? 'Untitled Video',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.author != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.author!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (item.createdAt != null)
                  Text(
                    _formatDate(item.createdAt!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'Delete',
                    onPressed: () => controller.removeHistoryItem(item),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.month}/${date.day}';
  }
}

/// Internal helper class to track pipeline step state.
class _PipelineStep {
  final String label;
  final IconData icon;
  final PipelineStatus status;
  final PipelineStatus activeAt;

  const _PipelineStep({
    required this.label,
    required this.icon,
    required this.status,
    required this.activeAt,
  });

  static const _order = [
    PipelineStatus.downloading,
    PipelineStatus.extractingAudio,
    PipelineStatus.transcribing,
    PipelineStatus.summarizing,
  ];

  bool get isActive => status == activeAt;

  bool get isCompleted {
    final currentIndex = _order.indexOf(status);
    final myIndex = _order.indexOf(activeAt);
    if (currentIndex == -1 || myIndex == -1) {
      // completed or error: all steps before are completed
      return status == PipelineStatus.completed ||
          (status == PipelineStatus.error && myIndex < _order.length);
    }
    return currentIndex > myIndex;
  }
}
