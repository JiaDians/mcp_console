import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../models/mcp_server.dart';
import '../../models/mcp_type.dart';
import '../../models/ai_client.dart';
import '../../providers/version_check_provider.dart';
import '../screens/mcp_detail_screen.dart';
import '../widgets/update_dialog.dart';
import 'update_indicator.dart';

class McpCard extends ConsumerWidget {
  final McpServer server;

  const McpCard({super.key, required this.server});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = server.disabled
        ? null
        : ref.watch(versionCheckProvider(server));

    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => McpDetailScreen(server: server)),
          );
        },
        child: Opacity(
          opacity: server.disabled ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TypeIcon(type: server.type),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  server.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              if (server.disabled)
                                const _DisabledBadge()
                              else if (versionAsync != null)
                                versionAsync.when(
                                  data: (result) {
                                    if (result.updateAvailable &&
                                        result.latestVersion != null) {
                                      return _QuickUpdateButton(
                                        server: server,
                                        latestVersion: result.latestVersion!,
                                      );
                                    }
                                    return UpdateIndicator(
                                      snapshot: AsyncSnapshot.withData(
                                        ConnectionState.done,
                                        result,
                                      ),
                                    );
                                  },
                                  loading: () => UpdateIndicator(
                                    snapshot: const AsyncSnapshot.waiting(),
                                  ),
                                  error: (e, _) => UpdateIndicator(
                                    snapshot: AsyncSnapshot.withError(
                                      ConnectionState.done,
                                      e,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            server.type == McpType.sse
                                ? server.url ?? '(no URL)'
                                : '${server.command} ${server.args.join(' ')}'
                                      .trim(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  color: cs.onSurfaceVariant,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _TypeBadge(type: server.type),
                    if (server.currentVersion != null)
                      _VersionBadge(version: server.currentVersion!),
                    ...server.clients.map((c) => _ClientBadge(client: c)),
                    if (server.alwaysAllow.isNotEmpty)
                      _MetaBadge(
                        icon: Icons.verified_user_outlined,
                        label: '${server.alwaysAllow.length} 個自動核准',
                      ),
                    if (server.env.isNotEmpty || server.headers.isNotEmpty)
                      _MetaBadge(
                        icon: Icons.key_outlined,
                        label:
                            '${server.env.length + server.headers.length} 個敏感值',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientBadge extends StatelessWidget {
  final AiClientType client;

  const _ClientBadge({required this.client});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: client.displayName,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(client.icon, size: 15, color: cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            Text(
              client.displayName,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─── Quick update button ─────────────────────────────────────────────────────

class _QuickUpdateButton extends ConsumerWidget {
  final McpServer server;
  final String latestVersion;
  const _QuickUpdateButton({required this.server, required this.latestVersion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: '可更新至 $latestVersion，點擊立即更新',
      child: TextButton.icon(
        style: TextButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(44, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
        onPressed: () => showUpdateDialog(context, ref, server, latestVersion),
        icon: const Icon(Icons.system_update_alt, size: 16),
        label: Text(
          '↑ $latestVersion',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _DisabledBadge extends StatelessWidget {
  const _DisabledBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        '停用',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  final McpType type;
  const _TypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (type) {
      case McpType.npm:
        icon = Icons.inventory_2_outlined;
        color = const Color(0xFFCB3837);
        break;
      case McpType.python:
        icon = Icons.code_outlined;
        color = const Color(0xFF3572A5);
        break;
      case McpType.github:
        icon = Icons.source_outlined;
        color = const Color(0xFF6E40C9);
        break;
      case McpType.sse:
        icon = Icons.http_outlined;
        color = const Color(0xFF00897B);
        break;
      case McpType.unknown:
        icon = Icons.extension_outlined;
        color = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final McpType type;
  const _TypeBadge({required this.type});

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
        type.label,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  final String version;
  const _VersionBadge({required this.version});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        'v$version',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
