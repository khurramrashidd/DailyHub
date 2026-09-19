import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../services/db_service.dart';
import '../services/weather_service.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 12) return context.t('good_morning');
    if (h < 17) return context.t('good_afternoon');
    return context.t('good_evening');
  }

  bool _isToday(String? iso) {
    if (iso == null || iso.isEmpty) return false;
    final d = DateTime.tryParse(iso);
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    final name = FirebaseAuth.instance.currentUser?.displayName ??
        FirebaseAuth.instance.currentUser?.email?.split('@').first ??
        '';

    return Scaffold(
      appBar: GradientAppBar(
        title: Text(context.t('app_name')),
      ),
      body: ContentWidth(
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${_greeting(context)}${name.isNotEmpty ? ', $name' : ''} 👋',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800)),
          Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          const WeatherCard(),
          const SizedBox(height: 6),

          // Quick stat tiles
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.stream('todos', workspace: true),
            builder: (context, todoSnap) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: db.stream('trips', workspace: true),
                builder: (context, tripSnap) {
                  final todos = todoSnap.data ?? [];
                  final trips = tripSnap.data ?? [];
                  final pending = todos
                      .where((t) => (t['status'] ?? 'upcoming') == 'upcoming')
                      .length;
                  final dueToday = todos
                      .where((t) =>
                          (t['status'] ?? 'upcoming') == 'upcoming' &&
                          _isToday(t['date'] as String?))
                      .length;
                  final upcomingTrips = trips
                      .where(
                          (t) => (t['status'] ?? 'upcoming') == 'upcoming')
                      .length;
                  return Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          icon: Icons.today,
                          label: context.t('today'),
                          value: '$dueToday',
                          color: const Color(0xFFE74C3C),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          icon: Icons.check_circle_outline,
                          label: context.t('todos'),
                          value: '$pending',
                          color: const Color(0xFF667EEA),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          icon: Icons.flight_takeoff,
                          label: context.t('trips'),
                          value: '$upcomingTrips',
                          color: const Color(0xFF27AE60),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          SectionHeader('${context.t('today')} • ${context.t('todos')}'),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.stream('todos', workspace: true),
            builder: (context, snap) {
              final todos = (snap.data ?? [])
                  .where((t) =>
                      (t['status'] ?? 'upcoming') == 'upcoming' &&
                      _isToday(t['date'] as String?))
                  .toList();
              if (todos.isEmpty) {
                return const _MiniEmpty(text: 'No tasks due today. Enjoy!');
              }
              return Column(
                children: todos
                    .map((t) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.radio_button_unchecked),
                            title: Text(t['title'] ?? ''),
                            subtitle: (t['time'] ?? '').toString().isEmpty
                                ? null
                                : Text('${context.t('due')}: ${t['time']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.check_circle_outline,
                                  color: Color(0xFF27AE60)),
                              onPressed: () => db.update(
                                  'todos', t['id'], {'status': 'completed'}),
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),

          SectionHeader(
              '${context.t('upcoming')} • ${context.t('reminders')}',
              color: const Color(0xFFE74C3C)),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.stream('reminders'),
            builder: (context, snap) {
              final now = DateTime.now();
              final rem = (snap.data ?? [])
                  .where((r) {
                    final d = DateTime.tryParse(r['when'] ?? '');
                    return d != null && d.isAfter(now);
                  })
                  .toList()
                ..sort((a, b) => DateTime.parse(a['when'])
                    .compareTo(DateTime.parse(b['when'])));
              final top = rem.take(3).toList();
              if (top.isEmpty) {
                return const _MiniEmpty(text: 'No upcoming reminders.');
              }
              return Column(
                children: top.map((r) {
                  final d = DateTime.parse(r['when']);
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.alarm,
                          color: Color(0xFFE74C3C)),
                      title: Text(r['title'] ?? ''),
                      subtitle: Text(
                          DateFormat('EEE, d MMM • h:mm a').format(d)),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
      ),
    );
  }
}

class _MiniEmpty extends StatelessWidget {
  final String text;
  const _MiniEmpty({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text, style: TextStyle(color: Colors.grey.shade500)),
    );
  }
}

/// Compact weather line for the dashboard. Renders nothing at all when no
/// API key is configured, so the dashboard stays clean either way.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  WeatherInfo? _info;

  @override
  void initState() {
    super.initState();
    if (WeatherService.enabled) {
      WeatherService.instance.current().then((w) {
        if (mounted) setState(() => _info = w);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!WeatherService.enabled || _info == null) {
      return const SizedBox.shrink();
    }
    final w = _info!;
    return Card(
      child: ListTile(
        leading: Text(w.emoji, style: const TextStyle(fontSize: 30)),
        title: Text('${w.temp.toStringAsFixed(0)}°C  ${w.city}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${w.description}  •  feels like ${w.feelsLike.toStringAsFixed(0)}°C'),
      ),
    );
  }
}
