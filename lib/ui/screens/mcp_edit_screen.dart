import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/mcp_server.dart';
import '../../models/mcp_type.dart';
import '../../providers/ai_clients_provider.dart';
import '../../providers/mcp_list_provider.dart';
import '../../services/config_parser_service.dart';

class McpEditScreen extends ConsumerStatefulWidget {
  final McpServer server;
  const McpEditScreen({super.key, required this.server});

  @override
  ConsumerState<McpEditScreen> createState() => _McpEditScreenState();
}

class _McpEditScreenState extends ConsumerState<McpEditScreen> {
  late final TextEditingController _nameCtrl;

  // SSE
  late final TextEditingController _urlCtrl;
  late List<_KVEntry> _headerEntries;

  // stdio
  late final TextEditingController _commandCtrl;
  late List<TextEditingController> _argCtrl;
  late List<_KVEntry> _envEntries;

  // Common
  late final TextEditingController _timeoutCtrl;
  late List<TextEditingController> _alwaysAllowCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.server;
    _nameCtrl = TextEditingController(text: s.name);
    _urlCtrl = TextEditingController(text: s.url ?? '');
    _headerEntries = s.headers.entries
        .map((e) => _KVEntry(e.key, e.value))
        .toList();
    _commandCtrl = TextEditingController(text: s.command);
    _argCtrl = s.args.map((a) => TextEditingController(text: a)).toList();
    _envEntries = s.env.entries
        .map((e) => _KVEntry(e.key, e.value))
        .toList();
    _timeoutCtrl = TextEditingController(text: s.timeout?.toString() ?? '');
    _alwaysAllowCtrl =
        s.alwaysAllow.map((a) => TextEditingController(text: a)).toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    for (final e in _headerEntries) { e.dispose(); }
    _commandCtrl.dispose();
    for (final c in _argCtrl) { c.dispose(); }
    for (final e in _envEntries) { e.dispose(); }
    _timeoutCtrl.dispose();
    for (final c in _alwaysAllowCtrl) { c.dispose(); }
    super.dispose();
  }

  McpServer _buildUpdated() {
    final isSSE = widget.server.type == McpType.sse;
    return widget.server.copyWith(
      name: _nameCtrl.text.trim(),
      url: isSSE ? _urlCtrl.text.trim() : null,
      headers: isSSE
          ? Map.fromEntries(
              _headerEntries
                  .map((e) => MapEntry(e.keyText, e.valueText))
                  .where((e) => e.key.isNotEmpty),
            )
          : const {},
      command: !isSSE ? _commandCtrl.text.trim() : '',
      args: !isSSE
          ? _argCtrl.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList()
          : const [],
      env: !isSSE
          ? Map.fromEntries(
              _envEntries
                  .map((e) => MapEntry(e.keyText, e.valueText))
                  .where((e) => e.key.isNotEmpty),
            )
          : const {},
      timeout: _timeoutCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_timeoutCtrl.text.trim()),
      alwaysAllow: _alwaysAllowCtrl
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('名稱不可為空')));
      return;
    }
    setState(() => _saving = true);

    final updated = _buildUpdated();
    final parser = ConfigParserService();
    final clients = await ref.read(aiClientsProvider.future);

    for (final client in clients) {
      if (widget.server.clients.contains(client.type)) {
        await parser.updateServerConfig(
          configPath: client.configPath,
          oldName: widget.server.name,
          server: updated,
        );
      }
    }

    ref.invalidate(mcpListProvider);

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isSSE = widget.server.type == McpType.sse;
    return Scaffold(
      appBar: AppBar(
        title: Text('編輯 ${widget.server.name}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('儲存'),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Name ──────────────────────────────────────────────────────────
          _EditSection(
            title: '基本資訊',
            child: TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '名稱',
                border: OutlineInputBorder(),
                helperText: '此 MCP 在設定檔中的識別鍵名',
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Transport ────────────────────────────────────────────────────
          if (isSSE) ...[
            _EditSection(
              title: '傳輸設定（HTTP/SSE）',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: '端點 URL',
                      border: OutlineInputBorder(),
                      hintText: 'http://localhost:3000/sse',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _KVListEditor(
                    label: 'HTTP 標頭',
                    entries: _headerEntries,
                    keyHint: 'Authorization',
                    valueHint: 'Bearer token…',
                    onAdd: () => setState(
                        () => _headerEntries.add(_KVEntry('', ''))),
                    onRemove: (i) => setState(() {
                      _headerEntries[i].dispose();
                      _headerEntries.removeAt(i);
                    }),
                    onChanged: () => setState(() {}),
                  ),
                ],
              ),
            ),
          ] else ...[
            _EditSection(
              title: '指令（stdio）',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _commandCtrl,
                    decoration: const InputDecoration(
                      labelText: '執行指令',
                      border: OutlineInputBorder(),
                      hintText: 'npx / uvx / node …',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StringListEditor(
                    label: '參數 (args)',
                    controllers: _argCtrl,
                    hint: '-y @modelcontextprotocol/server-xxx',
                    onAdd: () => setState(
                        () => _argCtrl.add(TextEditingController())),
                    onRemove: (i) => setState(() {
                      _argCtrl[i].dispose();
                      _argCtrl.removeAt(i);
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _EditSection(
              title: '環境變數',
              child: _KVListEditor(
                label: null,
                entries: _envEntries,
                keyHint: 'API_KEY',
                valueHint: '環境變數值',
                onAdd: () => setState(() => _envEntries.add(_KVEntry('', ''))),
                onRemove: (i) => setState(() {
                  _envEntries[i].dispose();
                  _envEntries.removeAt(i);
                }),
                onChanged: () => setState(() {}),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Advanced ─────────────────────────────────────────────────────
          _EditSection(
            title: '進階選項',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _timeoutCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '逾時 (ms)',
                    border: OutlineInputBorder(),
                    hintText: '5000',
                    helperText: '留空表示不設定',
                  ),
                ),
                const SizedBox(height: 16),
                _StringListEditor(
                  label: '自動核准工具 (alwaysAllow)',
                  controllers: _alwaysAllowCtrl,
                  hint: 'tool_name',
                  onAdd: () => setState(
                      () => _alwaysAllowCtrl.add(TextEditingController())),
                  onRemove: (i) => setState(() {
                    _alwaysAllowCtrl[i].dispose();
                    _alwaysAllowCtrl.removeAt(i);
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Entry model ─────────────────────────────────────────────────────────────

class _KVEntry {
  final TextEditingController key;
  final TextEditingController value;

  _KVEntry(String k, String v)
      : key = TextEditingController(text: k),
        value = TextEditingController(text: v);

  String get keyText => key.text;
  String get valueText => value.text;

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

// ─── Section wrapper ─────────────────────────────────────────────────────────

class _EditSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _EditSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── KV list editor ──────────────────────────────────────────────────────────

class _KVListEditor extends StatelessWidget {
  final String? label;
  final List<_KVEntry> entries;
  final String keyHint;
  final String valueHint;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final VoidCallback onChanged;

  const _KVListEditor({
    required this.label,
    required this.entries,
    required this.keyHint,
    required this.valueHint,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
        ],
        ...List.generate(entries.length, (i) {
          final e = entries[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: e.key,
                    decoration: InputDecoration(
                      hintText: keyHint,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: e.value,
                    decoration: InputDecoration(
                      hintText: valueHint,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => onRemove(i),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: '移除',
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('新增'),
        ),
      ],
    );
  }
}

// ─── String list editor ──────────────────────────────────────────────────────

class _StringListEditor extends StatelessWidget {
  final String label;
  final List<TextEditingController> controllers;
  final String hint;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _StringListEditor({
    required this.label,
    required this.controllers,
    required this.hint,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ...List.generate(controllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controllers[i],
                    decoration: InputDecoration(
                      hintText: hint,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      prefixText: '[${i + 1}]  ',
                      prefixStyle: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontFamily: 'monospace'),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => onRemove(i),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: '移除',
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('新增'),
        ),
      ],
    );
  }
}
