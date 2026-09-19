import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import '../services/db_service.dart';
import '../widgets/common.dart';

/// Morning and night briefings — a short, readable summary of the day
/// ahead or the day just finished. Switches automatically based on the
/// time of day, and can be toggled manually.
class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  late bool _night;

  @override
  void initState() {
    super.initState();
    _night = DateTime.now().hour >= 18;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _due(Map<String, dynamic> t) {
    final date = (t['date'] ?? '') as String;
    if (date.isEmpty) return null;
    return DateTime.tryParse(date);
  }

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final name = FirebaseAuth.instance.currentUser?.displayName ??
        FirebaseAuth.instance.currentUser?.email?.split('@').first ??
        '';

    return Scaffold(
      appBar: GradientAppBar(
        title: Text(_night ? 'Daily Review' : 'Morning Briefing'),
        actions: [
          IconButton(
            tooltip: _night ? 'Show morning briefing' : 'Show daily review',
            icon: Icon(_night ? Icons.wb_sunny_outlined : Icons.nightlight_round),
            onPressed: () => setState(() => _night = !_night),
          ),
        ],
      ),
      body: ContentWidth(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: db.stream('todos', workspace: true),
          builder: (context, todoSnap) => StreamBuilder<
              List<Map<String, dynamic>>>(
            stream: db.stream('trips', workspace: true),
            builder: (context, tripSnap) =>
                StreamBuilder<List<Map<String, dynamic>>>(
              stream: db.stream('reminders'),
              builder: (context, remSnap) => StreamBuilder<
                  List<Map<String, dynamic>>>(
                stream: db.stream('expenses'),
                builder: (context, expSnap) {
                  final todos = todoSnap.data ?? [];
                  final trips = tripSnap.data ?? [];
                  final reminders = remSnap.data ?? [];
                  final expenses = expSnap.data ?? [];

                  final target = _night ? now : now;
                  final todayTodos = todos
                      .where((t) =>
                          _due(t) != null && _sameDay(_due(t)!, target))
                      .toList();
                  final doneToday = todayTodos
                      .where((t) => t['status'] == 'completed')
                      .length;
                  final tomorrowTodos = todos
                      .where((t) =>
                          (t['status'] ?? 'upcoming') == 'upcoming' &&
                          _due(t) != null &&
                          _sameDay(_due(t)!, tomorrow))
                      .toList();
                  final overdue = todos
                      .where((t) =>
                          (t['status'] ?? 'upcoming') == 'upcoming' &&
                          _due(t) != null &&
                          _due(t)!.isBefore(
                              DateTime(now.year, now.month, now.day)))
                      .length;

                  final relevantTrips = trips
                      .where((t) {
                        final d = DateTime.tryParse(t['depDate'] ?? '');
                        return d != null &&
                            _sameDay(d, _night ? tomorrow : now);
                      })
                      .toList();

                  final relevantReminders = reminders.where((r) {
                    final d = DateTime.tryParse(r['when'] ?? '');
                    return d != null &&
                        _sameDay(d, _night ? tomorrow : now);
                  }).toList();

                  final spentToday = expenses
                      .where((e) {
                        final d = DateTime.tryParse(e['date'] ?? '');
                        return d != null && _sameDay(d, now);
                      })
                      .fold<double>(
                          0,
                          (s, e) =>
                              s + ((e['amount'] ?? 0) as num).toDouble());

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _night
                                  ? 'Good evening${name.isEmpty ? '' : ', $name'} 🌙'
                                  : 'Good morning${name.isEmpty ? '' : ', $name'} 👋',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, d MMMM').format(now),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (_night) ...[
                        _line(Icons.check_circle, 'Completed',
                            '$doneToday of ${todayTodos.length} tasks',
                            const Color(0xFF27AE60)),
                        if (overdue > 0)
                          _line(Icons.warning_amber, 'Overdue',
                              '$overdue task(s) need attention',
                              const Color(0xFFE74C3C)),
                        _line(Icons.currency_rupee, 'Spent today',
                            '₹${spentToday.toStringAsFixed(0)}',
                            const Color(0xFF16A085)),
                        const SizedBox(height: 8),
                        const SectionHeader('Tomorrow'),
                        _line(Icons.check_circle_outline, 'Tasks',
                            '${tomorrowTodos.length} scheduled',
                            const Color(0xFF667EEA)),
                        if (relevantTrips.isNotEmpty)
                          _line(Icons.flight, 'Travel',
                              '${relevantTrips.first['from']} → ${relevantTrips.first['to']}',
                              const Color(0xFF27AE60)),
                        if (relevantReminders.isNotEmpty)
                          _line(Icons.alarm, 'Reminders',
                              '${relevantReminders.length} set',
                              const Color(0xFFE74C3C)),
                      ] else ...[
                        _line(Icons.check_circle_outline, 'Tasks today',
                            '${todayTodos.where((t) => t['status'] != 'completed').length} to do',
                            const Color(0xFF667EEA)),
                        if (overdue > 0)
                          _line(Icons.warning_amber, 'Overdue',
                              '$overdue from earlier',
                              const Color(0xFFE74C3C)),
                        if (relevantReminders.isNotEmpty)
                          _line(Icons.alarm, 'Reminders',
                              '${relevantReminders.length} today',
                              const Color(0xFFF39C12)),
                        if (relevantTrips.isNotEmpty)
                          _line(Icons.flight, 'Travel today',
                              '${relevantTrips.first['from']} → ${relevantTrips.first['to']}',
                              const Color(0xFF27AE60)),
                        const SizedBox(height: 8),
                        if (todayTodos.isEmpty && relevantReminders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Nothing scheduled. A clear day — use it well.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                      ],
                      const SizedBox(height: 60),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String label, String value, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
