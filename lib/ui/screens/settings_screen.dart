import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ai_client.dart';
import '../../providers/ai_clients_provider.dart';
import '../../providers/mcp_list_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(aiClientsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (clients) {
          final builtIn = clients
              .where((c) => c.type != AiClientType.custom)
              .toList();
          final customs = clients
              .where((c) => c.type == AiClientType.custom)
              .toList();

          return ListView(
            children: [
              const _SectionHeader('AI 用戶端'),
              ...builtIn.map((client) => SwitchListTile(
                    secondary: Icon(client.type.icon),
                    title: Text(client.name),
                    subtitle: Text(
                      client.configPath,
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: client.isEnabled,
                    onChanged: (_) {
                      ref
                          .read(aiClientsNotifier)
                          .toggleClient(client);
                    },
                  )),
              const Divider(),
              const _SectionHeader('自訂設定路徑'),
              ...customs.map((client) => ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: Text(client.configPath),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '移除',
                      onPressed: () {
                        ref
                            .read(aiClientsNotifier)
                            .removeCustomPath(client.configPath);
                        ref.invalidate(mcpListProvider);
                      },
                    ),
                  )),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('新增自訂設定路徑'),
                onTap: () => _showAddPathDialog(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPathDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新增自訂設定路徑'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: r'C:\path\to\mcp_config.json',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            _addPath(context, ref, val);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _addPath(context, ref, controller.text),
            child: const Text('新增'),
          ),
        ],
      ),
    );
  }

  void _addPath(BuildContext context, WidgetRef ref, String path) {
    if (path.trim().isEmpty) return;
    ref.read(aiClientsNotifier).addCustomPath(path.trim());
    ref.invalidate(mcpListProvider);
    Navigator.pop(context);
  }
}

final aiClientsNotifier = Provider<AiClientsNotifier>((ref) {
  return ref.watch(aiClientsProvider.notifier);
});

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
