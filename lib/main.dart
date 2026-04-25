import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    minimumSize: Size(900, 600),
    size: Size(1280, 760),
    center: true,
    title: 'MCP Console',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    const ProviderScope(
      child: McpConsoleApp(),
    ),
  );
}
