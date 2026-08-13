import 'package:flutter/material.dart';

import '../library/library_screen.dart';
import '../offline/offline_screen.dart';
import '../saved/saved_screen.dart';
import '../settings/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [
    LibraryScreen(),
    SavedScreen(),
    OfflineScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Library'),
          NavigationDestination(
              icon: Icon(Icons.bookmark_border_rounded),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: 'Saved'),
          NavigationDestination(
              icon: Icon(Icons.download_outlined),
              selectedIcon: Icon(Icons.download_rounded),
              label: 'Offline'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings'),
        ],
      ),
    );
  }
}
