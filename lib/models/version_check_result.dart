class VersionCheckResult {
  final String mcpName;
  final String? currentVersion;
  final String? latestVersion;
  final bool updateAvailable;
  final String? releaseUrl;
  final String? errorMessage;

  // ── HTTP/SSE connectivity check (not a version check) ───────────────────────
  /// True if this result represents a server connectivity probe, not a version check.
  final bool isConnectivity;
  /// Online/offline result for connectivity checks. Null for version checks.
  final bool? isOnline;

  const VersionCheckResult({
    required this.mcpName,
    this.currentVersion,
    this.latestVersion,
    this.updateAvailable = false,
    this.releaseUrl,
    this.errorMessage,
    this.isConnectivity = false,
    this.isOnline,
  });

  bool get hasError => errorMessage != null;
  bool get isUntracked => currentVersion == null;

  factory VersionCheckResult.error(String mcpName, String message) {
    return VersionCheckResult(mcpName: mcpName, errorMessage: message);
  }

  factory VersionCheckResult.upToDate(String mcpName, String version) {
    return VersionCheckResult(
      mcpName: mcpName,
      currentVersion: version,
      latestVersion: version,
      updateAvailable: false,
    );
  }

  factory VersionCheckResult.updateAvailable({
    required String mcpName,
    required String currentVersion,
    required String latestVersion,
    String? releaseUrl,
  }) {
    return VersionCheckResult(
      mcpName: mcpName,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      updateAvailable: true,
      releaseUrl: releaseUrl,
    );
  }

  /// Result for HTTP/SSE server connectivity probe.
  factory VersionCheckResult.connectivity(
    String mcpName, {
    required bool isOnline,
    String? url,
  }) {
    return VersionCheckResult(
      mcpName: mcpName,
      isConnectivity: true,
      isOnline: isOnline,
      errorMessage: isOnline ? null : 'Server not reachable at ${url ?? "unknown"}',
    );
  }
}
