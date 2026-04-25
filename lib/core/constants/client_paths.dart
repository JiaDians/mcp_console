import 'dart:io';

import '../../models/ai_client.dart';

/// Known MCP config file paths for each AI client on each platform.
class ClientPaths {
  ClientPaths._();

  static String get _appData => Platform.environment['APPDATA'] ?? '';
  static String get _userProfile => Platform.environment['USERPROFILE'] ?? '';
  static String get _home => Platform.environment['HOME'] ?? _userProfile;

  static String _winPath(String path) =>
      path.replaceAll('/', Platform.pathSeparator);

  static String defaultPathFor(AiClientType type) {
    if (Platform.isWindows) {
      return _windowsPath(type);
    } else if (Platform.isMacOS) {
      return _macosPath(type);
    } else {
      return _linuxPath(type);
    }
  }

  static String _windowsPath(AiClientType type) {
    switch (type) {
      case AiClientType.claudeDesktop:
        return _winPath('$_appData\\Claude\\claude_desktop_config.json');
      case AiClientType.cursor:
        return _winPath('$_userProfile\\.cursor\\mcp.json');
      case AiClientType.windsurf:
        return _winPath(
            '$_userProfile\\.codeium\\windsurf\\mcp_config.json');
      case AiClientType.vscodeCopilot:
        return _winPath('$_appData\\Code\\User\\mcp.json');
      case AiClientType.githubCopilotCli:
        return _winPath('$_userProfile\\.copilot\\mcp-config.json');
      case AiClientType.custom:
        return '';
    }
  }

  static String _macosPath(AiClientType type) {
    final home = _home;
    switch (type) {
      case AiClientType.claudeDesktop:
        return '$home/Library/Application Support/Claude/claude_desktop_config.json';
      case AiClientType.cursor:
        return '$home/.cursor/mcp.json';
      case AiClientType.windsurf:
        return '$home/.codeium/windsurf/mcp_config.json';
      case AiClientType.vscodeCopilot:
        return '$home/Library/Application Support/Code/User/mcp.json';
      case AiClientType.githubCopilotCli:
        return '$home/.copilot/mcp-config.json';
      case AiClientType.custom:
        return '';
    }
  }

  static String _linuxPath(AiClientType type) {
    final home = _home;
    switch (type) {
      case AiClientType.claudeDesktop:
        return '$home/.config/Claude/claude_desktop_config.json';
      case AiClientType.cursor:
        return '$home/.cursor/mcp.json';
      case AiClientType.windsurf:
        return '$home/.codeium/windsurf/mcp_config.json';
      case AiClientType.vscodeCopilot:
        return '$home/.config/Code/User/mcp.json';
      case AiClientType.githubCopilotCli:
        return '$home/.copilot/mcp-config.json';
      case AiClientType.custom:
        return '';
    }
  }

  /// All known (non-custom) client types in display order.
  static const List<AiClientType> knownClients = [
    AiClientType.claudeDesktop,
    AiClientType.cursor,
    AiClientType.windsurf,
    AiClientType.vscodeCopilot,
    AiClientType.githubCopilotCli,
  ];
}
