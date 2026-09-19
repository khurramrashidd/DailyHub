import '../widgets/common.dart';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_version.dart';
import '../core/localization.dart';
import '../core/responsive.dart';
import '../core/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final locale = context.watch<LocaleProvider>();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: GradientAppBar(title: Text(context.t('settings'))),
      body: ContentWidth(
        child: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF667EEA),
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(user?.displayName ?? user?.email ?? 'User'),
            subtitle: Text(user?.email ?? ''),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text(context.t('dark_mode')),
            value: theme.isDark,
            onChanged: (v) => theme.setDark(v),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.t('language')),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'hi', label: Text('हिं')),
              ],
              selected: {locale.lang},
              onSelectionChanged: (s) => locale.setLang(s.first),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(context.t('export_data')),
            onTap: () => _export(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('Check for updates'),
            subtitle: const Text('Version ${AppVersion.appVersion}'),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Checking...')));
              final info =
                  await UpdateService.instance.check(ignoreSkipped: true);
              if (!context.mounted) return;
              if (info == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You are up to date')));
              } else {
                await showUpdateDialog(context, info);
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFE74C3C)),
            title: Text(context.t('logout'),
                style: const TextStyle(color: Color(0xFFE74C3C))),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(context.t('logout')),
                  content: const Text('Sign out of DailyHub?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(context.t('cancel'))),
                    GradientButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(context.t('logout'))),
                  ],
                ),
              );
              if (ok == true) await AuthService().signOut();
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('DailyHub v${AppVersion.appVersion}',
                style: TextStyle(color: Colors.grey.shade400)),
          ),
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      final data = await DbService.instance.exportAll();
      const encoder = JsonEncoder.withIndent('  ');
      final json = encoder.convert(data);
      await Share.share(json,
          subject: 'My DailyHub data export');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}
