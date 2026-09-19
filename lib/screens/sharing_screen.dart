import '../widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../core/workspace_provider.dart';
import '../services/db_service.dart';

/// Workspace sharing — same model as the web app.
/// Share by email (looked up via emailToUid), assign a role, change it live,
/// or revoke. Also lists workspaces others have shared with you.
class SharingScreen extends StatefulWidget {
  const SharingScreen({super.key});

  @override
  State<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends State<SharingScreen> {
  final _email = TextEditingController();
  String _role = 'view';
  bool _busy = false;

  static const roleLabels = {
    'view': 'View Only',
    'add': 'Add Only',
    'master': 'Master',
  };

  Future<void> _share() async {
    if (_email.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await DbService.instance.shareWith(_email.text.trim(), _role);
      _email.clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Workspace shared')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    final ws = context.watch<WorkspaceProvider>();

    return Scaffold(
      appBar: const GradientAppBar(title: Text('Share Workspace')),
      body: ContentWidth(
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Invite someone',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('They need a DailyHub account already.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Their email address',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Permission'),
                    items: roleLabels.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _role = v ?? 'view'),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _share,
                    icon: _busy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.person_add_alt),
                    label: const Text('Share'),
                  ),
                ],
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(4, 22, 4, 8),
            child: Text('Shared with',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.collaboratorsStream(),
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Not shared with anyone yet',
                      style: TextStyle(color: Colors.grey.shade500)),
                );
              }
              return Column(
                children: list.map((c) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(c['email'] ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          DropdownButton<String>(
                            value: roleLabels.containsKey(c['role'])
                                ? c['role']
                                : 'view',
                            underline: const SizedBox.shrink(),
                            items: roleLabels.entries
                                .map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value,
                                        style:
                                            const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                db.updateCollaboratorRole(c['uid'], v);
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Revoke',
                            icon: const Icon(Icons.person_remove_outlined,
                                color: Color(0xFFE74C3C)),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Revoke access?'),
                                  content: Text(
                                      '${c['email']} will lose access to your workspace.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(context.t('cancel'))),
                                    GradientButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Revoke')),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await db.removeCollaborator(c['uid']);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(4, 22, 4, 8),
            child: Text('Shared with me',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.sharedWithMeStream(),
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No one has shared a workspace with you',
                      style: TextStyle(color: Colors.grey.shade500)),
                );
              }
              return Column(
                children: list.map((s) {
                  final active = ws.workspaceUid == s['uid'];
                  final label =
                      "${s['ownerName'] ?? 'Shared User'}'s Workspace";
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: active
                            ? const Color(0xFF667EEA)
                            : Colors.grey.shade300,
                        child: Icon(Icons.workspaces_outline,
                            color: active ? Colors.white : Colors.grey),
                      ),
                      title: Text(label),
                      subtitle: Text(
                          roleLabels[s['role']] ?? s['role'] ?? ''),
                      trailing: active
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF27AE60))
                          : const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        ws.switchTo(
                          uid: s['uid'],
                          role: s['role'] ?? 'view',
                          name: label,
                        );
                        db.activeWorkspaceUid = s['uid'];
                        Navigator.pop(context);
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
      ),
    );
  }
}
