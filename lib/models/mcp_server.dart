import 'mcp_type.dart';
import 'ai_client.dart';

class McpServer {
  final String name;
  final String command;
  final List<String> args;
  final Map<String, String> env;
  final McpType type;
  final String? currentVersion;
  final String? packageName;
  final String? githubRepo;

  // ── Transports ──────────────────────────────────────────────────────────────
  /// HTTP/SSE transport endpoint (Streamable HTTP or legacy SSE)
  final String? url;
  /// HTTP headers for url-based transport (e.g. Authorization: Bearer …)
  final Map<String, String> headers;

  // ── Runtime options ──────────────────────────────────────────────────────────
  /// When true, this MCP entry is disabled in the client config
  final bool disabled;
  /// Connection timeout in milliseconds (client-specific, e.g. Claude Desktop)
  final int? timeout;
  /// Tool names that are auto-approved without user confirmation (alwaysAllow / autoApprove)
  final List<String> alwaysAllow;

  /// Which AI clients have this MCP configured
  final List<AiClientType> clients;

  const McpServer({
    required this.name,
    required this.command,
    required this.args,
    required this.env,
    required this.type,
    required this.clients,
    this.currentVersion,
    this.packageName,
    this.githubRepo,
    this.url,
    this.headers = const {},
    this.disabled = false,
    this.timeout,
    this.alwaysAllow = const [],
  });

  McpServer copyWith({
    String? name,
    String? command,
    List<String>? args,
    Map<String, String>? env,
    McpType? type,
    List<AiClientType>? clients,
    String? currentVersion,
    String? packageName,
    String? githubRepo,
    String? url,
    Map<String, String>? headers,
    bool? disabled,
    int? timeout,
    List<String>? alwaysAllow,
  }) {
    return McpServer(
      name: name ?? this.name,
      command: command ?? this.command,
      args: args ?? this.args,
      env: env ?? this.env,
      type: type ?? this.type,
      clients: clients ?? this.clients,
      currentVersion: currentVersion ?? this.currentVersion,
      packageName: packageName ?? this.packageName,
      githubRepo: githubRepo ?? this.githubRepo,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      disabled: disabled ?? this.disabled,
      timeout: timeout ?? this.timeout,
      alwaysAllow: alwaysAllow ?? this.alwaysAllow,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is McpServer &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'McpServer(name: $name, type: $type, version: $currentVersion)';
}
