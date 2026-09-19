import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../services/db_service.dart';
import '../widgets/common.dart';

/// The signature DailyHub view: everything happening on a given day, from
/// every module, arranged chronologically on one spine.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineEntry {
  final DateTime? at;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool done;

  _TimelineEntry({
    required this.at,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.done = false,
  });
}

class _TimelineScreenState extends State<TimelineScreen> {
  DateTime _day = DateTime.now();

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _combine(String? date, String? time) {
    if (date == null || date.isEmpty) return null;
    final d = DateTime.tryParse(date);
    if (d == null) return null;
    if (time != null && time.contains(':')) {
      final p = time.split(':');
      return DateTime(d.year, d.month, d.day,
          int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0);
    }
    return DateTime(d.year, d.month, d.day);
  }

  List<_TimelineEntry> _build(
    List<Map<String, dynamic>> todos,
    List<Map<String, dynamic>> trips,
    List<Map<String, dynamic>> reminders,
    List<Map<String, dynamic>> expenses,
  ) {
    final out = <_TimelineEntry>[];

    for (final t in todos) {
      final at = _combine(t['date'], t['time']);
      if (at == null || !_sameDay(at, _day)) continue;
      out.add(_TimelineEntry(
        at: (t['time'] ?? '').toString().isEmpty ? null : at,
        title: t['title'] ?? '',
        subtitle: 'Task',
        icon: Icons.check_circle_outline,
        color: const Color(0xFF667EEA),
        done: t['status'] == 'completed',
      ));
    }

    for (final t in trips) {
      final at = _combine(t['depDate'], t['depTime']);
      if (at == null || !_sameDay(at, _day)) continue;
      out.add(_TimelineEntry(
        at: (t['depTime'] ?? '').toString().isEmpty ? null : at,
        title: '${t['from']} → ${t['to']}',
        subtitle: switch (t['type']) {
          'flight' => 'Flight',
          'train' => 'Train',
          'bus' => 'Bus',
          _ => 'Travel',
        },
        icon: switch (t['type']) {
          'flight' => Icons.flight,
          'train' => Icons.train,
          'bus' => Icons.directions_bus,
          _ => Icons.directions_car,
        },
        color: const Color(0xFF27AE60),
      ));
    }

    for (final r in reminders) {
      final at = DateTime.tryParse(r['when'] ?? '');
      if (at == null || !_sameDay(at, _day)) continue;
      out.add(_TimelineEntry(
        at: at,
        title: r['title'] ?? '',
        subtitle: 'Reminder',
        icon: Icons.alarm,
        color: const Color(0xFFE74C3C),
      ));
    }

    for (final e in expenses) {
      final at = _combine(e['date'], null);
      if (at == null || !_sameDay(at, _day)) continue;
      final amt = ((e['amount'] ?? 0) as num).toStringAsFixed(0);
      out.add(_TimelineEntry(
        at: null,
        title: (e['note'] ?? '').toString().isNotEmpty
            ? e['note']
            : e['category'] ?? 'Expense',
        subtitle: '₹$amt • ${e['category'] ?? ''}',
        icon: Icons.currency_rupee,
        color: const Color(0xFF16A085),
      ));
    }

    // Timed entries first in clock order, untimed ones after.
    out.sort((a, b) {
      if (a.at == null && b.at == null) return 0;
      if (a.at == null) return 1;
      if (b.at == null) return -1;
      return a.at!.compareTo(b.at!);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    final isToday = _sameDay(_day, DateTime.now());

    return Scaffold(
      appBar: GradientAppBar(
        title: Text(isToday ? context.t('today') : 'Timeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _day,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _day = d);
            },
          ),
        ],
      ),
      body: ContentWidth(
        child: Column(
          children: [
            // Day stepper
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(
                        () => _day = _day.subtract(const Duration(days: 1))),
                  ),
                  Text(DateFormat('EEEE, d MMMM').format(_day),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(
                        () => _day = _day.add(const Duration(days: 1))),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: db.stream('todos', workspace: true),
                builder: (context, todoSnap) =>
                    StreamBuilder<List<Map<String, dynamic>>>(
                  stream: db.stream('trips', workspace: true),
                  builder: (context, tripSnap) =>
                      StreamBuilder<List<Map<String, dynamic>>>(
                    stream: db.stream('reminders'),
                    builder: (context, remSnap) =>
                        StreamBuilder<List<Map<String, dynamic>>>(
                      stream: db.stream('expenses'),
                      builder: (context, expSnap) {
                        final entries = _build(
                          todoSnap.data ?? [],
                          tripSnap.data ?? [],
                          remSnap.data ?? [],
                          expSnap.data ?? [],
                        );
                        if (entries.isEmpty) {
                          return EmptyState(
                            icon: Icons.timeline,
                            message: isToday
                                ? 'Nothing scheduled today.\nTap + to add something.'
                                : 'Nothing on this day.',
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: entries.length,
                          itemBuilder: (context, i) =>
                              _row(entries[i], i == entries.length - 1),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(_TimelineEntry e, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                e.at == null ? '—' : DateFormat('HH:mm').format(e.at!),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700),
              ),
            ),
          ),
          // Spine with dot
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 18),
                height: 14,
                width: 14,
                decoration: BoxDecoration(
                  color: e.done ? Colors.grey.shade400 : e.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: Colors.grey.shade300),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(e.icon, color: e.color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: e.done
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: e.done ? Colors.grey : null,
                              )),
                          Text(e.subtitle,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
