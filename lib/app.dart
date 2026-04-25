import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';

class McpConsoleApp extends StatelessWidget {
  const McpConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCP Console',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
