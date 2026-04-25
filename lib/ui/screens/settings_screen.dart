import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ai_client.dart';
import '../../providers/ai_clients_provider.dart';
import '../../providers/mcp_list_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(aiClientsProvider);
    final themeSettings = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (clients) {
          final builtIn =
              clients.where((c) => c.type != AiClientType.custom).toList();
          final customs =
              clients.where((c) => c.type == AiClientType.custom).toList();

          return ListView(
            children: [
              // ── Appearance ───────────────────────────────────────────────
              const _SectionHeader('外觀'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('主題模式',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('跟隨系統'),
                            icon: Icon(Icons.brightness_auto_outlined)),
                        ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('淺色'),
                            icon: Icon(Icons.light_mode_outlined)),
                        ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('深色'),
                            icon: Icon(Icons.dark_mode_outlined)),
                      ],
                      selected: {themeSettings.mode},
                      onSelectionChanged: (s) =>
                          themeNotifier.setMode(s.first),
                    ),
                    const SizedBox(height: 16),
                    Text('主題色',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: kAccentOptions.map((option) {
                        final selected =
                            themeSettings.accent.toARGB32() == option.color.toARGB32();
                        return Tooltip(
                          message: option.label,
                          child: GestureDetector(
                            onTap: () => themeNotifier.setAccent(option.color),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: option.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? cs.onSurface
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color:
                                              option.color.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: selected
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // ── AI Clients ───────────────────────────────────────────────
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
                      ref.read(aiClientsNotifier).toggleClient(client);
                    },
                  )),
              const Divider(),

              // ── Custom paths ─────────────────────────────────────────────
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
