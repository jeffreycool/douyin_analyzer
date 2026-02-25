import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/constants.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildSectionTitle(theme, 'Tool Paths'),
                      const SizedBox(height: 12),
                      _buildSettingsGroup(theme, [
                        _SettingsItem(
                          label: 'yt-dlp',
                          value: AppConstants.ytDlpPath,
                          icon: Icons.download_outlined,
                        ),
                        _SettingsItem(
                          label: 'ffmpeg',
                          value: AppConstants.ffmpegPath,
                          icon: Icons.audiotrack_outlined,
                        ),
                        _SettingsItem(
                          label: 'whisper-cli',
                          value: AppConstants.whisperCliPath,
                          icon: Icons.record_voice_over_outlined,
                        ),
                        _SettingsItem(
                          label: 'claude',
                          value: AppConstants.claudePath,
                          icon: Icons.auto_awesome_outlined,
                        ),
                      ]),
                      const SizedBox(height: 28),
                      _buildSectionTitle(theme, 'Model & Storage'),
                      const SizedBox(height: 12),
                      _buildSettingsGroup(theme, [
                        _SettingsItem(
                          label: 'Whisper Model',
                          value: AppConstants.whisperModelPath,
                          icon: Icons.memory_outlined,
                        ),
                        _SettingsItem(
                          label: 'Working Directory',
                          value: AppConstants.workDir,
                          icon: Icons.folder_outlined,
                        ),
                      ]),
                      const SizedBox(height: 28),
                      _buildSectionTitle(theme, 'About'),
                      const SizedBox(height: 12),
                      _buildAboutCard(theme),
                      const SizedBox(height: 32),
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
          Tooltip(
            message: 'Back to Home',
            child: InkWell(
              onTap: () => Get.back(),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Back',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Settings',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 72),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: -0.1,
      ),
    );
  }

  Widget _buildSettingsGroup(ThemeData theme, List<_SettingsItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 52,
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            _buildSettingsRow(theme, items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsRow(ThemeData theme, _SettingsItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.icon,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              item.label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'Menlo',
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.15),
                      theme.colorScheme.tertiary.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Version 1.0.0',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Douyin Analyzer extracts audio from Douyin videos, transcribes speech using Whisper, and generates AI-powered summaries using Claude.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pipeline: yt-dlp (download) -> ffmpeg (audio extraction) -> whisper-cli (ASR) -> claude (AI summary)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontFamily: 'Menlo',
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem {
  final String label;
  final String value;
  final IconData icon;

  const _SettingsItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}
