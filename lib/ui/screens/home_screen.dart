import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../models/ai_client.dart';
import '../../models/mcp_server.dart';
import '../../models/mcp_type.dart';
import '../../providers/ai_clients_provider.dart';
import '../../providers/mcp_list_provider.dart';
import '../widgets/client_filter_chips.dart';
import '../widgets/mcp_card.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredMcpListProvider);
    final allAsync = ref.watch(mcpListProvider);
    final clientsAsync = ref.watch(aiClientsProvider);
    final selectedFilter = ref.watch(clientFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新整理',
            onPressed: () {
              ref.invalidate(mcpListProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= AppBreakpoints.wide;
          final dashboard = _DashboardPanel(
            allAsync: allAsync,
            clientsAsync: clientsAsync,
            selectedFilter: selectedFilter,
          );
          final list = _ServerList(filteredAsync: filteredAsync);

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 340,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: dashboard,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: list),
              ],
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: dashboard,
              ),
              const Divider(height: 1),
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  final AsyncValue<List<McpServer>> allAsync;
  final AsyncValue<List<AiClient>> clientsAsync;
  final AiClientType? selectedFilter;

  const _DashboardPanel({
    required this.allAsync,
    required this.clientsAsync,
    required this.selectedFilter,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                      child: Icon(
                        Icons.hub_outlined,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MCP 管理中樞',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            selectedFilter == null
                                ? '總覽所有已啟用用戶端的 MCP'
                                : '目前篩選：${selectedFilter!.displayName}',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                allAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => _InlineState(
                    icon: Icons.error_outline,
                    text: '無法讀取摘要',
                    color: cs.error,
                  ),
                  data: (servers) => clientsAsync.when(
                    loading: () =>
                        _SummaryGrid(items: _summaryItems(servers, const [])),
                    error: (_, __) =>
                        _SummaryGrid(items: _summaryItems(servers, const [])),
                    data: (clients) =>
                        _SummaryGrid(items: _summaryItems(servers, clients)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('篩選用戶端', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        const ClientFilterChips(),
      ],
    );
  }

  List<_SummaryItem> _summaryItems(
    List<McpServer> servers,
    List<AiClient> clients,
  ) {
    return [
      _SummaryItem(
        label: 'MCP 總數',
        value: servers.length.toString(),
        icon: Icons.extension_outlined,
      ),
      _SummaryItem(
        label: '啟用用戶端',
        value: clients.where((c) => c.isEnabled).length.toString(),
        icon: Icons.desktop_windows_outlined,
      ),
      _SummaryItem(
        label: '停用項目',
        value: servers.where((s) => s.disabled).length.toString(),
        icon: Icons.block,
      ),
      _SummaryItem(
        label: 'HTTP/SSE',
        value: servers.where((s) => s.type == McpType.sse).length.toString(),
        icon: Icons.http_outlined,
      ),
    ];
  }
}

class _SummaryGrid extends StatelessWidget {
  final List<_SummaryItem> items;

  const _SummaryGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items.map((item) => _SummaryTile(item: item)).toList(),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final _SummaryItem item;

  const _SummaryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 136,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 18, color: cs.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(item.label, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _ServerList extends StatelessWidget {
  final AsyncValue<List<McpServer>> filteredAsync;

  const _ServerList({required this.filteredAsync});

  @override
  Widget build(BuildContext context) {
    return filteredAsync.when(
      loading: () => const _LoadingState(),
      error: (e, _) => _ErrorState(error: e),
      data: (servers) {
        if (servers.isEmpty) {
          return const _EmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            96,
          ),
          itemCount: servers.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: McpCard(server: servers[i]),
          ),
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '正在讀取 MCP 設定…',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  final Object error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                '載入 MCP 伺服器時發生錯誤',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonalIcon(
                onPressed: () => ref.invalidate(mcpListProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('重試'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 56, color: cs.onSurfaceVariant),
              const SizedBox(height: AppSpacing.md),
              Text(
                '找不到 MCP 伺服器',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '請確認 AI 用戶端已設定 MCP，或在設定中新增自訂設定路徑。',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('開啟設定'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InlineState({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(text, style: TextStyle(color: color)),
      ],
    );
  }
}
