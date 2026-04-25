import 'dart:convert';
import 'dart:io';

/// Runs a shell command and streams stdout/stderr lines.
class ProcessRunner {
  /// Runs [executable] with [arguments] and returns all output lines.
  /// Throws [ProcessException] on non-zero exit code.
  static Future<List<String>> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: true,
    );
    final lines = <String>[];
    lines.addAll(result.stdout.toString().split('\n'));
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        result.stderr.toString(),
        result.exitCode,
      );
    }
    return lines;
  }

  /// Runs a command and yields output lines as a stream (for live log).
  static Stream<String> stream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async* {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: true,
    );

    await for (final line in process.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())) {
      yield line;
    }
    await for (final line in process.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())) {
      yield '[stderr] $line';
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw ProcessException(executable, arguments, 'Exit code: $exitCode', exitCode);
    }
  }
}
