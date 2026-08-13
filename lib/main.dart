import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'providers/settings_providers.dart';
import 'screens/shell/app_shell.dart';
import 'services/auth_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  // Silent anonymous sign-in: gives every device a stable auth.uid() for
  // bookmarks/sync/RLS with no login screen and no account required.
  await AuthService.instance.ensureSignedIn();

  // Load persisted Settings > Reading Preferences before the first frame,
  // so there's no flash of the default theme/text size on launch.
  final prefs = await SharedPreferences.getInstance();
  final initialThemeMode = themeModeFromString(prefs.getString('theme_mode'));
  final initialTextSize = textSizeFromString(prefs.getString('text_size'));

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(
            (ref) => ThemeModeController(prefs, initialThemeMode)),
        textSizeProvider
            .overrideWith((ref) => TextSizeController(prefs, initialTextSize)),
      ],
      child: const CpgApp(),
    ),
  );
}

class CpgApp extends ConsumerWidget {
  const CpgApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'CPG',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const AppShell(),
    );
  }
}
