import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mcp_server.dart';
import '../models/ai_client.dart';
import '../services/config_parser_service.dart';
import 'ai_clients_provider.dart';

final _configParser = ConfigParserService();

/// Provides the flat list of all MCP servers merged across all enabled clients.
final mcpListProvider = FutureProvider<List<McpServer>>((ref) async {
  final clients = await ref.watch(aiClientsProvider.future);
  final enabled = clients.where((c) => c.isEnabled).toList();

  final allServers = <McpServer>[];
  for (final client in enabled) {
    final servers =
        await _configParser.readConfig(client.configPath, client.type);
    allServers.addAll(servers);
  }

  return _configParser.mergeServers(allServers);
});

/// Filter state: null means "All", otherwise filter to specific client type.
final clientFilterProvider =
    StateProvider<AiClientType?>((ref) => null);

/// Filtered MCP list based on selected client filter.
final filteredMcpListProvider = Provider<AsyncValue<List<McpServer>>>((ref) {
  final filter = ref.watch(clientFilterProvider);
  final mcpList = ref.watch(mcpListProvider);

  return mcpList.whenData((servers) {
    if (filter == null) return servers;
    return servers
        .where((s) => s.clients.contains(filter))
        .toList();
  });
});
