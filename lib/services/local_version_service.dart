import 'dart:convert';
import 'dart:io';

import '../models/mcp_server.dart';
import '../models/mcp_type.dart';

/// Queries the local system to find the installed version of an MCP package.
/// Results are cached per process lifetime to avoid repeated slow CLI calls.
class LocalVersionService {
  LocalVersionService._();

  // Cache: npm global packages  (pkg → version)
  static Map<String, String>? _npmCache;
  // Cache: uv tool list         (pkg → version)
  static Map<String, String>? _uvCache;

  /// Returns the locally installed version for [server], or null if unknown.
  static Future<String?> detect(McpServer server) async {
    if (server.packageName == null) return null;
    switch (server.type) {
      case McpType.npm:
        return _detectNpm(server.packageName!);
      case McpType.python:
        final cmd = server.command.toLowerCase();
        if (cmd == 'uvx' || cmd == 'uv') {
          return _detectUvTool(server.packageName!);
        }
        return _detectPip(server.packageName!);
      case McpType.github:
      case McpType.sse:
      case McpType.unknown:
        return null;
    }
  }

  // ── npm ──────────────────────────────────────────────────────────────────

  static Future<String?> _detectNpm(String pkg) async {
    _npmCache ??= await _loadNpmGlobalPackages();
    return _npmCache![pkg] ?? _npmCache![pkg.toLowerCase()];
  }

  static Future<Map<String, String>> _loadNpmGlobalPackages() async {
    try {
      final result = await Process.run(
        'npm',
        ['list', '-g', '--json', '--depth=0'],
        runInShell: true,
      );
      if (result.exitCode != 0) return {};
      final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final deps = data['dependencies'] as Map<String, dynamic>? ?? {};
      return {
        for (final e in deps.entries)
          e.key: (e.value as Map<String, dynamic>)['version'] as String? ?? '',
      };
    } catch (_) {
      return {};
    }
  }

  // ── uv tool ──────────────────────────────────────────────────────────────

  static Future<String?> _detectUvTool(String pkg) async {
    _uvCache ??= await _loadUvToolList();
    final key = pkg.toLowerCase();
    return _uvCache![key] ?? _uvCache![key.replaceAll('-', '_')];
  }

  static Future<Map<String, String>> _loadUvToolList() async {
    try {
      final result = await Process.run(
        'uv',
        ['tool', 'list'],
        runInShell: true,
      );
      if (result.exitCode != 0) return {};
      final map = <String, String>{};
      // Each tool appears as:  "pkg-name v1.2.3"
      // Entrypoints appear as: "  - entrypoint"  (indented, skip)
      final lineRe = RegExp(r'^([\w][\w.-]*)\s+v?([\d][\d.a-zA-Z-]*)');
      for (final raw in (result.stdout as String).split('\n')) {
        final line = raw.trim();
        if (line.startsWith('-')) continue; // entrypoint line
        final m = lineRe.firstMatch(line);
        if (m != null) {
          map[m.group(1)!.toLowerCase()] = m.group(2)!;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  // ── pip ──────────────────────────────────────────────────────────────────

  static Future<String?> _detectPip(String pkg) async {
    try {
      final result = await Process.run(
        'pip',
        ['show', pkg],
        runInShell: true,
      );
      if (result.exitCode != 0) return null;
      for (final line in (result.stdout as String).split('\n')) {
        if (line.startsWith('Version:')) {
          return line.substring('Version:'.length).trim();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Clears all caches (call when user triggers a manual refresh).
  static void clearCache() {
    _npmCache = null;
    _uvCache = null;
  }
}
