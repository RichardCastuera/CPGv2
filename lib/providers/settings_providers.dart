import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reading text size — this is a real functional setting: `textScaleProvider`
/// multiplies into every font size TiptapRenderer uses, so it actually
/// changes how guideline content renders, not just a UI preference that
/// does nothing.
enum ReadingTextSize { compact, defaultSize, large }

extension ReadingTextSizeX on ReadingTextSize {
  double get scale => switch (this) {
        ReadingTextSize.compact => 0.9,
        ReadingTextSize.defaultSize => 1.0,
        ReadingTextSize.large => 1.15,
      };

  String get label => switch (this) {
        ReadingTextSize.compact => 'Compact',
        ReadingTextSize.defaultSize => 'Default',
        ReadingTextSize.large => 'Large',
      };
}

ThemeMode themeModeFromString(String? value) => switch (value) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.light, // default to light, not system — matches the app's designed palette
    };

ReadingTextSize textSizeFromString(String? value) => switch (value) {
      'compact' => ReadingTextSize.compact,
      'large' => ReadingTextSize.large,
      _ => ReadingTextSize.defaultSize,
    };

class ThemeModeController extends StateNotifier<ThemeMode> {
  final SharedPreferences prefs;
  ThemeModeController(this.prefs, ThemeMode initial) : super(initial);

  void setDark(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    prefs.setString('theme_mode', isDark ? 'dark' : 'light');
  }
}

class TextSizeController extends StateNotifier<ReadingTextSize> {
  final SharedPreferences prefs;
  TextSizeController(this.prefs, ReadingTextSize initial) : super(initial);

  void set(ReadingTextSize size) {
    state = size;
    prefs.setString('text_size', size.name);
  }
}

// Both overridden in main() with values loaded from SharedPreferences before
// runApp — this avoids a flicker from the default value on first frame.
final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  throw UnimplementedError('themeModeProvider must be overridden in main()');
});

final textSizeProvider = StateNotifierProvider<TextSizeController, ReadingTextSize>((ref) {
  throw UnimplementedError('textSizeProvider must be overridden in main()');
});

/// What TiptapRenderer and other reading surfaces actually multiply their
/// font sizes by.
final textScaleProvider = Provider<double>((ref) => ref.watch(textSizeProvider).scale);

/// Manual "force offline" switch for testing/demo — the Ask tab's online/
/// offline routing checks this in addition to real device connectivity, so
/// you can exercise the offline fallback path without turning on airplane
/// mode. Intentionally not persisted — always resets to false on launch.
final forceOfflineProvider = StateProvider<bool>((ref) => false);
