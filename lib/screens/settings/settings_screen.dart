import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../providers/guideline_providers.dart';
import '../../providers/settings_providers.dart';
import '../../services/auth_service.dart';

final autoUpdateOnWifiProvider = StateProvider<bool>((ref) => true);

/// One-shot real connectivity check, re-run whenever this provider is
/// invalidated (e.g. pull-to-refresh isn't wired here, but rebuilding the
/// screen re-checks). Combined with forceOfflineProvider for display.
final _realConnectivityProvider = FutureProvider<bool>((ref) async {
  final result = await Connectivity().checkConnectivity();
  return !result.contains(ConnectivityResult.none);
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAnonymous = AuthService.instance.isAnonymous;
    final user = ref.watch(supabaseServiceProvider).client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: 'READING PREFERENCES',
            child: Column(
              children: [
                _AppearanceRow(),
                const SizedBox(height: 14),
                _TextSizeRow(),
              ],
            ),
          ),
          _SettingsSection(title: 'CONNECTIVITY', child: _ConnectivityRow()),
          _SettingsSection(
            title: 'ACCOUNT',
            child: _AccountRow(isAnonymous: isAnonymous, email: user?.email),
          ),
          _SettingsSection(
            title: 'SYNC',
            child: _SyncRow(),
          ),
          _SettingsSection(
            title: 'SPECIALTY',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_hospital_outlined),
              title: const Text('Specialty interests'),
              subtitle: const Text(
                  'Choose specialties to get notified about new guidelines'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                // Hook up to a specialty-tags multi-select screen, writing to
                // a per-user preferences table/row.
              },
            ),
          ),
          _SettingsSection(
            title: 'ABOUT',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Version',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                Text('0.1.0',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ],
            ),
          ),
          if (!isAnonymous)
            _SettingsSection(
              title: 'ACTIONS',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                subtitle:
                    const Text('Returns to an anonymous, device-only session'),
                onTap: () async {
                  await ref.read(supabaseServiceProvider).client.auth.signOut();
                  await AuthService.instance.ensureSignedIn();
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared card-with-caps-label wrapper matching the design's section style.
class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _SettingsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AppearanceRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(
              isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              size: 18,
              color: AppColors.primaryGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Appearance',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(isDark ? 'Dark mode' : 'Light mode',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Switch(
          value: isDark,
          onChanged: (v) => ref.read(themeModeProvider.notifier).setDark(v),
          activeThumbColor: AppColors.primaryGreen,
        ),
      ],
    );
  }
}

class _TextSizeRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(textSizeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.format_size_rounded,
                  size: 18, color: AppColors.primaryGreen),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Text size',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('Adjust guideline reading size',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: ReadingTextSize.values.map((size) {
            final selected = size == current;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: size != ReadingTextSize.values.last ? 8 : 0),
                child: Material(
                  color: selected
                      ? AppColors.primaryGreen.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => ref.read(textSizeProvider.notifier).set(size),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: selected
                                ? AppColors.primaryGreen
                                : AppColors.divider),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        size.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? AppColors.primaryGreen
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ConnectivityRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forcedOffline = ref.watch(forceOfflineProvider);
    final realOnlineAsync = ref.watch(_realConnectivityProvider);
    final realOnline = realOnlineAsync.asData?.value ?? true;
    final isOnline = realOnline && !forcedOffline;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              size: 18,
              color: isOnline
                  ? AppColors.statusAvailableOffline
                  : AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              Text(
                isOnline
                    ? 'All guidelines stream over the network'
                    : 'Working from downloaded content only',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () =>
              ref.read(forceOfflineProvider.notifier).state = !forcedOffline,
          child: Text(forcedOffline ? 'Go online' : 'Go offline'),
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  final bool isAnonymous;
  final String? email;
  const _AccountRow({required this.isAnonymous, required this.email});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(
              isAnonymous
                  ? Icons.person_outline_rounded
                  : Icons.verified_user_rounded,
              size: 18,
              color: AppColors.primaryGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isAnonymous ? 'Using this device' : (email ?? 'Signed in'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              Text(
                isAnonymous
                    ? 'Your bookmarks and downloads are saved to this device. Link an email to sync them across devices.'
                    : 'Account',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        if (isAnonymous)
          TextButton(
            onPressed: () => _showLinkEmailSheet(context),
            child: const Text('Link email'),
          ),
      ],
    );
  }

  void _showLinkEmailSheet(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Link an email',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Your bookmarks and downloads stay exactly as they are — this just lets you access them from another device too.',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'you@example.com'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final email = controller.text.trim();
                  if (email.isEmpty) return;
                  await AuthService.instance.linkEmail(email);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Check $email to confirm and finish linking.')),
                    );
                  }
                },
                child: const Text('Send confirmation link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoUpdate = ref.watch(autoUpdateOnWifiProvider);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.sync_rounded,
              size: 18, color: AppColors.primaryGreen),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Auto-update on Wi-Fi',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(
                  'Automatically download new guideline versions when connected to Wi-Fi',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4)),
            ],
          ),
        ),
        Switch(
          value: autoUpdate,
          onChanged: (v) =>
              ref.read(autoUpdateOnWifiProvider.notifier).state = v,
          activeThumbColor: AppColors.primaryGreen,
        ),
      ],
    );
  }
}
