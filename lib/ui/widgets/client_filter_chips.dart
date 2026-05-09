import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
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
          padding: EdgeInsets.zero,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _FilterPill(
                icon: Icons.all_inclusive,
                label: '全部',
                selected: selectedFilter == null,
                onSelected: () =>
                    ref.read(clientFilterProvider.notifier).state = null,
              ),
              ...enabledClients.map(
                (client) => _FilterPill(
                  icon: client.type.icon,
                  label: client.name,
                  selected: selectedFilter == client.type,
                  onSelected: () {
                    final notifier = ref.read(clientFilterProvider.notifier);
                    notifier.state = selectedFilter == client.type
                        ? null
                        : client.type;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: ChoiceChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
