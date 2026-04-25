import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_client.dart';
import '../core/constants/client_paths.dart';

const _prefKeyCustomPaths = 'custom_paths';
const _prefKeyDisabledClients = 'disabled_clients';

/// Provider for SharedPreferences instance.
final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// Provider for the full list of AI clients (built-in + custom).
final aiClientsProvider =
    AsyncNotifierProvider<AiClientsNotifier, List<AiClient>>(
  AiClientsNotifier.new,
);

class AiClientsNotifier extends AsyncNotifier<List<AiClient>> {
  @override
  Future<List<AiClient>> build() async {
    final prefs = await ref.watch(sharedPrefsProvider.future);
    final disabled = prefs.getStringList(_prefKeyDisabledClients) ?? [];
    final customPaths = prefs.getStringList(_prefKeyCustomPaths) ?? [];

    final builtIn = ClientPaths.knownClients.map((type) {
      return AiClient(
        type: type,
        configPath: ClientPaths.defaultPathFor(type),
        isEnabled: !disabled.contains(type.name),
      );
    }).toList();

    final customs = customPaths.map((path) {
      return AiClient(
        type: AiClientType.custom,
        configPath: path,
        isEnabled: !disabled.contains('custom:$path'),
      );
    }).toList();

    return [...builtIn, ...customs];
  }

  Future<void> toggleClient(AiClient client) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final disabled = List<String>.from(
      prefs.getStringList(_prefKeyDisabledClients) ?? [],
    );
    final key = client.type == AiClientType.custom
        ? 'custom:${client.configPath}'
        : client.type.name;

    if (disabled.contains(key)) {
      disabled.remove(key);
    } else {
      disabled.add(key);
    }
    await prefs.setStringList(_prefKeyDisabledClients, disabled);
    ref.invalidateSelf();
  }

  Future<void> addCustomPath(String path) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final paths = List<String>.from(
      prefs.getStringList(_prefKeyCustomPaths) ?? [],
    );
    if (!paths.contains(path)) {
      paths.add(path);
      await prefs.setStringList(_prefKeyCustomPaths, paths);
      ref.invalidateSelf();
    }
  }

  Future<void> removeCustomPath(String path) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final paths = List<String>.from(
      prefs.getStringList(_prefKeyCustomPaths) ?? [],
    );
    paths.remove(path);
    await prefs.setStringList(_prefKeyCustomPaths, paths);
    ref.invalidateSelf();
  }
}
