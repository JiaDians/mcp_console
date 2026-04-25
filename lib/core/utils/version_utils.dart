/// Result of extracting a package identity from CLI args.
class PackageInfo {
  final String? name;
  final String? version;
  const PackageInfo({this.name, this.version});
}

/// Utility functions for semantic version parsing, comparison, and
/// universal MCP package name/version extraction from CLI arg lists.
class VersionUtils {
  VersionUtils._();

  // ── Semver ──────────────────────────────────────────────────────────────

  /// Parses "1.2.3", "v1.2.3", "1.2.3-beta.1" → [1, 2, 3].
  /// Returns null if unparseable.
  static List<int>? parseVersion(String? version) {
    if (version == null) return null;
    final clean = version.startsWith('v') ? version.substring(1) : version;
    final parts = clean.split('-').first.split('.');
    try {
      return parts.map(int.parse).toList();
    } catch (_) {
      return null;
    }
  }

  /// Returns true if [latest] is strictly newer than [current].
  static bool isNewer(String? current, String? latest) {
    if (current == null || latest == null) return false;
    final c = parseVersion(current);
    final l = parseVersion(latest);
    if (c == null || l == null) return false;
    final len = c.length > l.length ? c.length : l.length;
    for (var i = 0; i < len; i++) {
      final cv = i < c.length ? c[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  // ── npm / Node ───────────────────────────────────────────────────────────

  /// Extracts npm package name + version from a list of CLI args.
  ///
  /// Handles all common `npx` / `npm exec` patterns:
  ///   npx -y @scope/pkg@1.2.3
  ///   npx --package @scope/pkg some-cmd
  ///   npx -p pkg@latest some-cmd
  ///   npx some-pkg
  ///   node /path/to/server.js   ← ignored (not a registry package)
  static PackageInfo extractNpmPackage(List<String> args) {
    // Flags whose NEXT arg is the package specifier
    const pkgFlags = {'--package', '-p'};
    // Flags whose NEXT arg is a non-package value (consume & skip)
    const valueFlags = {
      '--userconfig', '--registry', '--prefix', '--cache',
      '--tag', '--access', '--otp', '--workspace', '-w',
      '--script-shell', '--call', '-c',
    };

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg.startsWith('-')) {
        if (pkgFlags.contains(arg) && i + 1 < args.length) {
          final info = _parseNpmSpec(args[++i]);
          if (info.name != null) return info;
        } else if (valueFlags.contains(arg)) {
          i++; // skip value
        }
        continue;
      }
      final info = _parseNpmSpec(arg);
      if (info.name != null) return info;
    }
    return const PackageInfo();
  }

  /// Parses a single npm package specifier: "@scope/pkg@1.2.3", "pkg", etc.
  static PackageInfo _parseNpmSpec(String spec) {
    spec = spec.trim();
    // Reject file paths and flags
    if (spec.startsWith('-') ||
        spec.startsWith('.') ||
        spec.contains('/') && !spec.startsWith('@') ||
        spec.contains('\\') ||
        spec.endsWith('.js') ||
        spec.endsWith('.cjs') ||
        spec.endsWith('.mjs')) {
      return const PackageInfo();
    }
    // @scope/pkg@version  or  @scope/pkg
    final scoped = RegExp(r'^(@[\w.-]+/[\w.-]+)(?:@(.+))?$').firstMatch(spec);
    if (scoped != null) {
      return PackageInfo(
        name: scoped.group(1),
        version: _npmVersion(scoped.group(2)),
      );
    }
    // pkg@version  or  pkg
    final plain = RegExp(r'^([\w][\w.-]*)(?:@(.+))?$').firstMatch(spec);
    if (plain != null) {
      return PackageInfo(
        name: plain.group(1),
        version: _npmVersion(plain.group(2)),
      );
    }
    return const PackageInfo();
  }

  /// Returns a clean numeric version string, or null for tags like "latest".
  static String? _npmVersion(String? v) {
    if (v == null) return null;
    return RegExp(r'\d').hasMatch(v) ? v : null;
  }

  // ── Python ───────────────────────────────────────────────────────────────

  /// Extracts Python package name + version from CLI args.
  ///
  /// Handles all common `uvx` / `uv` / `python` / `pip` patterns:
  ///   uvx mcp-server-fetch
  ///   uvx mcp-server-fetch==1.2.3
  ///   uvx --from mcp-server-fetch@1.2.3 mcp-server-fetch
  ///   uv run mcp-server-fetch
  ///   uv run --with mcp-server-fetch some-cmd
  ///   uv tool run mcp-server-fetch
  ///   python -m mcp_server_fetch    ← underscores → hyphens for PyPI
  ///   python3 -m mcp_server_fetch
  ///   pip install mcp-server-fetch  ← "install" subcommand skipped
  static PackageInfo extractPythonPackage(List<String> args, String cmd) {
    final isPython = cmd == 'python' || cmd == 'python3';
    final isUvFamily = cmd == 'uv' || cmd == 'uvx';

    // Flags whose NEXT arg is the package specifier
    const pkgFlags = {'--from', '--with', '--package', '-p'};
    // Flags whose NEXT arg is a non-package value
    const valueFlags = {
      '--python', '-python', '--index-url', '-i',
      '--extra-index-url', '--find-links', '-f',
      '--log', '--target', '-t', '--upgrade-strategy',
      '--constraint', '-c', '--require', '-r',
      '--editable', '-e', '--prefix', '--root',
    };
    // uv / uvx subcommands that should be skipped
    const uvSubcmds = {
      'run', 'tool', 'pip', 'sync', 'add', 'remove', 'exec',
      'compile', 'lock', 'venv', 'init', 'build', 'publish',
      'install', 'uninstall', 'list', 'show', 'freeze',
    };

    String? name;
    String? version;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];

      if (arg.startsWith('-')) {
        if (pkgFlags.contains(arg) && i + 1 < args.length) {
          final info = _parsePythonSpec(args[++i]);
          name ??= info.name;
          version ??= info.version;
          if (name != null) break;
        } else if (valueFlags.contains(arg)) {
          i++; // skip value
        }
        continue;
      }

      // Skip uv/uvx subcommands
      if (isUvFamily && uvSubcmds.contains(arg)) continue;

      final info = _parsePythonSpec(arg);
      name ??= info.name;
      version ??= info.version;
      if (name != null) break;
    }

    // python -m my_module_name → PyPI typically uses hyphens
    if (isPython && name != null) name = name.replaceAll('_', '-');

    return PackageInfo(name: name, version: version);
  }

  /// Parses a single Python package specifier.
  /// Accepts: "pkg", "pkg==1.2.3", "pkg>=1.2.3", "pkg@1.2.3",
  ///           "pkg[extra]==1.2.3", "pkg-name", "pkg_name".
  static PackageInfo _parsePythonSpec(String spec) {
    spec = spec.trim();
    // Reject file paths
    if (spec.startsWith('.') ||
        spec.startsWith('/') ||
        spec.contains('\\') ||
        spec.endsWith('.py') ||
        spec.endsWith('.cfg') ||
        spec.endsWith('.toml')) {
      return const PackageInfo();
    }
    // pkg[extra]==version  or  pkg==version  or  pkg>=version  or  pkg@1.2.3
    final withVersion = RegExp(
      r'^([\w][\w.-]*)(?:\[[^\]]*\])?(?:[=><~!]+|@)([\d][\d.a-zA-Z]*).*$',
    ).firstMatch(spec);
    if (withVersion != null) {
      return PackageInfo(
        name: withVersion.group(1),
        version: withVersion.group(2),
      );
    }
    // pkg@latest  or  pkg@tag (non-numeric tag — strip tag, keep name)
    final withTag = RegExp(r'^([\w][\w.-]*)@\S+$').firstMatch(spec);
    if (withTag != null) {
      return PackageInfo(name: withTag.group(1));
    }
    // Plain package name: must start with letter/digit, no slashes
    if (RegExp(r'^[\w][\w.-]*$').hasMatch(spec) && !spec.contains('/')) {
      return PackageInfo(name: spec);
    }
    return const PackageInfo();
  }

  // ── GitHub ───────────────────────────────────────────────────────────────

  /// Parses a GitHub "owner/repo" from any arg containing a github.com URL
  /// or a bare "owner/repo" string.
  static String? extractGithubRepo(List<String> args) {
    for (final arg in args) {
      // Full GitHub URL
      final urlMatch =
          RegExp(r'github\.com[/:]([^/\s]+/[^/\s#?@]+)').firstMatch(arg);
      if (urlMatch != null) {
        var repo = urlMatch.group(1)!;
        if (repo.endsWith('.git')) repo = repo.substring(0, repo.length - 4);
        return repo;
      }
      // Bare owner/repo (exactly one slash, no dots that look like domains)
      final bareMatch = RegExp(r'^([\w.-]+/[\w.-]+)$').firstMatch(arg.trim());
      if (bareMatch != null && !arg.contains('..') && !arg.contains(':')) {
        return bareMatch.group(1);
      }
    }
    return null;
  }

  // ── Legacy helpers (kept for backward compat) ────────────────────────────

  static String? extractNpmVersion(String arg) =>
      extractNpmPackage([arg]).version;

  static String? extractNpmPackageName(String arg) =>
      extractNpmPackage([arg]).name;

  static String? extractPythonPackageName(String arg) =>
      _parsePythonSpec(arg).name;

  static String? extractPythonVersion(String arg) =>
      _parsePythonSpec(arg).version;
}
