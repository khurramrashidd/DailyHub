import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../core/workspace_provider.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';

/// Task filters. "Overdue" is the one people actually need and most
/// to-do apps bury.
enum TaskFilter { today, overdue, upcoming, completed, all }

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  TaskFilter _filter = TaskFilter.today;

  Color _priorityColor(String? p) => switch (p) {
        'High' => const Color(0xFFE74C3C),
        'Medium' => const Color(0xFFF39C12),
        'Low' => const Color(0xFF3498DB),
        _ => Colors.grey,
      };

  DateTime? _due(Map<String, dynamic> t) {
    final date = (t['date'] ?? '') as String;
    if (date.isEmpty) return null;
    final d = DateTime.tryParse(date);
    if (d == null) return null;
    final time = (t['time'] ?? '') as String;
    if (time.contains(':')) {
      final p = time.split(':');
      return DateTime(d.year, d.month, d.day,
          int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0);
    }
    return DateTime(d.year, d.month, d.day, 23, 59);
  }

  bool _isToday(DateTime? d) {
    if (d == null) return false;
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  List<Map<String, dynamic>> _apply(List<Map<String, dynamic>> all) {
    final now = DateTime.now();
    bool open(Map<String, dynamic> t) =>
        (t['status'] ?? 'upcoming') == 'upcoming';

    return switch (_filter) {
      TaskFilter.today => all.where((t) => open(t) && _isToday(_due(t))).toList(),
      TaskFilter.overdue => all
          .where((t) =>
              open(t) && _due(t) != null && _due(t)!.isBefore(now) &&
              !_isToday(_due(t)))
          .toList(),
      TaskFilter.upcoming => all
          .where((t) =>
              open(t) && (_due(t) == null || _due(t)!.isAfter(now)) &&
              !_isToday(_due(t)))
          .toList(),
      TaskFilter.completed =>
        all.where((t) => t['status'] == 'completed').toList(),
      TaskFilter.all => all,
    };
  }

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    final ws = context.watch<WorkspaceProvider>();

    return Scaffold(
      appBar: GradientAppBar(title: Text(context.t('todos'))),
      body: ContentWidth(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: db.stream('todos', workspace: true),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data!;
            all.sort((a, b) =>
                (a['date'] ?? '9999').compareTo(b['date'] ?? '9999'));

            final now = DateTime.now();
            final overdueCount = all
                .where((t) =>
                    (t['status'] ?? 'upcoming') == 'upcoming' &&
                    _due(t) != null &&
                    _due(t)!.isBefore(now) &&
                    !_isToday(_due(t)))
                .length;

            final shown = _apply(all);

            return Column(
              children: [
                _filterBar(overdueCount),
                Expanded(
                  child: shown.isEmpty
                      ? EmptyState(
                          icon: Icons.check_circle_outline,
                          message: switch (_filter) {
                            TaskFilter.today => 'Nothing due today 🎉',
                            TaskFilter.overdue => 'Nothing overdue 👌',
                            TaskFilter.completed => 'Nothing completed yet',
                            _ => context.t('nothing_here'),
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: shown.length,
                          itemBuilder: (context, i) =>
                              _tile(context, db, shown[i], ws),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: ws.canAdd
          ? FloatingActionButton.extended(
              heroTag: 'todoFab',
              onPressed: () => _openForm(context, db),
              icon: const Icon(Icons.add),
              label: Text(context.t('add')),
            )
          : null,
    );
  }

  Widget _filterBar(int overdueCount) {
    final labels = {
      TaskFilter.today: 'Today',
      TaskFilter.overdue: 'Overdue',
      TaskFilter.upcoming: 'Upcoming',
      TaskFilter.completed: 'Done',
      TaskFilter.all: 'All',
    };
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: labels.entries.map((e) {
          final selected = _filter == e.key;
          final isOverdue = e.key == TaskFilter.overdue && overdueCount > 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              label: Text(isOverdue
                  ? '${e.value} ($overdueCount)'
                  : e.value),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : isOverdue
                        ? const Color(0xFFE74C3C)
                        : null,
              ),
              selectedColor: isOverdue
                  ? const Color(0xFFE74C3C)
                  : const Color(0xFF667EEA),
              onSelected: (_) => setState(() => _filter = e.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _tile(BuildContext context, DbService db, Map<String, dynamic> t,
      WorkspaceProvider ws) {
    final status = t['status'] ?? 'upcoming';
    final priority = t['priority'] as String?;
    final due = _due(t);
    final overdue = due != null &&
        due.isBefore(DateTime.now()) &&
        status == 'upcoming';
    final subtasks = _subtasksOf(t);
    final doneCount = subtasks.where((s) => s['done'] == true).length;
    final repeat = (t['repeat'] ?? 'none') as String;

    return Card(
      child: Theme(
        // Removes the default divider lines from ExpansionTile.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: IconButton(
            icon: Icon(
              status == 'completed'
                  ? Icons.check_circle
                  : status == 'cancelled'
                      ? Icons.cancel
                      : Icons.radio_button_unchecked,
              color: _priorityColor(priority),
            ),
            onPressed: !ws.canAdd
                ? null
                : () => _complete(db, t, status == 'completed'),
          ),
          title: Text(t['title'] ?? '',
              style: TextStyle(
                decoration:
                    status == 'completed' ? TextDecoration.lineThrough : null,
              )),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((t['desc'] ?? '').toString().isNotEmpty)
                Text(t['desc'], maxLines: 2, overflow: TextOverflow.ellipsis),
              Wrap(
                spacing: 10,
                children: [
                  if (due != null)
                    Text(
                      DateFormat('d MMM, HH:mm').format(due),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            overdue ? FontWeight.w700 : FontWeight.normal,
                        color: overdue ? const Color(0xFFE74C3C) : null,
                      ),
                    ),
                  if (repeat != 'none')
                    Text('🔁 $repeat', style: const TextStyle(fontSize: 12)),
                  if (subtasks.isNotEmpty)
                    Text('☑ $doneCount/${subtasks.length}',
                        style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          trailing: !ws.canAdd
              ? null
              : PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      _openForm(context, db, existing: t);
                    } else if (v == 'delete') {
                      await NotificationService.instance
                          .cancel('todo_${t['id']}');
                      if (!context.mounted) return;
                      await deleteWithUndo(
                        context,
                        collection: 'todos',
                        id: t['id'],
                        data: t,
                        workspace: true,
                        label: 'Task deleted',
                      );
                    } else {
                      await db.update(
                          'todos', t['id'], {'status': v}, workspace: true);
                    }
                  },
                  itemBuilder: (_) => [
                    if (status != 'completed')
                      PopupMenuItem(
                          value: 'completed', child: Text(context.t('done'))),
                    if (status != 'cancelled')
                      PopupMenuItem(
                          value: 'cancelled',
                          child: Text(context.t('cancelled'))),
                    if (status != 'upcoming')
                      PopupMenuItem(
                          value: 'upcoming',
                          child: Text(context.t('upcoming'))),
                    if (ws.canEdit)
                      PopupMenuItem(
                          value: 'edit', child: Text(context.t('edit'))),
                    if (ws.canEdit)
                      PopupMenuItem(
                          value: 'delete', child: Text(context.t('delete'))),
                  ],
                ),
          children: [
            _subtaskSection(context, db, t, subtasks, ws),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _subtasksOf(Map<String, dynamic> t) {
    final raw = t['subtasks'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is Map) {
      return raw.values
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Widget _subtaskSection(BuildContext context, DbService db,
      Map<String, dynamic> t, List<Map<String, dynamic>> subtasks,
      WorkspaceProvider ws) {
    final controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...subtasks.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Row(
              children: [
                Checkbox(
                  value: s['done'] == true,
                  onChanged: !ws.canAdd
                      ? null
                      : (v) {
                          final updated = [...subtasks];
                          updated[i] = {...s, 'done': v ?? false};
                          db.update('todos', t['id'], {'subtasks': updated},
                              workspace: true);
                        },
                ),
                Expanded(
                  child: Text(s['title'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        decoration: s['done'] == true
                            ? TextDecoration.lineThrough
                            : null,
                        color: s['done'] == true ? Colors.grey : null,
                      )),
                ),
                if (ws.canEdit)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      final updated = [...subtasks]..removeAt(i);
                      db.update('todos', t['id'], {'subtasks': updated},
                          workspace: true);
                    },
                  ),
              ],
            );
          }),
          if (ws.canAdd)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Add a subtask...',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isEmpty) return;
                      final updated = [
                        ...subtasks,
                        {'title': v.trim(), 'done': false}
                      ];
                      db.update('todos', t['id'], {'subtasks': updated},
                          workspace: true);
                      controller.clear();
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Completing a recurring task rolls it forward instead of closing it.
  Future<void> _complete(
      DbService db, Map<String, dynamic> t, bool alreadyDone) async {
    final repeat = (t['repeat'] ?? 'none') as String;
    if (alreadyDone || repeat == 'none') {
      await db.update('todos', t['id'],
          {'status': alreadyDone ? 'upcoming' : 'completed'},
          workspace: true);
      return;
    }

    final due = _due(t) ?? DateTime.now();
    final next = switch (repeat) {
      'daily' => due.add(const Duration(days: 1)),
      'weekly' => due.add(const Duration(days: 7)),
      'monthly' => DateTime(due.year, due.month + 1, due.day, due.hour,
          due.minute),
      _ => due,
    };

    // Reset subtasks for the next occurrence.
    final subtasks = _subtasksOf(t)
        .map((s) => {...s, 'done': false})
        .toList();

    await db.update(
        'todos',
        t['id'],
        {
          'date': DateFormat('yyyy-MM-dd').format(next),
          'time': DateFormat('HH:mm').format(next),
          'subtasks': subtasks,
        },
        workspace: true);

    await NotificationService.instance.cancel('todo_${t['id']}');
    await NotificationService.instance.scheduleAt(
      key: 'todo_${t['id']}',
      title: 'Task due: ${t['title']}',
      body: t['desc'] ?? '',
      when: next,
    );
  }

  /// Shared form for both Add and Edit. Pass [existing] to edit in place.
  void _openForm(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final titleC = TextEditingController(text: existing?['title'] ?? '');
    final descC = TextEditingController(text: existing?['desc'] ?? '');
    DateTime? date = existing != null && (existing['date'] ?? '').isNotEmpty
        ? DateTime.tryParse(existing['date'])
        : null;
    TimeOfDay? time;
    if (existing != null && (existing['time'] ?? '').toString().contains(':')) {
      final parts = (existing['time'] as String).split(':');
      time = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0);
    }
    String priority = existing?['priority'] ?? 'Medium';
    String repeat = existing?['repeat'] ?? 'none';

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    existing == null
                        ? context.t('todos')
                        : '${context.t('edit')} ${context.t('todos')}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(
                  controller: titleC,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: context.t('title')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descC,
                  minLines: 1,
                  maxLines: 3,
                  decoration:
                      InputDecoration(labelText: context.t('description')),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(date == null
                            ? context.t('date')
                            : DateFormat('d MMM').format(date!)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: date ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setSheet(() => date = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text(time == null
                            ? context.t('time')
                            : time!.format(ctx)),
                        onPressed: () async {
                          final tm = await showTimePicker(
                              context: ctx,
                              initialTime: time ?? TimeOfDay.now());
                          if (tm != null) setSheet(() => time = tm);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: InputDecoration(labelText: context.t('priority')),
                  items: [
                    DropdownMenuItem(
                        value: 'Low', child: Text(context.t('low'))),
                    DropdownMenuItem(
                        value: 'Medium', child: Text(context.t('medium'))),
                    DropdownMenuItem(
                        value: 'High', child: Text(context.t('high'))),
                  ],
                  onChanged: (v) => priority = v ?? 'Medium',
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: repeat,
                  decoration: InputDecoration(labelText: context.t('repeat')),
                  items: [
                    const DropdownMenuItem(
                        value: 'none', child: Text('Does not repeat')),
                    DropdownMenuItem(
                        value: 'daily', child: Text(context.t('daily'))),
                    DropdownMenuItem(
                        value: 'weekly', child: Text(context.t('weekly'))),
                    DropdownMenuItem(
                        value: 'monthly', child: Text(context.t('monthly'))),
                  ],
                  onChanged: (v) => repeat = v ?? 'none',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    onPressed: () async {
                      if (titleC.text.trim().isEmpty) return;
                      final dateStr = date == null
                          ? ''
                          : DateFormat('yyyy-MM-dd').format(date!);
                      final timeStr = time == null
                          ? ''
                          : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
                      final data = {
                        'title': titleC.text.trim(),
                        'desc': descC.text.trim(),
                        'date': dateStr,
                        'time': timeStr,
                        'priority': priority,
                        'repeat': repeat,
                        'status': existing?['status'] ?? 'upcoming',
                        'subtasks': existing?['subtasks'] ?? [],
                      };

                      String id;
                      if (existing != null) {
                        id = existing['id'];
                        await saveWithUndo(
                          ctx,
                          collection: 'todos',
                          id: id,
                          previousData: existing,
                          newData: data,
                          workspace: true,
                          label: 'Task updated',
                        );
                      } else {
                        id = await db.add('todos', data, workspace: true);
                      }

                      await NotificationService.instance.cancel('todo_$id');
                      if (date != null && time != null) {
                        final when = DateTime(date!.year, date!.month,
                            date!.day, time!.hour, time!.minute);
                        await NotificationService.instance.scheduleAt(
                          key: 'todo_$id',
                          title: 'Task due: ${titleC.text.trim()}',
                          body: descC.text.trim(),
                          when: when,
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(context.t('save')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
