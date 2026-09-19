import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/responsive.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';

/// Work Hub — meetings with notes and action items that can be promoted
/// into real tasks, plus follow-ups.
class WorkScreen extends StatelessWidget {
  const WorkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    return Scaffold(
      appBar: const GradientAppBar(title: Text('Work Hub')),
      body: ContentWidth(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: db.stream('meetings'),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data!
              ..sort((a, b) => (b['at'] ?? '').compareTo(a['at'] ?? ''));
            if (all.isEmpty) {
              return const EmptyState(
                  icon: Icons.work_outline,
                  message: 'No meetings yet');
            }
            final now = DateTime.now();
            final upcoming = all.where((m) {
              final d = DateTime.tryParse(m['at'] ?? '');
              return d != null && d.isAfter(now);
            }).toList()
              ..sort((a, b) => (a['at'] ?? '').compareTo(b['at'] ?? ''));
            final past = all.where((m) {
              final d = DateTime.tryParse(m['at'] ?? '');
              return d == null || !d.isAfter(now);
            }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              children: [
                if (upcoming.isNotEmpty)
                  const SectionHeader('Upcoming',
                      color: Color(0xFF27AE60)),
                ...upcoming.map((m) => _card(context, db, m)),
                if (past.isNotEmpty)
                  const SectionHeader('Past', color: Color(0xFF7F8C8D)),
                ...past.map((m) => _card(context, db, m)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'workFab',
        onPressed: () => _form(context, db),
        icon: const Icon(Icons.add),
        label: const Text('Meeting'),
      ),
    );
  }

  List<Map<String, dynamic>> _actions(Map<String, dynamic> m) {
    final raw = m['actions'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Widget _card(BuildContext context, DbService db, Map<String, dynamic> m) {
    final at = DateTime.tryParse(m['at'] ?? '');
    final actions = _actions(m);
    final done = actions.where((a) => a['done'] == true).length;
    final controller = TextEditingController();

    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF34495E),
            child: Icon(Icons.groups, color: Colors.white, size: 18),
          ),
          title: Text(m['title'] ?? ''),
          subtitle: Text([
            if (at != null) DateFormat('d MMM, h:mm a').format(at),
            if (actions.isNotEmpty) '☑ $done/${actions.length}',
          ].join(' • ')),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                _form(context, db, existing: m);
              } else {
                await NotificationService.instance.cancel('mtg_${m['id']}');
                if (!context.mounted) return;
                await deleteWithUndo(
                  context,
                  collection: 'meetings',
                  id: m['id'],
                  data: m,
                  label: 'Meeting deleted',
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((m['notes'] ?? '').toString().isNotEmpty) ...[
                    Text(m['notes'],
                        style: TextStyle(color: Colors.grey.shade700)),
                    const Divider(height: 20),
                  ],
                  const Text('Action items',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  ...actions.asMap().entries.map((e) {
                    final i = e.key;
                    final a = e.value;
                    return Row(
                      children: [
                        Checkbox(
                          value: a['done'] == true,
                          onChanged: (v) {
                            final updated = [...actions];
                            updated[i] = {...a, 'done': v ?? false};
                            db.update(
                                'meetings', m['id'], {'actions': updated});
                          },
                        ),
                        Expanded(
                          child: Text(a['title'] ?? '',
                              style: TextStyle(
                                  fontSize: 14,
                                  decoration: a['done'] == true
                                      ? TextDecoration.lineThrough
                                      : null)),
                        ),
                        IconButton(
                          tooltip: 'Send to Tasks',
                          icon: const Icon(Icons.playlist_add, size: 18),
                          onPressed: () async {
                            await db.add(
                                'todos',
                                {
                                  'title': a['title'] ?? '',
                                  'desc': 'From meeting: ${m['title']}',
                                  'date': '',
                                  'time': '',
                                  'priority': 'Medium',
                                  'repeat': 'none',
                                  'status': 'upcoming',
                                  'subtasks': [],
                                },
                                workspace: true);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Added to Tasks')));
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            final updated = [...actions]..removeAt(i);
                            db.update(
                                'meetings', m['id'], {'actions': updated});
                          },
                        ),
                      ],
                    );
                  }),
                  TextField(
                    controller: controller,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Add an action item...',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isEmpty) return;
                      final updated = [
                        ...actions,
                        {'title': v.trim(), 'done': false}
                      ];
                      db.update('meetings', m['id'], {'actions': updated});
                      controller.clear();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _form(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final titleC = TextEditingController(text: existing?['title'] ?? '');
    final notesC = TextEditingController(text: existing?['notes'] ?? '');
    DateTime at = existing == null
        ? DateTime.now().add(const Duration(hours: 1))
        : (DateTime.tryParse(existing['at'] ?? '') ?? DateTime.now());
    TimeOfDay time = TimeOfDay.fromDateTime(at);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                  controller: titleC,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      const InputDecoration(labelText: 'Meeting title')),
              const SizedBox(height: 10),
              TextField(
                controller: notesC,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('d MMM').format(at)),
                    onPressed: () async {
                      final d = await showDatePicker(
                          context: ctx,
                          initialDate: at,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100));
                      if (d != null) {
                        setSheet(() => at = DateTime(
                            d.year, d.month, d.day, time.hour, time.minute));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(time.format(ctx)),
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: ctx, initialTime: time);
                      if (t != null) {
                        setSheet(() {
                          time = t;
                          at = DateTime(
                              at.year, at.month, at.day, t.hour, t.minute);
                        });
                      }
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  onPressed: () async {
                    if (titleC.text.trim().isEmpty) return;
                    final data = {
                      'title': titleC.text.trim(),
                      'notes': notesC.text.trim(),
                      'at': at.toIso8601String(),
                      'actions': existing?['actions'] ?? [],
                    };
                    String id;
                    if (existing != null) {
                      id = existing['id'];
                      await saveWithUndo(
                        ctx,
                        collection: 'meetings',
                        id: id,
                        previousData: existing,
                        newData: data,
                        label: 'Meeting updated',
                      );
                    } else {
                      id = await db.add('meetings', data);
                    }
                    // Remind 15 minutes before.
                    await NotificationService.instance.cancel('mtg_$id');
                    await NotificationService.instance.scheduleAt(
                      key: 'mtg_$id',
                      title: 'Meeting soon: ${titleC.text.trim()}',
                      body: DateFormat('h:mm a').format(at),
                      when: at.subtract(const Duration(minutes: 15)),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
