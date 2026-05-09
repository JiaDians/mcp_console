import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
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
          final builtIn = clients
              .where((c) => c.type != AiClientType.custom)
              .toList();
          final customs = clients
              .where((c) => c.type == AiClientType.custom)
              .toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding =
                  constraints.maxWidth >= AppBreakpoints.wide
                  ? 64.0
                  : AppSpacing.lg;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AppSpacing.xl,
                  horizontalPadding,
                  AppSpacing.xxl,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SettingsSection(
                            title: '外觀',
                            icon: Icons.palette_outlined,
                            description: '調整 MCP Console 的主題模式與強調色。',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '主題模式',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                SegmentedButton<ThemeMode>(
                                  segments: const [
                                    ButtonSegment(
                                      value: ThemeMode.system,
                                      label: Text('跟隨系統'),
                                      icon: Icon(
                                        Icons.brightness_auto_outlined,
                                      ),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.light,
                                      label: Text('淺色'),
                                      icon: Icon(Icons.light_mode_outlined),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.dark,
                                      label: Text('深色'),
                                      icon: Icon(Icons.dark_mode_outlined),
                                    ),
                                  ],
                                  selected: {themeSettings.mode},
                                  onSelectionChanged: (s) =>
                                      themeNotifier.setMode(s.first),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  '主題色',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: kAccentOptions.map((option) {
                                    final selected =
                                        themeSettings.accent.toARGB32() ==
                                        option.color.toARGB32();
                                    return _AccentSwatch(
                                      option: option,
                                      selected: selected,
                                      onTap: () =>
                                          themeNotifier.setAccent(option.color),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SettingsSection(
                            title: 'AI 用戶端',
                            icon: Icons.desktop_windows_outlined,
                            description: '停用不需要讀取的用戶端可降低清單雜訊。',
                            child: Column(
                              children: builtIn
                                  .map(
                                    (client) => SwitchListTile(
                                      secondary: Icon(client.type.icon),
                                      title: Text(client.name),
                                      subtitle: Text(
                                        client.configPath,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                      value: client.isEnabled,
                                      onChanged: (_) {
                                        ref
                                            .read(aiClientsNotifier)
                                            .toggleClient(client);
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SettingsSection(
                            title: '自訂設定路徑',
                            icon: Icons.folder_open_outlined,
                            description: '加入其他 MCP 設定檔，或移除不再使用的路徑。',
                            child: Column(
                              children: [
                                ...customs.map(
                                  (client) => ListTile(
                                    leading: const Icon(Icons.folder_open),
                                    title: Text(client.configPath),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: '移除',
                                      onPressed: () {
                                        ref
                                            .read(aiClientsNotifier)
                                            .removeCustomPath(
                                              client.configPath,
                                            );
                                        ref.invalidate(mcpListProvider);
                                      },
                                    ),
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.add),
                                  title: const Text('新增自訂設定路徑'),
                                  subtitle: const Text(
                                    '支援任意 mcp_config.json 檔案',
                                  ),
                                  onTap: () => _showAddPathDialog(context, ref),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
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

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.description,
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
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(description, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  final AccentOption option;
  final bool selected;
  final VoidCallback onTap;

  const _AccentSwatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: option.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: '主題色 ${option.label}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: option.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? cs.onSurface : cs.outlineVariant,
                width: selected ? 3 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: option.color.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}
