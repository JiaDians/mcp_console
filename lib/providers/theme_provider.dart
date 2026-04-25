import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Color Accent Options ───────────────────────────────────────────────────

class AccentOption {
  final String label;
  final Color color;
  const AccentOption(this.label, this.color);
}

const List<AccentOption> kAccentOptions = [
  AccentOption('紫色', Color(0xFF6750A4)),
  AccentOption('藍色', Color(0xFF1565C0)),
  AccentOption('青色', Color(0xFF00695C)),
  AccentOption('綠色', Color(0xFF2E7D32)),
  AccentOption('橙色', Color(0xFFE65100)),
  AccentOption('玫瑰', Color(0xFFC62828)),
];

// ─── Theme Settings Model ────────────────────────────────────────────────────

class ThemeSettings {
  final ThemeMode mode;
  final Color accent;

  const ThemeSettings({
    this.mode = ThemeMode.system,
    this.accent = const Color(0xFF6750A4),
  });

  ThemeSettings copyWith({ThemeMode? mode, Color? accent}) => ThemeSettings(
        mode: mode ?? this.mode,
        accent: accent ?? this.accent,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class ThemeNotifier extends Notifier<ThemeSettings> {
  static const _modeKey = 'theme_mode';
  static const _accentKey = 'theme_accent';

  @override
  ThemeSettings build() {
    _load();
    return const ThemeSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIdx = prefs.getInt(_modeKey) ?? 0;
    final accentVal = prefs.getInt(_accentKey) ?? 0xFF6750A4;
    state = ThemeSettings(
      mode: ThemeMode.values[modeIdx.clamp(0, ThemeMode.values.length - 1)],
      accent: Color(accentVal),
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, mode.index);
  }

  Future<void> setAccent(Color accent) async {
    state = state.copyWith(accent: accent);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, accent.toARGB32());
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeSettings>(ThemeNotifier.new);
