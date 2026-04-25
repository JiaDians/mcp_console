import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/mcp_server.dart';
import '../models/mcp_type.dart';
import '../models/version_check_result.dart';
import '../core/utils/version_utils.dart';
import 'local_version_service.dart';

/// Checks the latest version of an MCP server from npm, PyPI, or GitHub.
class VersionCheckService {
  final http.Client _client;

  VersionCheckService({http.Client? client})
      : _client = client ?? http.Client();

  Future<VersionCheckResult> check(McpServer server) async {
    // Disabled servers: skip network check entirely
    if (server.disabled) {
      return VersionCheckResult.error(server.name, 'disabled');
    }

    // Always try local detection — it's the ground truth of what's installed.
    // Falls back to config version if local detection returns nothing.
    final local = await LocalVersionService.detect(server);
    if (local != null) {
      server = server.copyWith(currentVersion: local);
    }

    switch (server.type) {
      case McpType.npm:
        return _checkNpm(server);
      case McpType.python:
        return _checkPypi(server);
      case McpType.github:
        return _checkGithub(server);
      case McpType.sse:
        return _checkConnectivity(server);
      case McpType.unknown:
        return VersionCheckResult.error(
          server.name,
          'Local binary or unsupported type — version check not available',
        );
    }
  }

  /// Probes the HTTP/SSE server URL to check if it's reachable.
  /// Uses the server's configured headers and timeout.
  Future<VersionCheckResult> _checkConnectivity(McpServer server) async {
    final url = server.url;
    if (url == null || url.isEmpty) {
      return VersionCheckResult.error(server.name, 'No URL configured for HTTP/SSE server');
    }
    try {
      final uri = Uri.parse(url);
      // Use configured timeout (clamped 1–15 s) or default 5 s
      final timeoutMs = (server.timeout ?? 5000).clamp(1000, 15000);
      final headers = <String, String>{
        'Accept': 'application/json, text/event-stream',
        ...server.headers,
      };
      final response = await _client
          .get(uri, headers: headers)
          .timeout(Duration(milliseconds: timeoutMs));
      // 401/403/405/406 means the server IS running but needs auth / different method
      final reachable = response.statusCode < 500;
      return VersionCheckResult.connectivity(
        server.name,
        isOnline: reachable,
        url: url,
      );
    } catch (_) {
      return VersionCheckResult.connectivity(
        server.name,
        isOnline: false,
        url: url,
      );
    }
  }

  Future<VersionCheckResult> _checkNpm(McpServer server) async {
    final pkg = server.packageName;
    if (pkg == null) {
      return VersionCheckResult.error(server.name, 'Could not detect npm package name');
    }
    try {
      final uri = Uri.parse('https://registry.npmjs.org/$pkg/latest');
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 404) {
        // Fallback chain for scoped packages that may live on GitHub only.
        // @scope/pkg → try GitHub repo scope/pkg with releases → tags → package.json
        if (pkg.startsWith('@')) {
          final parts = pkg.substring(1).split('/');
          if (parts.length == 2) {
            final repo = '${parts[0]}/${parts[1]}';
            return _checkGithubWithFallbacks(server.name, repo, server.currentVersion);
          }
        }
        return VersionCheckResult.error(
          server.name,
          'npm 上找不到套件「$pkg」，且無法推斷 GitHub repo。',
        );
      }
      if (response.statusCode != 200) {
        return VersionCheckResult.error(
          server.name,
          'npm registry 回傳 ${response.statusCode}',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latest = data['version'] as String?;
      if (latest == null) {
        return VersionCheckResult.error(server.name, 'npm 回應中沒有版本資訊');
      }
      final current = server.currentVersion;
      if (VersionUtils.isNewer(current, latest)) {
        return VersionCheckResult.updateAvailable(
          mcpName: server.name,
          currentVersion: current ?? 'untracked',
          latestVersion: latest,
          releaseUrl: 'https://www.npmjs.com/package/$pkg',
        );
      }
      return VersionCheckResult.upToDate(server.name, latest);
    } catch (e) {
      return VersionCheckResult.error(server.name, e.toString());
    }
  }

  /// Tries GitHub releases → tags → package.json in sequence.
  Future<VersionCheckResult> _checkGithubWithFallbacks(
    String mcpName,
    String repo,
    String? currentVersion,
  ) async {
    // 1. Formal releases
    final relResult = await _checkGithubRepo(mcpName, repo, currentVersion);
    if (!relResult.hasError) return relResult;

    // 2. Tags API (repos without formal releases)
    try {
      final tagsUri = Uri.parse('https://api.github.com/repos/$repo/tags?per_page=1');
      final tagsResp = await _client.get(
        tagsUri,
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));

      if (tagsResp.statusCode == 200) {
        final tags = jsonDecode(tagsResp.body) as List<dynamic>;
        if (tags.isNotEmpty) {
          final tagName = tags.first['name'] as String?;
          if (tagName != null) {
            final latest = tagName.startsWith('v') ? tagName.substring(1) : tagName;
            if (VersionUtils.isNewer(currentVersion, latest)) {
              return VersionCheckResult.updateAvailable(
                mcpName: mcpName,
                currentVersion: currentVersion ?? 'untracked',
                latestVersion: latest,
                releaseUrl: 'https://github.com/$repo/tags',
              );
            }
            return VersionCheckResult.upToDate(mcpName, latest);
          }
        }
      }
    } catch (_) {}

    // 3. package.json on default branch (last resort)
    for (final branch in ['main', 'master']) {
      try {
        final pkgUri = Uri.parse(
          'https://raw.githubusercontent.com/$repo/$branch/package.json',
        );
        final pkgResp = await _client.get(pkgUri).timeout(const Duration(seconds: 8));
        if (pkgResp.statusCode == 200) {
          final pkgData = jsonDecode(pkgResp.body) as Map<String, dynamic>;
          final latest = pkgData['version'] as String?;
          if (latest != null) {
            if (VersionUtils.isNewer(currentVersion, latest)) {
              return VersionCheckResult.updateAvailable(
                mcpName: mcpName,
                currentVersion: currentVersion ?? 'untracked',
                latestVersion: latest,
                releaseUrl: 'https://github.com/$repo',
              );
            }
            return VersionCheckResult.upToDate(mcpName, latest);
          }
        }
      } catch (_) {}
    }

    // All fallbacks exhausted
    return VersionCheckResult.error(
      mcpName,
      'npm 上找不到此套件，GitHub ($repo) 也無 releases/tags/package.json。',
    );
  }

  Future<VersionCheckResult> _checkPypi(McpServer server) async {
    final pkg = server.packageName;
    if (pkg == null) {
      return VersionCheckResult.error(server.name, 'Could not detect Python package name');
    }
    try {
      final uri = Uri.parse('https://pypi.org/pypi/$pkg/json');
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return VersionCheckResult.error(
          server.name,
          'PyPI returned ${response.statusCode}',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final info = data['info'] as Map<String, dynamic>?;
      final latest = info?['version'] as String?;
      if (latest == null) {
        return VersionCheckResult.error(server.name, 'No version in PyPI response');
      }
      final current = server.currentVersion;
      if (VersionUtils.isNewer(current, latest)) {
        return VersionCheckResult.updateAvailable(
          mcpName: server.name,
          currentVersion: current ?? 'untracked',
          latestVersion: latest,
          releaseUrl: 'https://pypi.org/project/$pkg/',
        );
      }
      return VersionCheckResult.upToDate(server.name, latest);
    } catch (e) {
      return VersionCheckResult.error(server.name, e.toString());
    }
  }

  Future<VersionCheckResult> _checkGithub(McpServer server) async {
    final repo = server.githubRepo;
    if (repo == null) {
      return VersionCheckResult.error(server.name, 'Could not detect GitHub repo');
    }
    return _checkGithubRepo(server.name, repo, server.currentVersion);
  }

  Future<VersionCheckResult> _checkGithubRepo(
    String mcpName,
    String repo,
    String? currentVersion,
  ) async {
    try {
      final uri =
          Uri.parse('https://api.github.com/repos/$repo/releases/latest');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 404) {
        return VersionCheckResult.error(mcpName, 'No releases found on GitHub');
      }
      if (response.statusCode != 200) {
        return VersionCheckResult.error(
          mcpName,
          'GitHub API returned ${response.statusCode}',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String?;
      final htmlUrl = data['html_url'] as String?;
      if (tagName == null) {
        return VersionCheckResult.error(mcpName, 'No tag_name in GitHub response');
      }
      final latest = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      if (VersionUtils.isNewer(currentVersion, latest)) {
        return VersionCheckResult.updateAvailable(
          mcpName: mcpName,
          currentVersion: currentVersion ?? 'untracked',
          latestVersion: latest,
          releaseUrl: htmlUrl,
        );
      }
      return VersionCheckResult.upToDate(mcpName, latest);
    } catch (e) {
      return VersionCheckResult.error(mcpName, e.toString());
    }
  }

  void dispose() => _client.close();
}
