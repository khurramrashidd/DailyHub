import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    return Scaffold(
      appBar: GradientAppBar(title: Text(context.t('reminders'))),
      body: ContentWidth(
        child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.stream('reminders'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rem = snap.data!
            ..sort((a, b) => (a['when'] ?? '').compareTo(b['when'] ?? ''));
          if (rem.isEmpty) {
            return EmptyState(
                icon: Icons.alarm, message: context.t('nothing_here'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rem.length,
            itemBuilder: (context, i) {
              final r = rem[i];
              final when = DateTime.tryParse(r['when'] ?? '');
              final past = when != null && when.isBefore(DateTime.now());
              return Card(
                child: ListTile(
                  onTap: () => _openForm(context, db, existing: r),
                  leading: Icon(Icons.alarm,
                      color: past
                          ? Colors.grey
                          : const Color(0xFFE74C3C)),
                  title: Text(r['title'] ?? ''),
                  subtitle: Text(when == null
                      ? ''
                      : '${DateFormat('EEE, d MMM • h:mm a').format(when)}'
                          '${(r['repeat'] ?? 'once') != 'once' ? ' • ${r['repeat']}' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () =>
                            _openForm(context, db, existing: r),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, db, r),
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
        heroTag: 'remFab',
        onPressed: () => _openForm(context, db),
        icon: const Icon(Icons.add),
        label: Text(context.t('add')),
      ),
    );
  }

  /// Delete with undo. Because a reminder drives a real OS notification, the
  /// generic undo helper isn't enough on its own — the notification must be
  /// cancelled on delete and rescheduled if the user presses undo.
  Future<void> _delete(
      BuildContext context, DbService db, Map<String, dynamic> r) async {
    await NotificationService.instance.cancel('rem_${r['id']}');
    final clean = Map<String, dynamic>.from(r)..remove('id');
    await db.remove('reminders', r['id']);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Reminder deleted'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            await db.set('reminders', r['id'], clean);
            final when = DateTime.tryParse(clean['when'] ?? '');
            if (when != null && when.isAfter(DateTime.now())) {
              await NotificationService.instance.scheduleAt(
                key: 'rem_${r['id']}',
                title: clean['title'] ?? '',
                body: 'Reminder',
                when: when,
              );
            }
          },
        ),
      ),
    );
  }

  /// Shared form for both Add and Edit. Pass [existing] to edit in place.
  void _openForm(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final titleC = TextEditingController(text: existing?['title'] ?? '');
    final existingWhen = existing != null
        ? DateTime.tryParse(existing['when'] ?? '')
        : null;
    DateTime date =
        existingWhen ?? DateTime.now().add(const Duration(hours: 1));
    TimeOfDay time = TimeOfDay.fromDateTime(date);
    String repeat = existing?['repeat'] ?? 'once';

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
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  existing == null
                      ? context.t('reminders')
                      : '${context.t('edit')} ${context.t('reminders')}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextField(
                controller: titleC,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    InputDecoration(labelText: context.t('title')),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('d MMM').format(date)),
                    onPressed: () async {
                      final d = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 1)),
                          lastDate: DateTime(2100));
                      if (d != null) setSheet(() => date = d);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(time.format(ctx)),
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: ctx, initialTime: time);
                      if (t != null) setSheet(() => time = t);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: repeat,
                decoration: InputDecoration(labelText: context.t('repeat')),
                items: [
                  DropdownMenuItem(
                      value: 'once', child: Text(context.t('once'))),
                  DropdownMenuItem(
                      value: 'daily', child: Text(context.t('daily'))),
                  DropdownMenuItem(
                      value: 'weekly', child: Text(context.t('weekly'))),
                  DropdownMenuItem(
                      value: 'monthly', child: Text(context.t('monthly'))),
                ],
                onChanged: (v) => repeat = v ?? 'once',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  onPressed: () async {
                    if (titleC.text.trim().isEmpty) return;
                    final when = DateTime(date.year, date.month, date.day,
                        time.hour, time.minute);
                    final data = {
                      'title': titleC.text.trim(),
                      'when': when.toIso8601String(),
                      'repeat': repeat,
                      'createdAt': existing?['createdAt'] ??
                          DateTime.now().toIso8601String(),
                    };

                    String id;
                    if (existing != null) {
                      id = existing['id'];
                      await saveWithUndo(
                        ctx,
                        collection: 'reminders',
                        id: id,
                        previousData: existing,
                        newData: data,
                        label: 'Reminder updated',
                      );
                    } else {
                      id = await db.add('reminders', data);
                    }

                    // (Re)schedule the notification at the new time.
                    await NotificationService.instance.cancel('rem_$id');
                    await NotificationService.instance.scheduleAt(
                      key: 'rem_$id',
                      title: titleC.text.trim(),
                      body: 'Reminder',
                      when: when,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(context.t('save')),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fires even when the app is closed.',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
