import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/mcp_server.dart';
import '../../models/mcp_type.dart';
import '../../models/ai_client.dart';
import '../../providers/version_check_provider.dart';
import '../../providers/ai_clients_provider.dart';
import '../../providers/mcp_list_provider.dart';
import '../../services/config_parser_service.dart';
import '../../services/local_version_service.dart';
import '../widgets/update_dialog.dart';
import 'mcp_edit_screen.dart';

class McpDetailScreen extends ConsumerWidget {
  final McpServer server;

  const McpDetailScreen({super.key, required this.server});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = server.disabled
        ? null
        : ref.watch(versionCheckProvider(server));

    return Scaffold(
      appBar: AppBar(
        title: Text(server.name),
        actions: [
          if (!server.disabled)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重新檢查',
              onPressed: () {
                LocalVersionService.clearCache();
                ref.invalidate(versionCheckProvider(server));
              },
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '編輯設定',
            onPressed: () => _showEditScreen(context, ref),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            tooltip: '移除 MCP',
            onPressed: () => _showRemoveDialog(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Disabled banner ──────────────────────────────────────────────
          if (server.disabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block, size: 18,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Text('此 MCP 已停用（disabled: true）',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

          // ── Type ────────────────────────────────────────────────────────
          _Section(
            title: '類型',
            child: _Badge(server.type.label),
          ),

          // ── Transport ────────────────────────────────────────────────────
          if (server.url != null)
            _Section(
              title: '端點 URL',
              child: _MonoText(server.url!),
            )
          else
            _Section(
              title: '指令',
              child: _MonoText('${server.command} ${server.args.join(' ')}'.trim()),
            ),

          // ── Headers (HTTP/SSE only) ───────────────────────────────────────
          if (server.headers.isNotEmpty)
            _Section(
              title: 'HTTP 標頭',
              child: _MaskedKeyValueList(entries: server.headers),
            ),

          // ── Env vars ─────────────────────────────────────────────────────
          if (server.env.isNotEmpty)
            _Section(
              title: '環境變數',
              child: _MaskedKeyValueList(entries: server.env),
            ),

          // ── Runtime options ───────────────────────────────────────────────
          if (server.timeout != null || server.alwaysAllow.isNotEmpty)
            _Section(
              title: '選項',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (server.timeout != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text('逾時：${server.timeout} ms'),
                        ],
                      ),
                    ),
                  if (server.alwaysAllow.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 16),
                          SizedBox(width: 6),
                          Text('自動核准工具：'),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: server.alwaysAllow.map((tool) {
                        return Chip(
                          label: Text(tool),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

          // ── Clients ────────────────────────────────────────────────────
          _Section(
            title: '設定於',
            child: Wrap(
              spacing: 8,
              children: server.clients.map((c) {
                return Chip(
                  avatar: Icon(c.icon, size: 16),
                  label: Text(c.displayName),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ),

          // ── Version / Connectivity ────────────────────────────────────────
          _Section(
            title: server.type == McpType.sse ? '連線狀態' : '版本',
            child: server.disabled
                ? const Text('已停用，略過檢查',
                    style: TextStyle(color: Colors.grey))
                : versionAsync!.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e',
                        style: const TextStyle(color: Colors.red)),
                    data: (result) => _VersionSection(
                      server: server,
                      result: result,
                      onUpdate: () =>
                          _showUpdateDialog(context, ref, result.latestVersion!),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showEditScreen(BuildContext context, WidgetRef ref) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => McpEditScreen(server: server),
      ),
    ).then((saved) {
      if (saved == true && context.mounted) {
        // Detail screen data is stale after edit — go back to home
        Navigator.of(context).pop();
      }
    });
  }

  void _showRemoveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _RemoveDialog(server: server),
    ).then((removed) {
      if (removed == true && context.mounted) {
        ref.invalidate(mcpListProvider);
        Navigator.of(context).pop(); // close detail screen
      }
    });
  }

  void _showUpdateDialog(
      BuildContext context, WidgetRef ref, String newVersion) {
    showUpdateDialog(context, ref, server, newVersion);
  }
}

class _VersionSection extends ConsumerWidget {
  final McpServer server;
  final dynamic result;
  final VoidCallback onUpdate;

  const _VersionSection({
    required this.server,
    required this.result,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── HTTP/SSE connectivity result ─────────────────────────────────────────
    if (result.isConnectivity) {
      final online = result.isOnline == true;
      return Row(
        children: [
          Icon(
            online ? Icons.wifi : Icons.wifi_off,
            size: 18,
            color: online ? Colors.green : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Text(
            online ? '伺服器在線' : '伺服器離線或無法連線',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: online ? Colors.green : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      );
    }

    // ── Version check error ──────────────────────────────────────────────────
    if (result.hasError) {
      return Text('無法檢查: ${result.errorMessage}',
          style: const TextStyle(color: Colors.grey));
    }

    // ── Normal version check ──────────────────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('當前: ${server.currentVersion ?? "未追蹤"}'),
            const Spacer(),
            Text(
              '最新: ${result.latestVersion ?? "未知"}',
              style: TextStyle(
                color: result.updateAvailable
                    ? Theme.of(context).colorScheme.error
                    : Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (result.updateAvailable) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onUpdate,
            icon: const Icon(Icons.system_update_alt, size: 18),
            label: Text('更新至 ${result.latestVersion}'),
          ),
        ],
      ],
    );
  }
}

// ─── Remove dialog ──────────────────────────────────────────────────────────

class _RemoveDialog extends ConsumerStatefulWidget {
  final McpServer server;
  const _RemoveDialog({required this.server});

  @override
  ConsumerState<_RemoveDialog> createState() => _RemoveDialogState();
}

class _RemoveDialogState extends ConsumerState<_RemoveDialog> {
  late Map<AiClientType, bool> _selected;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    // Pre-select all clients that contain this server
    _selected = {for (final c in widget.server.clients) c: true};
  }

  Future<void> _remove() async {
    setState(() => _removing = true);
    final parser = ConfigParserService();
    final clients = await ref.read(aiClientsProvider.future);

    for (final client in clients) {
      if (_selected[client.type] == true) {
        await parser.removeServerFromConfig(
          configPath: client.configPath,
          mcpName: widget.server.name,
        );
      }
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final anySelected = _selected.values.any((v) => v);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.delete_outline, color: colorScheme.error),
          const SizedBox(width: 8),
          const Text('移除 MCP'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  const TextSpan(text: '將 '),
                  TextSpan(
                    text: widget.server.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' 從以下設定檔中移除：'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...widget.server.clients.map((clientType) {
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _selected[clientType] ?? false,
                title: Row(
                  children: [
                    Icon(clientType.icon, size: 16),
                    const SizedBox(width: 6),
                    Text(clientType.displayName),
                  ],
                ),
                onChanged: _removing
                    ? null
                    : (v) => setState(() => _selected[clientType] = v!),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _removing ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
          onPressed: (_removing || !anySelected) ? null : _remove,
          child: _removing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('移除'),
        ),
      ],
    );
  }
}

// ─── Small helper widgets ───────────────────────────────────────────────────

class _MaskedKeyValueList extends StatefulWidget {
  final Map<String, String> entries;
  const _MaskedKeyValueList({required this.entries});

  @override
  State<_MaskedKeyValueList> createState() => _MaskedKeyValueListState();
}

class _MaskedKeyValueListState extends State<_MaskedKeyValueList> {
  final _revealed = <String>{};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.entries.entries.map((e) {
        final isRevealed = _revealed.contains(e.key);
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(e.key, style: const TextStyle(fontFamily: 'monospace')),
          subtitle: Text(
            e.value.isEmpty
                ? '(empty)'
                : isRevealed
                    ? e.value
                    : '••••••',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (e.value.isNotEmpty)
                IconButton(
                  icon: Icon(
                    isRevealed ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                  ),
                  tooltip: isRevealed ? 'Hide' : 'Show',
                  onPressed: () => setState(() {
                    if (isRevealed) {
                      _revealed.remove(e.key);
                    } else {
                      _revealed.add(e.key);
                    }
                  }),
                ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy value',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: e.value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已複製 ${e.key}')),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _MonoText extends StatelessWidget {
  final String text;
  const _MonoText(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          text.isEmpty ? '(empty)' : text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer)),
    );
  }
}
