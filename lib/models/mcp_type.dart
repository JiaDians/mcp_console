enum McpType {
  npm,
  python,
  github,
  sse,
  unknown;

  String get label {
    switch (this) {
      case McpType.npm:
        return 'npm';
      case McpType.python:
        return 'Python';
      case McpType.github:
        return 'GitHub';
      case McpType.sse:
        return 'HTTP/SSE';
      case McpType.unknown:
        return 'Unknown';
    }
  }
}
