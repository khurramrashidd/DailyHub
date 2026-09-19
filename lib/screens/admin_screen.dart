import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/admin_config.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../services/admin_service.dart';
import '../widgets/common.dart';

/// Superadmin master dashboard: aggregate stats, user management, content
/// inspection, broadcast, and the audit log of admin actions.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _admin = AdminService.instance;

  late final bool _isSuper;
  Map<String, int>? _stats;
  List<Map<String, dynamic>>? _users;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isSuper = AdminService.instance.isSuperAdmin;
    _tabs = TabController(length: _isSuper ? 5 : 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _admin.listUsers();
      final stats = await _admin.stats();
      if (!mounted) return;
      setState(() {
        _users = users;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        ),
        title: const Text('Admin'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(text: 'Overview'),
            const Tab(text: 'Users'),
            if (_isSuper) const Tab(text: 'Admins'),
            const Tab(text: 'Broadcast'),
            const Tab(text: 'Audit log'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : ContentWidth(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _overview(),
                      _userList(),
                      if (_isSuper) _adminManager(),
                      _broadcast(),
                      _auditLog(),
                    ],
                  ),
                ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 52, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Could not load admin data',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'This usually means the database rules do not grant your '
                'account admin access yet. See firebase_rules.json.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );

  Widget _overview() {
    final s = _stats ?? {};
    final tiles = [
      ('Users', s['users'] ?? 0, Icons.people, const Color(0xFF667EEA)),
      ('Tasks', s['todos'] ?? 0, Icons.check_circle, const Color(0xFF3498DB)),
      ('Trips', s['trips'] ?? 0, Icons.flight, const Color(0xFF27AE60)),
      ('Notes', s['notes'] ?? 0, Icons.sticky_note_2, const Color(0xFFF39C12)),
      ('Reminders', s['reminders'] ?? 0, Icons.alarm, const Color(0xFFE74C3C)),
      ('Expenses', s['expenses'] ?? 0, Icons.currency_rupee,
          const Color(0xFF16A085)),
      ('Goals', s['goals'] ?? 0, Icons.flag, const Color(0xFF9B59B6)),
      ('Habits', s['habits'] ?? 0, Icons.local_fire_department,
          const Color(0xFFE67E22)),
      ('Journal', s['journal'] ?? 0, Icons.book, const Color(0xFF2C3E50)),
    ];
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount:
          Responsive.gridColumns(context, phone: 2, tablet: 3, desktop: 4),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: tiles
          .map((t) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.$4.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.$4.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.$3, color: t.$4, size: 24),
                    const SizedBox(height: 8),
                    Text('${t.$2}',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: t.$4)),
                    Text(t.$1,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _userList() {
    final users = _users ?? [];
    if (users.isEmpty) {
      return const EmptyState(icon: Icons.people, message: 'No users found');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, i) {
        final u = users[i];
        final disabled = u['disabled'] == true;
        final total = [
          'todos', 'trips', 'notes', 'reminders', 'expenses',
          'goals', 'habits', 'journal', 'bookmarks'
        ].fold<int>(0, (s, c) => s + ((u['count_$c'] ?? 0) as int));
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  disabled ? Colors.grey : AppColors.primary,
              child: Text(
                (u['name'] ?? '?').toString().isEmpty
                    ? '?'
                    : (u['name'] ?? '?').toString()[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(u['name'] ?? '(no profile)'),
            subtitle: Text('$total items • ${u['uid']}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => _userAction(v, u),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'view', child: Text('View content')),
                PopupMenuItem(
                    value: 'toggle',
                    child: Text(disabled ? 'Enable' : 'Disable')),
                const PopupMenuItem(
                    value: 'delete', child: Text('Delete all data')),
              ],
            ),
            onTap: () => _userAction('view', u),
          ),
        );
      },
    );
  }

  Future<void> _userAction(String action, Map<String, dynamic> u) async {
    final uid = u['uid'] as String;
    if (action == 'view') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  _UserContentScreen(uid: uid, name: u['name'] ?? uid)));
    } else if (action == 'toggle') {
      await _admin.setDisabled(uid, u['disabled'] != true);
      await _load();
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete all data?'),
          content: Text(
              'This permanently removes every item belonging to ${u['name'] ?? uid}. '
              'Their login account will still exist. This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await _admin.deleteUserData(uid);
        await _load();
      }
    }
  }

  /// Superadmin-only: grant or revoke admin rights.
  Widget _adminManager() {
    final users = _users ?? [];
    return StreamBuilder<Set<String>>(
      stream: _admin.adminUidsStream(),
      builder: (context, snap) {
        final adminUids = snap.data ?? <String>{};
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              color: const Color(0xFFE8F4FD),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified_user,
                            color: Color(0xFF2980B9), size: 20),
                        SizedBox(width: 8),
                        Text('Superadmin',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(AdminConfig.superAdminEmail,
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      'Set in database.rules.json. Admins cannot grant this '
                      'role \u2014 changing it needs a rules redeploy.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: Text('Admins (${adminUids.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            if (users.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No users loaded'),
              ),
            ...users.map((u) {
              final uid = u['uid'] as String;
              final isAdmin = adminUids.contains(uid);
              return Card(
                child: SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor:
                        isAdmin ? const Color(0xFFC0392B) : Colors.grey,
                    child: Icon(
                        isAdmin
                            ? Icons.admin_panel_settings
                            : Icons.person_outline,
                        color: Colors.white,
                        size: 18),
                  ),
                  title: Text(u['name'] ?? '(no profile)'),
                  subtitle: Text(uid,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                  value: isAdmin,
                  onChanged: (v) async {
                    try {
                      await _admin.setAdmin(uid, v);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(v
                                ? 'Admin rights granted'
                                : 'Admin rights revoked')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(e
                                .toString()
                                .replaceAll('Exception: ', ''))));
                      }
                    }
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _broadcast() {
    final titleC = TextEditingController();
    final msgC = TextEditingController();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Send an announcement',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 4),
        Text('Every user sees this as a banner inside the app.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 14),
        TextField(
            controller: titleC,
            decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 10),
        TextField(
          controller: msgC,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        const SizedBox(height: 14),
        GradientButton(
          onPressed: () async {
            if (titleC.text.trim().isEmpty) return;
            await _admin.broadcast(titleC.text.trim(), msgC.text.trim());
            titleC.clear();
            msgC.clear();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Announcement sent')));
            }
          },
          child: const Text('Send to all users'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () async {
            await _admin.clearBroadcast();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Announcement cleared')));
            }
          },
          child: const Text('Clear current announcement'),
        ),
      ],
    );
  }

  Widget _auditLog() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _admin.auditStream(),
      builder: (context, snap) {
        final logs = snap.data ?? [];
        if (logs.isEmpty) {
          return const EmptyState(
              icon: Icons.receipt_long, message: 'No admin actions recorded');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: logs.length,
          itemBuilder: (context, i) {
            final l = logs[i];
            final at = DateTime.tryParse(l['at'] ?? '');
            return Card(
              child: ListTile(
                dense: true,
                leading: Icon(
                  switch (l['action']) {
                    'read' => Icons.visibility,
                    'deleteData' => Icons.delete_forever,
                    'disable' => Icons.block,
                    _ => Icons.info_outline,
                  },
                  color: l['action'] == 'deleteData'
                      ? const Color(0xFFE74C3C)
                      : Colors.grey.shade600,
                  size: 20,
                ),
                title: Text('${l['action']} • ${l['collection'] ?? ''}',
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  '${l['adminEmail'] ?? l['adminUid']} → ${l['targetUid']}'
                  '${at == null ? '' : '\n${DateFormat('d MMM yyyy, HH:mm').format(at)}'}',
                  style: const TextStyle(fontSize: 11),
                ),
                isThreeLine: at != null,
              ),
            );
          },
        );
      },
    );
  }
}

/// Inspect one user's content. Every tab switch writes an audit entry.
class _UserContentScreen extends StatelessWidget {
  final String uid;
  final String name;
  const _UserContentScreen({required this.uid, required this.name});

  static const _collections = [
    ('todos', 'Tasks', Icons.check_circle_outline),
    ('trips', 'Trips', Icons.flight),
    ('notes', 'Notes', Icons.sticky_note_2_outlined),
    ('reminders', 'Reminders', Icons.alarm),
    ('expenses', 'Expenses', Icons.currency_rupee),
    ('goals', 'Goals', Icons.flag),
    ('habits', 'Habits', Icons.local_fire_department),
    ('journal', 'Journal', Icons.book),
    ('bookmarks', 'Bookmarks', Icons.bookmark),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _collections.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.brandGradient),
          ),
          title: Text(name, overflow: TextOverflow.ellipsis),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: _collections
                .map((c) => Tab(text: c.$2, icon: Icon(c.$3, size: 18)))
                .toList(),
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF3C4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: const Text(
                'Viewing another user\'s private content. Every view is '
                'recorded in the audit log.',
                style: TextStyle(fontSize: 11, color: Color(0xFF7A5C00)),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: _collections
                    .map((c) => _CollectionView(uid: uid, collection: c.$1))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionView extends StatefulWidget {
  final String uid;
  final String collection;
  const _CollectionView({required this.uid, required this.collection});

  @override
  State<_CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<_CollectionView> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminService.instance
        .readUserCollection(widget.uid, widget.collection);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const EmptyState(
              icon: Icons.inbox_outlined, message: 'Nothing here');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = Map<String, dynamic>.from(items[i])..remove('id');
            final title = item['title'] ??
                item['name'] ??
                item['note'] ??
                item['text'] ??
                item['body'] ??
                item['from'] ??
                '(item)';
            return Card(
              child: ExpansionTile(
                title: Text(title.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14)),
                children: item.entries
                    .map((e) => ListTile(
                          dense: true,
                          title: Text(e.key,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          subtitle: Text('${e.value}',
                              style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
              ),
            );
          },
        );
      },
    );
  }
}
