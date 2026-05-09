import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../models/version_check_result.dart';

class UpdateIndicator extends StatelessWidget {
  final AsyncSnapshot<VersionCheckResult?> snapshot;

  const UpdateIndicator({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Tooltip(
        message: '正在檢查版本',
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final result = snapshot.data;
    if (result == null || result.hasError) {
      return Tooltip(
        message: result?.errorMessage ?? '檢查失敗',
        child: _IndicatorPill(
          icon: Icons.error_outline,
          color: cs.onSurfaceVariant,
          background: cs.surfaceContainerHigh,
        ),
      );
    }

    if (result.isUntracked) {
      return Tooltip(
        message: '版本未追蹤',
        child: _IndicatorPill(
          icon: Icons.help_outline,
          color: cs.onSurfaceVariant,
          background: cs.surfaceContainerHigh,
        ),
      );
    }

    if (result.updateAvailable) {
      return Tooltip(
        message: '可更新至 ${result.latestVersion}',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Text(
            '↑ ${result.latestVersion}',
            style: TextStyle(
              fontSize: 13,
              color: cs.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: '已是最新版 (${result.latestVersion})',
      child: _IndicatorPill(
        icon: Icons.check_circle_outline,
        color: AppSemanticColors.success,
        background: AppSemanticColors.success.withValues(alpha: 0.12),
      ),
    );
  }
}

class _IndicatorPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;

  const _IndicatorPill({
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
