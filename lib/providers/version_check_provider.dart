import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mcp_server.dart';
import '../models/version_check_result.dart';
import '../services/version_check_service.dart';

final _versionCheckService = VersionCheckService();

/// FutureProvider.family that checks the version for a single MCP server.
final versionCheckProvider =
    FutureProvider.family<VersionCheckResult, McpServer>((ref, server) async {
  return _versionCheckService.check(server);
});
