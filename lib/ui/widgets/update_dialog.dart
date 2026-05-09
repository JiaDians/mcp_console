import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../models/mcp_server.dart';
import '../../models/version_check_result.dart';
import '../../providers/ai_clients_provider.dart';
import '../../providers/version_check_provider.dart';
import '../../services/local_version_service.dart';
import '../../services/update_service.dart';
import '../../services/version_check_service.dart';

/// Shows the live-log update dialog. Returns true when the update succeeds.
Future<bool?> showUpdateDialog(
  BuildContext context,
  WidgetRef ref,
  McpServer server,
  String newVersion,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UpdateDialog(
      server: server,
      newVersion: newVersion,
      onSuccess: () {
        LocalVersionService.clearCache();
        ref.invalidate(versionCheckProvider(server));
      },
    ),
  );
}

class UpdateDialog extends ConsumerStatefulWidget {
  final McpServer server;
  final String newVersion;
  final VoidCallback? onSuccess;

  const UpdateDialog({
    super.key,
    required this.server,
    required this.newVersion,
    this.onSuccess,
  });

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  final _log = <String>[];
  bool _running = true;
  bool _success = false;
  bool _verifying = false;
  VersionCheckResult? _verifyResult;
  final _scrollController = ScrollController();
  late final UpdateService _updateService;

  @override
  void initState() {
    super.initState();
    _updateService = UpdateService();
    _startUpdate();
  }

  Future<void> _startUpdate() async {
    final clientsAsync = await ref.read(aiClientsProvider.future);
    final configPaths = clientsAsync
        .where((c) => c.isEnabled && widget.server.clients.contains(c.type))
        .map((c) => c.configPath)
        .toList();

    try {
      await for (final line in _updateService.update(
        server: widget.server,
        newVersion: widget.newVersion,
        configPaths: configPaths,
      )) {
        if (!mounted) return;
        setState(() => _log.add(line));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
      if (mounted) {
        setState(() {
          _running = false;
          _success = true;
        });
        await _verifyUpdate();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _log.add('[error] $e');
          _running = false;
          _success = false;
        });
      }
    }
  }

  Future<void> _verifyUpdate() async {
    if (!mounted) return;
    setState(() => _verifying = true);
    LocalVersionService.clearCache();
    final updated = widget.server.copyWith(currentVersion: widget.newVersion);
    final result = await VersionCheckService().check(updated);
    if (mounted) {
      setState(() {
        _verifyResult = result;
        _verifying = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = _running
        ? '正在更新 ${widget.server.name}…'
        : _success
        ? '更新完成'
        : '更新失敗';

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _running
                ? Icons.sync
                : _success
                ? Icons.check_circle_outline
                : Icons.error_outline,
            color: _running
                ? cs.primary
                : _success
                ? AppSemanticColors.success
                : cs.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(title)),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '更新過程會即時顯示命令輸出，完成後會重新驗證版本。',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 240,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: cs.outlineVariant),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _log.length,
                  itemBuilder: (_, i) => Text(
                    _log[i],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            if (_success) ...[
              const SizedBox(height: AppSpacing.md),
              if (_verifying)
                const _InlineProgress(text: '驗證已安裝版本…')
              else if (_verifyResult != null)
                _VerifyBanner(result: _verifyResult!),
            ],
          ],
        ),
      ),
      actions: [
        if (_running)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        if (!_running)
          FilledButton(
            onPressed: () {
              if (_success) widget.onSuccess?.call();
              Navigator.pop(context, _success);
            },
            child: const Text('關閉'),
          ),
      ],
    );
  }
}

class _VerifyBanner extends StatelessWidget {
  final VersionCheckResult result;
  const _VerifyBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (result.hasError) {
      return _StatusBanner(
        icon: Icons.warning_amber_rounded,
        color: cs.onSurfaceVariant,
        text: '無法驗證：${result.errorMessage}',
      );
    }
    if (result.updateAvailable) {
      return _StatusBanner(
        icon: Icons.error_outline,
        color: cs.error,
        text: '仍未更新 — 最新版為 v${result.latestVersion}',
      );
    }
    return _StatusBanner(
      icon: Icons.check_circle_outline,
      color: AppSemanticColors.success,
      text: 'v${result.latestVersion} — 已是最新版',
    );
  }
}

class _InlineProgress extends StatelessWidget {
  final String text;

  const _InlineProgress({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
