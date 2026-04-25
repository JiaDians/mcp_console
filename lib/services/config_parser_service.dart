import 'dart:convert';
import 'dart:io';

import '../models/ai_client.dart';
import '../models/mcp_server.dart';
import '../models/mcp_type.dart';
import '../core/utils/version_utils.dart';

/// Reads and writes MCP config JSON files.
class ConfigParserService {
  /// Reads all MCP servers from a config file and returns them tagged with [clientType].
  /// Returns an empty list if the file does not exist or cannot be parsed.
  Future<List<McpServer>> readConfig(
    String configPath,
    AiClientType clientType,
  ) async {
    final file = File(configPath);
    if (!await file.exists()) return [];

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final servers = json['mcpServers'] as Map<String, dynamic>?;
      if (servers == null) return [];

      return servers.entries.map((entry) {
        final data = entry.value as Map<String, dynamic>;
        return _parseServerEntry(entry.key, data, clientType);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  McpServer _parseServerEntry(
    String name,
    Map<String, dynamic> data,
    AiClientType clientType,
  ) {
    // ── Shared optional fields (all transport types) ─────────────────────────
    final disabled = (data['disabled'] as bool?) ?? false;
    final timeout = _parseInt(data['timeout']);
    final env = _parseStringMap(data['env']);
    final headers = _parseStringMap(data['headers']);
    // alwaysAllow and autoApprove are aliases — merge both
    final alwaysAllow = <String>{
      ..._parseStringList(data['alwaysAllow']),
      ..._parseStringList(data['autoApprove']),
    }.toList();

    // ── Determine transport type ─────────────────────────────────────────────
    // Explicit "type" field takes priority (some clients set this)
    final explicitType = (data['type'] as String?)?.toLowerCase();
    final url = data['url'] as String?;

    final bool isHttpTransport = explicitType == 'sse' ||
        explicitType == 'http' ||
        explicitType == 'streamable-http' ||
        (explicitType == null && url != null);

    if (isHttpTransport) {
      return McpServer(
        name: name,
        command: '',
        args: const [],
        env: env,
        headers: headers,
        type: McpType.sse,
        clients: [clientType],
        url: url,
        disabled: disabled,
        timeout: timeout,
        alwaysAllow: alwaysAllow,
      );
    }

    // ── stdio transport ──────────────────────────────────────────────────────
    final command = (data['command'] as String?) ?? '';
    final args = _parseStringList(data['args']);

    return _buildMcpServer(
      name: name,
      command: command,
      args: args,
      env: env,
      headers: headers,
      clientType: clientType,
      disabled: disabled,
      timeout: timeout,
      alwaysAllow: alwaysAllow,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, String> _parseStringMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((k, v) => MapEntry(k, v.toString()));
    }
    return {};
  }

  List<String> _parseStringList(dynamic value) {
    if (value is List<dynamic>) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────

  /// Merges a list of per-client server lists into a deduplicated list.
  /// Servers with the same name are merged (their client lists combined).
  List<McpServer> mergeServers(List<McpServer> allServers) {
    final map = <String, McpServer>{};
    for (final server in allServers) {
      if (map.containsKey(server.name)) {
        final existing = map[server.name]!;
        final merged = existing.copyWith(
          clients: [
            ...existing.clients,
            ...server.clients.where((c) => !existing.clients.contains(c)),
          ],
        );
        map[server.name] = merged;
      } else {
        map[server.name] = server;
      }
    }
    return map.values.toList();
  }

  /// Updates the version of a specific package in the args of an MCP entry
  /// within a config file.
  Future<void> updateVersionInConfig({
    required String configPath,
    required String mcpName,
    required String newVersion,
  }) async {
    final file = File(configPath);
    if (!await file.exists()) return;

    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final servers = json['mcpServers'] as Map<String, dynamic>?;
    if (servers == null || !servers.containsKey(mcpName)) return;

    final serverData = servers[mcpName] as Map<String, dynamic>;
    final args = (serverData['args'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();
    if (args == null) return;

    final updated = args.map((arg) {
      // Replace @old-version with @new-version in package args
      return arg.replaceAllMapped(
        RegExp(r'(@[\w.-]+/[\w.-]+|[\w.-]+)@[\d.]+\w*'),
        (m) {
          final pkg = m.group(1)!;
          return '$pkg@$newVersion';
        },
      );
    }).toList();

    serverData['args'] = updated;
    servers[mcpName] = serverData;
    json['mcpServers'] = servers;

    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(json));
  }

  /// Removes an MCP server entry from a config file.
  Future<void> removeServerFromConfig({
    required String configPath,
    required String mcpName,
  }) async {
    final file = File(configPath);
    if (!await file.exists()) return;

    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final servers = json['mcpServers'] as Map<String, dynamic>?;
    if (servers == null || !servers.containsKey(mcpName)) return;

    servers.remove(mcpName);
    json['mcpServers'] = servers;

    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(json));
  }


  McpServer _buildMcpServer({
    required String name,
    required String command,
    required List<String> args,
    required Map<String, String> env,
    required Map<String, String> headers,
    required AiClientType clientType,
    required bool disabled,
    required int? timeout,
    required List<String> alwaysAllow,
  }) {
    final type = _detectType(command, args);
    final cmd = command.toLowerCase().split(RegExp(r'[/\\]')).last.replaceAll('.exe', '');
    String? packageName;
    String? currentVersion;
    String? githubRepo;

    switch (type) {
      case McpType.npm:
        final npmInfo = VersionUtils.extractNpmPackage(args);
        packageName = npmInfo.name;
        currentVersion = npmInfo.version;
        break;
      case McpType.python:
        final pyInfo = VersionUtils.extractPythonPackage(args, cmd);
        packageName = pyInfo.name;
        currentVersion = pyInfo.version;
        break;
      case McpType.github:
        githubRepo = VersionUtils.extractGithubRepo(args);
        break;
      case McpType.sse:
      case McpType.unknown:
        break;
    }

    return McpServer(
      name: name,
      command: command,
      args: args,
      env: env,
      headers: headers,
      type: type,
      clients: [clientType],
      currentVersion: currentVersion,
      packageName: packageName,
      githubRepo: githubRepo,
      disabled: disabled,
      timeout: timeout,
      alwaysAllow: alwaysAllow,
    );
  }

  McpType _detectType(String command, List<String> args) {
    // command may be a full path like C:\...\uvx.exe — use only the basename
    final cmd = command.toLowerCase().split(RegExp(r'[/\\]')).last.replaceAll('.exe', '');

    if (cmd == 'npx' || cmd == 'node' || cmd == 'npm') {
      return McpType.npm;
    }
    if (cmd == 'uvx' || cmd == 'uv' || cmd == 'python' ||
        cmd == 'python3' || cmd == 'pip' || cmd == 'pip3') {
      return McpType.python;
    }
    // dotnet apps may ship on NuGet or GitHub — try GitHub detection from args
    if (cmd == 'dotnet') {
      return VersionUtils.extractGithubRepo(args) != null
          ? McpType.github
          : McpType.unknown;
    }
    // cmd /c or powershell: look for a real executable inside the args
    if (cmd == 'cmd' || cmd == 'powershell' || cmd == 'pwsh') {
      return _detectType(args.firstWhere(
        (a) => !a.startsWith('/') && !a.startsWith('-') && a.isNotEmpty,
        orElse: () => '',
      ), args);
    }
    // Command is itself a direct executable path (.exe / .bat / .sh / etc.)
    if (command.contains(RegExp(r'[/\\]')) ||
        command.endsWith('.exe') ||
        command.endsWith('.bat') ||
        command.endsWith('.sh')) {
      // Try GitHub detection from args as a last resort
      if (VersionUtils.extractGithubRepo(args) != null) return McpType.github;
      return McpType.unknown;
    }
    if (VersionUtils.extractGithubRepo(args) != null) {
      return McpType.github;
    }
    return McpType.unknown;
  }
}
