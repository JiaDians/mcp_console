import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => McpDetailScreen(server: server),
            ),
          );
        },
        child: Opacity(
          opacity: server.disabled ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TypeIcon(type: server.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              server.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (server.disabled)
                            _DisabledBadge()
                          else if (versionAsync != null)
                            versionAsync.when(
                              data: (result) {
                                // Show quick-update button when update available
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
                      const SizedBox(height: 4),
                      Text(
                        server.type == McpType.sse
                            ? server.url ?? '(no URL)'
                            : '${server.command} ${server.args.join(' ')}'.trim(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _TypeBadge(type: server.type),
                          const SizedBox(width: 8),
                          if (server.currentVersion != null)
                            _VersionBadge(version: server.currentVersion!),
                          const Spacer(),
                          ..._clientBadges(context, server.clients),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _clientBadges(
      BuildContext context, List<AiClientType> clients) {
    return clients.map((c) {
      return Tooltip(
        message: c.displayName,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(c.icon, size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }).toList();
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
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
