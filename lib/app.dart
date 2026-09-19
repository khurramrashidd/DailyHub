import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/localization.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'core/workspace_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/profile_screen.dart';
import 'services/auth_service.dart';
import 'services/db_service.dart';
import 'services/notification_service.dart';

class DailyHubApp extends StatelessWidget {
  const DailyHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final locale = context.watch<LocaleProvider>();

    return LocaleScope(
      lang: locale.lang,
      child: MaterialApp(
        title: 'DailyHub',
        debugShowCheckedModeBanner: false,
        themeMode: theme.mode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Paints the soft blue page-gradient behind every screen in light
        // mode, matching the original web app's body background. Dark mode
        // keeps a plain dark backdrop (the web app never had a dark theme).
        builder: (context, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          if (!isDark) {
            return DecoratedBox(
              decoration: const BoxDecoration(gradient: AppColors.bodyGradient),
              child: child,
            );
          }
          return child ?? const SizedBox.shrink();
        },
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // Reset workspace to your own on each fresh login.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ws = context.read<WorkspaceProvider>();
            ws.resetToOwn();
            DbService.instance.activeWorkspaceUid = ws.ownUid;
            if (!kIsWeb) {
              NotificationService.instance.requestPermissions();
            }
          });
          return const _ProfileGate();
        }
        return const AuthScreen();
      },
    );
  }
}

/// Mirrors the web app: if users/{uid}/profile does not exist yet, show the
/// profile setup screen before the dashboard.
class _ProfileGate extends StatelessWidget {
  const _ProfileGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: DbService.instance.profileStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final profile = snap.data;
        final hasName =
            profile != null && (profile['name'] ?? '').toString().isNotEmpty;
        if (!hasName) {
          return const ProfileScreen(isSetup: true);
        }
        return const HomeShell();
      },
    );
  }
}
