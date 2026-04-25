import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'ui/screens/home_screen.dart';

class McpConsoleApp extends ConsumerWidget {
  const McpConsoleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return MaterialApp(
      title: 'MCP Console',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(theme.accent),
      darkTheme: AppTheme.dark(theme.accent),
      themeMode: theme.mode,
      home: const HomeScreen(),
    );
  }
}
