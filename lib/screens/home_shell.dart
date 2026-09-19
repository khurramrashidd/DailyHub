import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/workspace_provider.dart';
import '../services/admin_service.dart';
import '../services/db_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../widgets/quick_add_sheet.dart';
import 'admin_screen.dart';
import 'bookmarks_screen.dart';
import 'briefing_screen.dart';
import 'budget_screen.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'goals_screen.dart';
import 'habits_screen.dart';
import 'journal_screen.dart';
import 'notes_screen.dart';
import 'profile_screen.dart';
import 'reminders_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'shopping_screen.dart';
import 'sharing_screen.dart';
import 'student_screen.dart';
import 'timeline_screen.dart';
import 'todos_screen.dart';
import 'trips_screen.dart';
import 'work_screen.dart';

/// Six primary sections (Home, Today, Tasks, Travel, Notes, More) with a
/// layout that adapts: bottom bar on phones, navigation rail on tablets,
/// extended sidebar on desktop/web.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Check GitHub for a newer APK once per app launch. Distribution is
    // outside the Play Store, so this is the only update channel.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final info = await UpdateService.instance.check();
      if (info != null && mounted) {
        await showUpdateDialog(context, info);
      }
    });
  }

  static const _destinations = [
    _Dest(Icons.home_outlined, Icons.home, 'dashboard'),
    _Dest(Icons.timeline_outlined, Icons.timeline, 'today'),
    _Dest(Icons.check_circle_outline, Icons.check_circle, 'todos'),
    _Dest(Icons.flight_outlined, Icons.flight, 'trips'),
    _Dest(Icons.sticky_note_2_outlined, Icons.sticky_note_2, 'notes'),
    _Dest(Icons.grid_view_outlined, Icons.grid_view, 'more'),
  ];

  List<Widget> get _pages => const [
        DashboardScreen(),
        TimelineScreen(),
        TodosScreen(),
        TripsScreen(),
        NotesScreen(),
        MoreScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final sideNav = Responsive.hasSideNav(context);
    final extended = Responsive.isDesktop(context);

    final body = Column(
      children: [
        const BroadcastBanner(),
        const WorkspaceBanner(),
        Expanded(child: IndexedStack(index: _index, children: _pages)),
      ],
    );

    if (!sideNav) {
      // Phone: bottom navigation + centre FAB.
      return Scaffold(
        body: body,
        floatingActionButton: FloatingActionButton(
          onPressed: () => showQuickAdd(context),
          tooltip: 'Add',
          child: const Icon(Icons.add),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: _destinations
              .map((d) => NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: context.t(d.labelKey),
                  ))
              .toList(),
        ),
      );
    }

    // Tablet / desktop: persistent side navigation, no bottom bar.
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 200,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.dashboard_customize,
                        color: Colors.white, size: 22),
                  ),
                  if (extended) ...[
                    const SizedBox(height: 8),
                    const Text('DailyHub',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ],
                  const SizedBox(height: 14),
                  extended
                      ? SizedBox(
                          width: 160,
                          child: FloatingActionButton.extended(
                            heroTag: 'railFab',
                            onPressed: () => showQuickAdd(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                          ),
                        )
                      : FloatingActionButton(
                          heroTag: 'railFab',
                          onPressed: () => showQuickAdd(context),
                          child: const Icon(Icons.add),
                        ),
                ],
              ),
            ),
            destinations: _destinations
                .map((d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selected),
                      label: Text(context.t(d.labelKey)),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Dest {
  final IconData icon;
  final IconData selected;
  final String labelKey;
  const _Dest(this.icon, this.selected, this.labelKey);
}

/// Shown only when viewing someone else's shared workspace, so it's always
/// obvious whose data is on screen. Tap to return to your own.
class WorkspaceBanner extends StatelessWidget {
  const WorkspaceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WorkspaceProvider>();
    if (ws.isOwnWorkspace) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFF764BA2),
      child: InkWell(
        onTap: () {
          ws.resetToOwn();
          DbService.instance.activeWorkspaceUid = ws.ownUid;
        },
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.workspaces_outline,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${ws.name} • ${ws.role}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Text('Exit',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Icon(Icons.close, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the admin's announcement to every user until it's cleared.
class BroadcastBanner extends StatelessWidget {
  const BroadcastBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: AdminService.instance.broadcastStream(),
      builder: (context, snap) {
        final b = snap.data;
        if (b == null || (b['title'] ?? '').toString().isEmpty) {
          return const SizedBox.shrink();
        }
        return Material(
          color: const Color(0xFFFFF3C4),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.campaign_outlined,
                      color: Color(0xFF7A5C00), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b['title'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFF7A5C00))),
                        if ((b['message'] ?? '').toString().isNotEmpty)
                          Text(b['message'],
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF7A5C00))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_MoreItem>[
      _MoreItem(Icons.wb_sunny_outlined, 'Briefing', const Color(0xFFFF8C42),
          const BriefingScreen()),
      _MoreItem(Icons.calendar_month, context.t('calendar'),
          const Color(0xFF667EEA), const CalendarScreen()),
      _MoreItem(Icons.alarm, context.t('reminders'), const Color(0xFFE74C3C),
          const RemindersScreen()),
      _MoreItem(Icons.account_balance_wallet, context.t('expenses'),
          const Color(0xFF27AE60), const ExpensesScreen()),
      _MoreItem(Icons.savings_outlined, 'Budgets', const Color(0xFF1ABC9C),
          const BudgetScreen()),
      _MoreItem(Icons.school_outlined, 'Student', const Color(0xFF8E44AD),
          const StudentScreen()),
      _MoreItem(Icons.work_outline, 'Work', const Color(0xFF34495E),
          const WorkScreen()),
      _MoreItem(Icons.shopping_cart_outlined, 'Shopping',
          const Color(0xFFD35400), const ShoppingScreen()),
      _MoreItem(Icons.local_fire_department, context.t('habits'),
          const Color(0xFFF39C12), const HabitsScreen()),
      _MoreItem(Icons.flag, context.t('goals'), const Color(0xFF3498DB),
          const GoalsScreen()),
      _MoreItem(Icons.book, context.t('journal'), const Color(0xFF9B59B6),
          const JournalScreen()),
      _MoreItem(Icons.bookmark, context.t('bookmarks'),
          const Color(0xFF16A085), const BookmarksScreen()),
      _MoreItem(Icons.search, context.t('search'), const Color(0xFF34495E),
          const SearchScreen()),
      _MoreItem(Icons.group_add, 'Share', const Color(0xFFE67E22),
          const SharingScreen()),
      _MoreItem(Icons.person, 'Profile', const Color(0xFF2C3E50),
          const ProfileScreen()),
      _MoreItem(Icons.settings, context.t('settings'),
          const Color(0xFF7F8C8D), const SettingsScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('more')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        ),
      ),
      body: StreamBuilder<bool>(
        stream: AdminService.instance.adminStream(),
        builder: (context, adminSnap) {
          final all = [
            ...items,
            if (adminSnap.data == true)
              _MoreItem(Icons.admin_panel_settings, 'Admin',
                  const Color(0xFFC0392B), const AdminScreen()),
          ];
          return ContentWidth(
        child: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount:
              Responsive.gridColumns(context, phone: 3, tablet: 4, desktop: 6),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.95,
          children: all
              .map((it) => InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => it.screen)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: it.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: it.color.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(it.icon, color: it.color, size: 34),
                          const SizedBox(height: 10),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(it.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
          );
        },
      ),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String label;
  final Color color;
  final Widget screen;
  _MoreItem(this.icon, this.label, this.color, this.screen);
}
