import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          _log.add('❌ $e');
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
      title: Text(title),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 240,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _log.length,
                  itemBuilder: (_, i) => Text(
                    _log[i],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
            if (_success) ...[
              const SizedBox(height: 12),
              if (_verifying)
                Row(children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text('驗證已安裝版本…',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ])
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
      return Row(children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text('無法驗證：${result.errorMessage}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ),
      ]);
    }
    if (result.updateAvailable) {
      return Row(children: [
        Icon(Icons.error_outline, size: 18, color: cs.error),
        const SizedBox(width: 6),
        Text('仍未更新 — 最新版為 v${result.latestVersion}',
            style: TextStyle(color: cs.error, fontSize: 13)),
      ]);
    }
    return Row(children: [
      const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
      const SizedBox(width: 6),
      Text('✓ v${result.latestVersion} — 已是最新版',
          style: const TextStyle(
              color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }
}
