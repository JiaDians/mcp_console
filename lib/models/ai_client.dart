import 'package:flutter/material.dart';

enum AiClientType {
  claudeDesktop,
  cursor,
  windsurf,
  vscodeCopilot,
  githubCopilotCli,
  custom;

  String get displayName {
    switch (this) {
      case AiClientType.claudeDesktop:
        return 'Claude Desktop';
      case AiClientType.cursor:
        return 'Cursor';
      case AiClientType.windsurf:
        return 'Windsurf';
      case AiClientType.vscodeCopilot:
        return 'VS Code';
      case AiClientType.githubCopilotCli:
        return 'Copilot CLI';
      case AiClientType.custom:
        return 'Custom';
    }
  }

  IconData get icon {
    switch (this) {
      case AiClientType.claudeDesktop:
        return Icons.chat_bubble_outline;
      case AiClientType.cursor:
        return Icons.code;
      case AiClientType.windsurf:
        return Icons.waves;
      case AiClientType.vscodeCopilot:
        return Icons.developer_mode;
      case AiClientType.githubCopilotCli:
        return Icons.terminal;
      case AiClientType.custom:
        return Icons.folder_open;
    }
  }
}

class AiClient {
  final AiClientType type;
  final String configPath;
  final bool isEnabled;

  const AiClient({
    required this.type,
    required this.configPath,
    this.isEnabled = true,
  });

  String get name => type.displayName;

  AiClient copyWith({
    AiClientType? type,
    String? configPath,
    bool? isEnabled,
  }) {
    return AiClient(
      type: type ?? this.type,
      configPath: configPath ?? this.configPath,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiClient &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          configPath == other.configPath;

  @override
  int get hashCode => type.hashCode ^ configPath.hashCode;
}
