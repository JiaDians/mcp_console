import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
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
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: '移除 MCP',
            onPressed: () => _showRemoveDialog(context, ref),
          ),
        ],
      ),
      body: _DetailLayout(
        server: server,
        versionAsync: versionAsync,
        onUpdate: (version) => _showUpdateDialog(context, ref, version),
      ),
    );
  }

  void _showEditScreen(BuildContext context, WidgetRef ref) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => McpEditScreen(server: server)),
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
    BuildContext context,
    WidgetRef ref,
    String newVersion,
  ) {
    showUpdateDialog(context, ref, server, newVersion);
  }
}

class _DetailLayout extends StatelessWidget {
  final McpServer server;
  final AsyncValue<dynamic>? versionAsync;
  final void Function(String version) onUpdate;

  const _DetailLayout({
    required this.server,
    required this.versionAsync,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.wide;
        final overview = _buildOverview(context);
        final transport = _buildTransport(context);
        final secrets = _buildSecrets();
        final side = _buildSide(context);

        if (isWide) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              if (server.disabled) _DisabledBanner(server: server),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        overview,
                        const SizedBox(height: AppSpacing.lg),
                        transport,
                        if (secrets != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          secrets,
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 2, child: side),
                ],
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (server.disabled) _DisabledBanner(server: server),
            overview,
            const SizedBox(height: AppSpacing.lg),
            transport,
            if (secrets != null) ...[
              const SizedBox(height: AppSpacing.lg),
              secrets,
            ],
            const SizedBox(height: AppSpacing.lg),
            side,
          ],
        );
      },
    );
  }

  Widget _buildOverview(BuildContext context) {
    final command = server.url != null
        ? server.url!
        : '${server.command} ${server.args.join(' ')}'.trim();
    return _Section(
      title: '概覽',
      icon: Icons.dashboard_customize_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Badge(server.type.label),
              if (server.currentVersion != null)
                _Badge('v${server.currentVersion}'),
              if (server.disabled) _Badge('停用'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('啟動方式', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          _MonoText(command),
        ],
      ),
    );
  }

  Widget _buildTransport(BuildContext context) {
    return _Section(
      title: server.url != null ? '傳輸端點' : '指令參數',
      icon: server.url != null ? Icons.http_outlined : Icons.terminal_outlined,
      child: server.url != null
          ? _MonoText(server.url!)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.play_arrow_outlined,
                  label: '指令',
                  value: server.command.isEmpty ? '(empty)' : server.command,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('參數', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                server.args.isEmpty
                    ? Text(
                        '未設定參數',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: server.args.map(_Badge.new).toList(),
                      ),
              ],
            ),
    );
  }

  Widget? _buildSecrets() {
    if (server.headers.isEmpty && server.env.isEmpty) return null;
    return _Section(
      title: '敏感資訊',
      icon: Icons.lock_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (server.headers.isNotEmpty) ...[
            const _SubsectionLabel('HTTP 標頭'),
            _MaskedKeyValueList(entries: server.headers),
          ],
          if (server.headers.isNotEmpty && server.env.isNotEmpty)
            const Divider(height: AppSpacing.xl),
          if (server.env.isNotEmpty) ...[
            const _SubsectionLabel('環境變數'),
            _MaskedKeyValueList(entries: server.env),
          ],
        ],
      ),
    );
  }

  Widget _buildSide(BuildContext context) {
    return Column(
      children: [
        _Section(
          title: server.type == McpType.sse ? '連線狀態' : '版本狀態',
          icon: server.type == McpType.sse
              ? Icons.sensors_outlined
              : Icons.system_update_alt,
          child: server.disabled
              ? Text(
                  '已停用，略過檢查',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : versionAsync!.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(
                    '檢查失敗：$e',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  data: (result) => _VersionSection(
                    server: server,
                    result: result,
                    onUpdate: () => onUpdate(result.latestVersion!),
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Section(
          title: '設定於',
          icon: Icons.desktop_windows_outlined,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: server.clients.map((c) {
              return Chip(
                avatar: Icon(c.icon, size: 16),
                label: Text(c.displayName),
              );
            }).toList(),
          ),
        ),
        if (server.timeout != null || server.alwaysAllow.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: '執行選項',
            icon: Icons.tune_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (server.timeout != null)
                  _InfoRow(
                    icon: Icons.timer_outlined,
                    label: '逾時',
                    value: '${server.timeout} ms',
                  ),
                if (server.timeout != null && server.alwaysAllow.isNotEmpty)
                  const SizedBox(height: AppSpacing.md),
                if (server.alwaysAllow.isNotEmpty) ...[
                  Text('自動核准工具', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: server.alwaysAllow.map(_Badge.new).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
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
      return _StatusBanner(
        icon: online ? Icons.wifi : Icons.wifi_off,
        text: online ? '伺服器在線' : '伺服器離線或無法連線',
        color: online
            ? AppSemanticColors.success
            : Theme.of(context).colorScheme.error,
      );
    }

    if (result.hasError) {
      return _StatusBanner(
        icon: Icons.warning_amber_rounded,
        text: '無法檢查：${result.errorMessage}',
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }

    final latestColor = result.updateAvailable
        ? Theme.of(context).colorScheme.error
        : AppSemanticColors.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          icon: Icons.inventory_2_outlined,
          label: '當前',
          value: server.currentVersion ?? '未追蹤',
        ),
        const SizedBox(height: AppSpacing.sm),
        _InfoRow(
          icon: Icons.cloud_download_outlined,
          label: '最新',
          value: result.latestVersion ?? '未知',
        ),
        const SizedBox(height: AppSpacing.md),
        _StatusBanner(
          icon: result.updateAvailable
              ? Icons.system_update_alt
              : Icons.check_circle_outline,
          text: result.updateAvailable ? '有新版本可更新' : '已是最新版',
          color: latestColor,
        ),
        if (result.updateAvailable) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onUpdate,
              icon: const Icon(Icons.system_update_alt, size: 18),
              label: Text('更新至 ${result.latestVersion}'),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusBanner({
    required this.icon,
    required this.text,
    required this.color,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
          title: Text(e.key, style: const TextStyle(fontFamily: 'monospace')),
          subtitle: Text(
            e.value.isEmpty
                ? '(empty)'
                : isRevealed
                ? e.value
                : '••••••',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
                  tooltip: isRevealed ? '隱藏' : '顯示',
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
                tooltip: '複製值',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: e.value));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('已複製 ${e.key}')));
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
  final IconData icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(icon, size: 18, color: cs.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
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
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _DisabledBanner extends StatelessWidget {
  final McpServer server;

  const _DisabledBanner({required this.server});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            Icon(Icons.block, color: cs.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${server.name} 已停用（disabled: true）',
                style: TextStyle(
                  color: cs.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: cs.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubsectionLabel extends StatelessWidget {
  final String text;

  const _SubsectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
