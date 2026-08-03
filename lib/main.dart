import 'package:cpg_reader/core/supabase/supabase_client.dart';
import 'package:cpg_reader/features/home/home_page.dart';
import 'package:cpg_reader/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await SupabaseService.initialize();

  runApp(const ProviderScope(child: CpgReaderApp()));
}

class CpgReaderApp extends StatelessWidget {
  const CpgReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CPG Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}
