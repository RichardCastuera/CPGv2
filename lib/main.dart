import 'package:cpg_reader/core/tiptap/tiptap_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/supabase/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await SupabaseService.initialize();

  runApp(const ProviderScope(child: CpgReaderApp()));
}

// Temporary smoke-test fixture — mirrors the shape seeded in
// phase0c-seed-data-tiptap.sql for sections.overview. Delete once
// Phase 4 wires real data through.
const _testDocument = {
  "type": "doc",
  "content": [
    {
      "type": "paragraph",
      "content": [
        {
          "type": "text",
          "text":
              "Asthma is a heterogeneous condition defined by a history of variable respiratory symptoms together with demonstrable variable expiratory airflow limitation. Diagnosis should be confirmed objectively ",
        },
        {
          "type": "text",
          "text": "before",
          "marks": [
            {"type": "bold"},
          ],
        },
        {
          "type": "text",
          "text":
              " long-term controller therapy is started wherever this is feasible.",
        },
      ],
    },
    {
      "type": "bulletList",
      "content": [
        {
          "type": "listItem",
          "content": [
            {
              "type": "paragraph",
              "content": [
                {"type": "text", "text": "Confirm with spirometry"},
              ],
            },
          ],
        },
        {
          "type": "listItem",
          "content": [
            {
              "type": "paragraph",
              "content": [
                {"type": "text", "text": "Check bronchodilator reversibility"},
              ],
            },
          ],
        },
      ],
    },
    {
      "type": "paragraph",
      "content": [
        {"type": "text", "text": "See the "},
        {
          "type": "text",
          "text": "GINA strategy report",
          "marks": [
            {
              "type": "link",
              "attrs": {"href": "https://ginasthma.org"},
            },
          ],
        },
        {"type": "text", "text": " for background."},
      ],
    },
  ],
};

class CpgReaderApp extends StatelessWidget {
  const CpgReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CPG Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B5566),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Tiptap Renderer Smoke Test')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: TiptapRenderer(document: _testDocument),
        ),
      ),
    );
  }
}
