import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/mcp_list_provider.dart';
import '../widgets/client_filter_chips.dart';
import '../widgets/mcp_card.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredMcpListProvider);

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
      body: Column(
        children: [
          const ClientFilterChips(),
          const Divider(height: 1),
          Expanded(
            child: filteredAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text('載入 MCP 伺服器時發生錯誤\n$e',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(mcpListProvider),
                      child: const Text('重試'),
                    ),
                  ],
                ),
              ),
              data: (servers) {
                if (servers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inbox_outlined,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('找不到 MCP 伺服器'),
                        const SizedBox(height: 4),
                        Text(
                          '請確認 AI 用戶端已設定 MCP，\n或在設定中新增自訂設定路徑。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()),
                          ),
                          child: const Text('開啟設定'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: servers.length,
                  itemBuilder: (_, i) => McpCard(server: servers[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
