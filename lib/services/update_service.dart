import 'dart:io';

import '../models/mcp_server.dart';
import '../models/mcp_type.dart';
import '../core/utils/process_runner.dart';
import 'config_parser_service.dart';

enum UpdateStatus { idle, running, success, failed }

class UpdateResult {
  final bool success;
  final List<String> log;
  final String? errorMessage;

  const UpdateResult({
    required this.success,
    required this.log,
    this.errorMessage,
  });
}

/// Executes update commands for an MCP server and rewrites config version.
class UpdateService {
  final ConfigParserService _configParser;

  UpdateService({ConfigParserService? configParser})
      : _configParser = configParser ?? ConfigParserService();

  /// Returns a stream of log lines while updating [server].
  /// After a successful update, rewrites [configPath] version to [newVersion].
  Stream<String> update({
    required McpServer server,
    required String newVersion,
    required List<String> configPaths,
  }) async* {
    yield '▶ Starting update for ${server.name} → $newVersion';

    try {
      switch (server.type) {
        case McpType.npm:
          yield* _updateNpm(server, newVersion);
          break;
        case McpType.python:
          yield* _updatePython(server, newVersion);
          break;
        case McpType.github:
          yield* _updateGithub(server);
          break;
        case McpType.sse:
          yield 'ℹ HTTP/SSE server — managed independently, not via package manager.';
          yield '  No update action taken.';
          return; // Do NOT touch config
        case McpType.unknown:
          yield '⚠ Unknown MCP type — cannot update automatically.';
          return;
      }

      // Rewrite version in all config files where this MCP is present
      yield '';
      yield '✎ Updating version in config files…';
      for (final path in configPaths) {
        await _configParser.updateVersionInConfig(
          configPath: path,
          mcpName: server.name,
          newVersion: newVersion,
        );
        yield '  ✔ $path';
      }

      yield '';
      yield '✅ Update complete.';
    } catch (e) {
      yield '';
      yield '❌ Update failed: $e';
      rethrow;
    }
  }

  Stream<String> _updateNpm(McpServer server, String newVersion) async* {
    final pkg = server.packageName;
    if (pkg == null) {
      yield '⚠ Cannot detect npm package name.';
      return;
    }
    yield '\$ npm install -g $pkg@$newVersion';
    yield* ProcessRunner.stream('npm', ['install', '-g', '$pkg@$newVersion']);
  }

  Stream<String> _updatePython(McpServer server, String newVersion) async* {
    final pkg = server.packageName;
    if (pkg == null) {
      yield '⚠ Cannot detect Python package name.';
      return;
    }

    final command = server.command.toLowerCase();
    if (command == 'uvx' || command == 'uv') {
      yield '\$ uv tool upgrade $pkg';
      yield* ProcessRunner.stream('uv', ['tool', 'upgrade', pkg]);
    } else {
      yield '\$ pip install --upgrade $pkg==$newVersion';
      yield* ProcessRunner.stream(
        'pip',
        ['install', '--upgrade', '$pkg==$newVersion'],
      );
    }
  }

  Stream<String> _updateGithub(McpServer server) async* {
    final repo = server.githubRepo;
    if (repo == null) {
      yield '⚠ Cannot detect GitHub repo. Please update manually.';
      return;
    }

    // Attempt git pull if a local path is detected in args
    final localPath = _findLocalGitPath(server.args);
    if (localPath != null && await Directory(localPath).exists()) {
      yield '\$ git -C "$localPath" pull';
      yield* ProcessRunner.stream('git', ['-C', localPath, 'pull']);
    } else {
      yield 'ℹ No local clone detected.';
      yield '  Open the release page to download the latest version:';
      yield '  https://github.com/$repo/releases/latest';
    }
  }

  String? _findLocalGitPath(List<String> args) {
    for (final arg in args) {
      if (arg.contains(Platform.pathSeparator) ||
          (arg.contains('/') && !arg.contains('github.com'))) {
        final d = Directory(arg);
        if (d.existsSync()) return arg;
      }
    }
    return null;
  }
}
