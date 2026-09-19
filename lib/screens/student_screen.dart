import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';

/// Student Hub — timetable, assignments, attendance and CGPA in one place.
class StudentScreen extends StatelessWidget {
  const StudentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.brandGradient),
          ),
          title: const Text('Student Hub'),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Timetable'),
              Tab(text: 'Assignments'),
              Tab(text: 'Attendance'),
              Tab(text: 'CGPA'),
            ],
          ),
        ),
        body: const ContentWidth(
          child: TabBarView(
            children: [
              _TimetableTab(),
              _AssignmentsTab(),
              _AttendanceTab(),
              _CgpaTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Timetable

class _TimetableTab extends StatefulWidget {
  const _TimetableTab();

  @override
  State<_TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<_TimetableTab> {
  static const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  late String _day;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().weekday; // 1 = Monday
    _day = today >= 1 && today <= 6 ? days[today - 1] : 'Mon';
  }

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: days
                  .map((d) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(d),
                          selected: _day == d,
                          onSelected: (_) => setState(() => _day = d),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: db.stream('timetable'),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final classes = snap.data!
                    .where((c) => c['day'] == _day)
                    .toList()
                  ..sort((a, b) =>
                      (a['start'] ?? '').compareTo(b['start'] ?? ''));
                if (classes.isEmpty) {
                  return const EmptyState(
                      icon: Icons.school_outlined,
                      message: 'No classes on this day');
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: classes.length,
                  itemBuilder: (context, i) {
                    final c = classes[i];
                    return Card(
                      child: ListTile(
                        onTap: () => _form(context, db, existing: c),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          child: const Icon(Icons.menu_book,
                              color: AppColors.primary, size: 18),
                        ),
                        title: Text(c['subject'] ?? ''),
                        subtitle: Text(
                            '${c['start'] ?? ''} - ${c['end'] ?? ''}'
                            '${(c['room'] ?? '').toString().isEmpty ? '' : ' • ${c['room']}'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => deleteWithUndo(
                            context,
                            collection: 'timetable',
                            id: c['id'],
                            data: c,
                            label: 'Class removed',
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ttFab',
        onPressed: () => _form(context, db),
        icon: const Icon(Icons.add),
        label: const Text('Class'),
      ),
    );
  }

  void _form(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final subjectC = TextEditingController(text: existing?['subject'] ?? '');
    final roomC = TextEditingController(text: existing?['room'] ?? '');
    String day = existing?['day'] ?? _day;
    String start = existing?['start'] ?? '09:00';
    String end = existing?['end'] ?? '10:00';

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
                  controller: subjectC,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: 10),
              TextField(
                  controller: roomC,
                  decoration:
                      const InputDecoration(labelText: 'Room (optional)')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: day,
                decoration: const InputDecoration(labelText: 'Day'),
                items: _TimetableTabState.days
                    .map((d) =>
                        DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => day = v ?? 'Mon',
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: ctx,
                          initialTime: _parse(start));
                      if (t != null) {
                        setSheet(() => start = _fmt(t));
                      }
                    },
                    child: Text('Start $start'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: ctx, initialTime: _parse(end));
                      if (t != null) setSheet(() => end = _fmt(t));
                    },
                    child: Text('End $end'),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  onPressed: () async {
                    if (subjectC.text.trim().isEmpty) return;
                    final data = {
                      'subject': subjectC.text.trim(),
                      'room': roomC.text.trim(),
                      'day': day,
                      'start': start,
                      'end': end,
                    };
                    if (existing != null) {
                      await saveWithUndo(
                        ctx,
                        collection: 'timetable',
                        id: existing['id'],
                        previousData: existing,
                        newData: data,
                        label: 'Class updated',
                      );
                    } else {
                      await db.add('timetable', data);
                    }
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

  static TimeOfDay _parse(String s) {
    final p = s.split(':');
    return TimeOfDay(
        hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p.last) ?? 0);
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// -------------------------------------------------------------- Assignments

class _AssignmentsTab extends StatelessWidget {
  const _AssignmentsTab();

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.stream('assignments'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!
            ..sort((a, b) => (a['due'] ?? '9999').compareTo(b['due'] ?? '9999'));
          if (items.isEmpty) {
            return const EmptyState(
                icon: Icons.assignment_outlined,
                message: 'No assignments yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final a = items[i];
              final due = DateTime.tryParse(a['due'] ?? '');
              final done = a['done'] == true;
              final overdue =
                  !done && due != null && due.isBefore(DateTime.now());
              final daysLeft =
                  due == null ? null : due.difference(DateTime.now()).inDays;
              return Card(
                child: ListTile(
                  onTap: () => _form(context, db, existing: a),
                  leading: IconButton(
                    icon: Icon(
                        done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: done
                            ? const Color(0xFF27AE60)
                            : overdue
                                ? const Color(0xFFE74C3C)
                                : Colors.grey),
                    onPressed: () =>
                        db.update('assignments', a['id'], {'done': !done}),
                  ),
                  title: Text(a['title'] ?? '',
                      style: TextStyle(
                          decoration:
                              done ? TextDecoration.lineThrough : null)),
                  subtitle: Text([
                    if ((a['subject'] ?? '').toString().isNotEmpty)
                      a['subject'],
                    if (due != null) DateFormat('d MMM').format(due),
                    if (daysLeft != null && !done)
                      overdue
                          ? 'overdue'
                          : daysLeft == 0
                              ? 'due today'
                              : '$daysLeft days left',
                  ].join(' • '),
                      style: TextStyle(
                          color: overdue ? const Color(0xFFE74C3C) : null,
                          fontWeight:
                              overdue ? FontWeight.w600 : FontWeight.normal)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await NotificationService.instance
                          .cancel('asg_${a['id']}');
                      if (!context.mounted) return;
                      await deleteWithUndo(
                        context,
                        collection: 'assignments',
                        id: a['id'],
                        data: a,
                        label: 'Assignment deleted',
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'asgFab',
        onPressed: () => _form(context, db),
        icon: const Icon(Icons.add),
        label: const Text('Assignment'),
      ),
    );
  }

  void _form(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final titleC = TextEditingController(text: existing?['title'] ?? '');
    final subjectC = TextEditingController(text: existing?['subject'] ?? '');
    DateTime? due = existing == null
        ? null
        : DateTime.tryParse(existing['due'] ?? '');

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
                  decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 10),
              TextField(
                  controller: subjectC,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(due == null
                    ? 'Due date'
                    : DateFormat('d MMM yyyy').format(due!)),
                onPressed: () async {
                  final d = await showDatePicker(
                      context: ctx,
                      initialDate: due ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100));
                  if (d != null) setSheet(() => due = d);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  onPressed: () async {
                    if (titleC.text.trim().isEmpty) return;
                    final data = {
                      'title': titleC.text.trim(),
                      'subject': subjectC.text.trim(),
                      'due': due == null
                          ? ''
                          : DateFormat('yyyy-MM-dd').format(due!),
                      'done': existing?['done'] ?? false,
                    };
                    String id;
                    if (existing != null) {
                      id = existing['id'];
                      await saveWithUndo(
                        ctx,
                        collection: 'assignments',
                        id: id,
                        previousData: existing,
                        newData: data,
                        label: 'Assignment updated',
                      );
                    } else {
                      id = await db.add('assignments', data);
                    }
                    // Remind the evening before the due date.
                    await NotificationService.instance.cancel('asg_$id');
                    if (due != null) {
                      await NotificationService.instance.scheduleAt(
                        key: 'asg_$id',
                        title: 'Assignment due tomorrow',
                        body: titleC.text.trim(),
                        when: DateTime(due!.year, due!.month, due!.day, 18)
                            .subtract(const Duration(days: 1)),
                      );
                    }
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

// --------------------------------------------------------------- Attendance

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab();

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.stream('attendance'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final subjects = snap.data!;
          if (subjects.isEmpty) {
            return const EmptyState(
                icon: Icons.fact_check_outlined,
                message: 'Add a subject to track attendance');
          }

          final totalAttended = subjects.fold<int>(
              0, (s, e) => s + ((e['attended'] ?? 0) as num).toInt());
          final totalHeld = subjects.fold<int>(
              0, (s, e) => s + ((e['total'] ?? 0) as num).toInt());
          final overall =
              totalHeld == 0 ? 0.0 : totalAttended / totalHeld * 100;

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              Card(
                color: (overall >= 75 ? const Color(0xFF27AE60) : const Color(0xFFE74C3C))
                    .withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text('${overall.toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: overall >= 75
                                  ? const Color(0xFF27AE60)
                                  : const Color(0xFFE74C3C))),
                      Text('Overall • $totalAttended of $totalHeld classes',
                          style: TextStyle(color: Colors.grey.shade700)),
                      if (overall < 75 && totalHeld > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Below the usual 75% requirement',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...subjects.map((s) {
                final attended = ((s['attended'] ?? 0) as num).toInt();
                final total = ((s['total'] ?? 0) as num).toInt();
                final pct = total == 0 ? 0.0 : attended / total * 100;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(s['subject'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                            Text('${pct.toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: pct >= 75
                                        ? const Color(0xFF27AE60)
                                        : const Color(0xFFE74C3C))),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => deleteWithUndo(
                                context,
                                collection: 'attendance',
                                id: s['id'],
                                data: s,
                                label: 'Subject removed',
                              ),
                            ),
                          ],
                        ),
                        Text('$attended / $total classes',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Present'),
                                onPressed: () => db.update(
                                    'attendance', s['id'], {
                                  'attended': attended + 1,
                                  'total': total + 1
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Absent'),
                                onPressed: () => db.update('attendance',
                                    s['id'], {'total': total + 1}),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'attFab',
        onPressed: () => _add(context, db),
        icon: const Icon(Icons.add),
        label: const Text('Subject'),
      ),
    );
  }

  void _add(BuildContext context, DbService db) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Track a subject'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Subject name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          GradientButton(
            onPressed: () async {
              if (c.text.trim().isEmpty) return;
              await db.add('attendance',
                  {'subject': c.text.trim(), 'attended': 0, 'total': 0});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- CGPA

class _CgpaTab extends StatelessWidget {
  const _CgpaTab();

  /// 10-point scale grade values, as used by Indian universities.
  static const grades = {
    'O (10)': 10.0,
    'A+ (9)': 9.0,
    'A (8)': 8.0,
    'B+ (7)': 7.0,
    'B (6)': 6.0,
    'C (5)': 5.0,
    'P (4)': 4.0,
    'F (0)': 0.0,
  };

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.stream('subjects'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final subjects = snap.data!;
          double totalPoints = 0;
          double totalCredits = 0;
          for (final s in subjects) {
            final credits = ((s['credits'] ?? 0) as num).toDouble();
            final grade = ((s['gradePoint'] ?? 0) as num).toDouble();
            totalPoints += credits * grade;
            totalCredits += credits;
          }
          final cgpa = totalCredits == 0 ? 0.0 : totalPoints / totalCredits;

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              Card(
                color: AppColors.primary.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(cgpa.toStringAsFixed(2),
                          style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                      Text(
                          'CGPA • ${totalCredits.toStringAsFixed(0)} credits',
                          style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (subjects.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('Add subjects with credits and grades',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ),
              ...subjects.map((s) => Card(
                    child: ListTile(
                      onTap: () => _form(context, db, existing: s),
                      title: Text(s['name'] ?? ''),
                      subtitle: Text(
                          '${((s['credits'] ?? 0) as num).toStringAsFixed(0)} credits • ${s['grade'] ?? ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => deleteWithUndo(
                          context,
                          collection: 'subjects',
                          id: s['id'],
                          data: s,
                          label: 'Subject removed',
                        ),
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'cgpaFab',
        onPressed: () => _form(context, db),
        icon: const Icon(Icons.add),
        label: const Text('Subject'),
      ),
    );
  }

  void _form(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final nameC = TextEditingController(text: existing?['name'] ?? '');
    final creditsC = TextEditingController(
        text: existing == null ? '' : '${existing['credits'] ?? ''}');
    String grade = existing?['grade'] ?? 'A (8)';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
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
                controller: nameC,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Subject name')),
            const SizedBox(height: 10),
            TextField(
                controller: creditsC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Credits')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: grade,
              decoration: const InputDecoration(labelText: 'Grade'),
              items: grades.keys
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => grade = v ?? 'A (8)',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                onPressed: () async {
                  final credits = double.tryParse(creditsC.text.trim());
                  if (nameC.text.trim().isEmpty || credits == null) return;
                  final data = {
                    'name': nameC.text.trim(),
                    'credits': credits,
                    'grade': grade,
                    'gradePoint': grades[grade] ?? 0.0,
                  };
                  if (existing != null) {
                    await saveWithUndo(
                      ctx,
                      collection: 'subjects',
                      id: existing['id'],
                      previousData: existing,
                      newData: data,
                      label: 'Subject updated',
                    );
                  } else {
                    await db.add('subjects', data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
