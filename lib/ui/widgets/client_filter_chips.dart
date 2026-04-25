import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ai_clients_provider.dart';
import '../../providers/mcp_list_provider.dart';

class ClientFilterChips extends ConsumerWidget {
  const ClientFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(aiClientsProvider);
    final selectedFilter = ref.watch(clientFilterProvider);

    return clientsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (clients) {
        final enabledClients = clients.where((c) => c.isEnabled).toList();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('全部'),
                selected: selectedFilter == null,
                onSelected: (_) =>
                    ref.read(clientFilterProvider.notifier).state = null,
              ),
              const SizedBox(width: 8),
              ...enabledClients.map((client) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(client.type.icon, size: 16),
                      label: Text(client.name),
                      selected: selectedFilter == client.type,
                      onSelected: (_) {
                        final notifier =
                            ref.read(clientFilterProvider.notifier);
                        notifier.state =
                            selectedFilter == client.type ? null : client.type;
                      },
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}
