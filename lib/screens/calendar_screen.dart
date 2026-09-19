import '../widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../services/db_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _Event {
  final String title;
  final Color color;
  final IconData icon;
  _Event(this.title, this.color, this.icon);
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Map<String, List<_Event>> _build(
    List<Map<String, dynamic>> todos,
    List<Map<String, dynamic>> trips,
    List<Map<String, dynamic>> reminders,
  ) {
    final map = <String, List<_Event>>{};
    void put(String? iso, _Event e) {
      if (iso == null || iso.isEmpty) return;
      final d = DateTime.tryParse(iso);
      if (d == null) return;
      final k = _dayKey(d);
      map.putIfAbsent(k, () => []).add(e);
    }

    for (final t in todos) {
      if ((t['status'] ?? 'upcoming') == 'upcoming') {
        put(t['date'], _Event(t['title'] ?? 'Task',
            const Color(0xFF667EEA), Icons.check_circle_outline));
      }
    }
    for (final t in trips) {
      put(t['depDate'],
          _Event('${t['from']} → ${t['to']}', const Color(0xFF27AE60), Icons.flight));
    }
    for (final r in reminders) {
      put(r['when'],
          _Event(r['title'] ?? 'Reminder', const Color(0xFFE74C3C), Icons.alarm));
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    return Scaffold(
      appBar: GradientAppBar(title: Text(context.t('calendar'))),
      body: ContentWidth(
        child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.stream('todos', workspace: true),
        builder: (context, todoSnap) => StreamBuilder<List<Map<String, dynamic>>>(
          stream: db.stream('trips', workspace: true),
          builder: (context, tripSnap) =>
              StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.stream('reminders'),
            builder: (context, remSnap) {
              final events = _build(
                todoSnap.data ?? [],
                tripSnap.data ?? [],
                remSnap.data ?? [],
              );
              final dayEvents = events[_dayKey(_selected)] ?? [];
              return Column(
                children: [
                  Card(
                    margin: const EdgeInsets.all(12),
                    child: TableCalendar(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2100),
                      focusedDay: _focused,
                      selectedDayPredicate: (d) => isSameDay(d, _selected),
                      calendarFormat: CalendarFormat.month,
                      onDaySelected: (sel, foc) => setState(() {
                        _selected = sel;
                        _focused = foc;
                      }),
                      eventLoader: (d) => events[_dayKey(d)] ?? [],
                      headerStyle: const HeaderStyle(
                          formatButtonVisible: false, titleCentered: true),
                      calendarStyle: const CalendarStyle(
                        markerDecoration: BoxDecoration(
                            color: Color(0xFF764BA2), shape: BoxShape.circle),
                        todayDecoration: BoxDecoration(
                            color: Color(0xFF667EEA), shape: BoxShape.circle),
                        selectedDecoration: BoxDecoration(
                            color: Color(0xFF764BA2), shape: BoxShape.circle),
                      ),
                    ),
                  ),
                  Expanded(
                    child: dayEvents.isEmpty
                        ? Center(
                            child: Text(context.t('nothing_here'),
                                style:
                                    TextStyle(color: Colors.grey.shade500)))
                        : ListView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            children: dayEvents
                                .map((e) => Card(
                                      child: ListTile(
                                        leading: Icon(e.icon, color: e.color),
                                        title: Text(e.title),
                                      ),
                                    ))
                                .toList(),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      ),
    );
  }
}
