import 'package:flutter/material.dart';

import '../../models/version_check_result.dart';

class UpdateIndicator extends StatelessWidget {
  final AsyncSnapshot<VersionCheckResult?> snapshot;

  const UpdateIndicator({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final result = snapshot.data;
    if (result == null || result.hasError) {
      return Tooltip(
        message: result?.errorMessage ?? '檢查失敗',
        child: const Icon(Icons.error_outline, size: 18, color: Colors.grey),
      );
    }

    if (result.isUntracked) {
      return const Tooltip(
        message: '版本未追蹤',
        child: Icon(Icons.help_outline, size: 18, color: Colors.grey),
      );
    }

    if (result.updateAvailable) {
      return Tooltip(
        message: '可更新至 ${result.latestVersion}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '↑ ${result.latestVersion}',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onError,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: '已是最新版 (${result.latestVersion})',
      child: const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
    );
  }
}
