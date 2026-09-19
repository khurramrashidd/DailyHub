import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../services/db_service.dart';
import '../widgets/common.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  int _streak(Map history) {
    int streak = 0;
    var day = DateTime.now();
    while (history[_key(day)] == true) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    final todayKey = _key(DateTime.now());
    return Scaffold(
      appBar: GradientAppBar(title: Text(context.t('habits'))),
      body: ContentWidth(
        child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.stream('habits'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final habits = snap.data!;
          if (habits.isEmpty) {
            return EmptyState(
                icon: Icons.local_fire_department,
                message: context.t('nothing_here'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: habits.length,
            itemBuilder: (context, i) {
              final h = habits[i];
              final history = (h['history'] is Map)
                  ? Map<String, dynamic>.from(h['history'])
                  : <String, dynamic>{};
              final doneToday = history[todayKey] == true;
              final streak = _streak(history);
              return Card(
                child: ListTile(
                  onTap: () => _edit(context, db, existing: h),
                  leading: CircleAvatar(
                    backgroundColor: doneToday
                        ? const Color(0xFFF39C12)
                        : Colors.grey.shade300,
                    child: Icon(Icons.local_fire_department,
                        color: doneToday ? Colors.white : Colors.grey),
                  ),
                  title: Text(h['name'] ?? ''),
                  subtitle: Text('$streak day ${context.t('streak')} 🔥'),
                  trailing: Wrap(
                    spacing: 0,
                    children: [
                      IconButton(
                        icon: Icon(
                          doneToday
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color: const Color(0xFF27AE60),
                        ),
                        onPressed: () {
                          history[todayKey] = !doneToday;
                          db.update('habits', h['id'], {'history': history});
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') {
                            _edit(context, db, existing: h);
                          } else if (v == 'delete') {
                            deleteWithUndo(
                              context,
                              collection: 'habits',
                              id: h['id'],
                              data: h,
                              label: 'Habit deleted',
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'edit', child: Text(context.t('edit'))),
                          PopupMenuItem(
                              value: 'delete',
                              child: Text(context.t('delete'))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'habitFab',
        onPressed: () => _edit(context, db),
        icon: const Icon(Icons.add),
        label: Text(context.t('add')),
      ),
    );
  }

  /// Shared dialog for both Add and Edit (rename). Pass [existing] to edit.
  void _edit(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final c = TextEditingController(text: existing?['name'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null
            ? context.t('habits')
            : '${context.t('edit')} ${context.t('habits')}'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              hintText: 'e.g. Drink 2L water, Read 10 pages'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.t('cancel'))),
          GradientButton(
            onPressed: () async {
              if (c.text.trim().isEmpty) return;
              if (existing != null) {
                final data = Map<String, dynamic>.from(existing)
                  ..['name'] = c.text.trim();
                await saveWithUndo(
                  ctx,
                  collection: 'habits',
                  id: existing['id'],
                  previousData: existing,
                  newData: data,
                  label: 'Habit updated',
                );
              } else {
                await db.add('habits', {
                  'name': c.text.trim(),
                  'history': {},
                  'createdAt': DateTime.now().toIso8601String(),
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing == null ? context.t('add') : context.t('save')),
          ),
        ],
      ),
    );
  }
}
