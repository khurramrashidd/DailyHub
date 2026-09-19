import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../services/db_service.dart';

/// Universal search across every module. One box, results grouped by type,
/// so "Delhi" surfaces the trip, the notes, the expenses and the bookmarks
/// that mention it.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _Result {
  final String type;
  final String text;
  final String subtitle;
  final IconData icon;
  final Color color;
  _Result(this.type, this.text, this.subtitle, this.icon, this.color);
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _q = '';

  final _data = <String, List<Map<String, dynamic>>>{};
  final _subs = <String>[
    'notes',
    'todos',
    'trips',
    'reminders',
    'expenses',
    'goals',
    'habits',
    'journal',
    'bookmarks',
    'assignments',
    'meetings',
    'shopping',
  ];

  @override
  void initState() {
    super.initState();
    final db = DbService.instance;
    for (final c in _subs) {
      final workspace = c == 'todos' || c == 'trips';
      db.stream(c, workspace: workspace).listen((v) {
        if (mounted) setState(() => _data[c] = v);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _hit(String q, List<Object?> fields) =>
      fields.any((f) => (f ?? '').toString().toLowerCase().contains(q));

  List<_Result> get _results {
    if (_q.isEmpty) return [];
    final q = _q.toLowerCase();
    final out = <_Result>[];

    for (final n in _data['notes'] ?? []) {
      if (_hit(q, [n['title'], n['body'], n['tags']])) {
        out.add(_Result(
            'Note',
            (n['title'] ?? '').toString().isEmpty ? n['body'] : n['title'],
            (n['tags'] ?? '').toString().isEmpty ? '' : '#${n['tags']}',
            Icons.sticky_note_2,
            const Color(0xFFF39C12)));
      }
    }
    for (final t in _data['todos'] ?? []) {
      if (_hit(q, [t['title'], t['desc']])) {
        out.add(_Result(
            'Task',
            t['title'] ?? '',
            [t['date'], t['priority']]
                .where((e) => (e ?? '').toString().isNotEmpty)
                .join(' • '),
            Icons.check_circle_outline,
            const Color(0xFF667EEA)));
      }
    }
    for (final t in _data['trips'] ?? []) {
      if (_hit(q, [
        t['from'], t['to'], t['airline'], t['trainName'],
        t['busOperator'], t['pnr']
      ])) {
        out.add(_Result(
            'Trip',
            '${t['from']} → ${t['to']}',
            [t['depDate'], t['pnr']]
                .where((e) => (e ?? '').toString().isNotEmpty)
                .join(' • '),
            Icons.flight,
            const Color(0xFF27AE60)));
      }
    }
    for (final r in _data['reminders'] ?? []) {
      if (_hit(q, [r['title']])) {
        final w = DateTime.tryParse(r['when'] ?? '');
        out.add(_Result(
            'Reminder',
            r['title'] ?? '',
            w == null ? '' : DateFormat('d MMM • h:mm a').format(w),
            Icons.alarm,
            const Color(0xFFE74C3C)));
      }
    }
    for (final e in _data['expenses'] ?? []) {
      if (_hit(q, [e['note'], e['category']])) {
        out.add(_Result(
            'Expense',
            (e['note'] ?? '').toString().isEmpty
                ? e['category'] ?? ''
                : e['note'],
            '₹${((e['amount'] ?? 0) as num).toStringAsFixed(0)} • ${e['date'] ?? ''}',
            Icons.currency_rupee,
            const Color(0xFF16A085)));
      }
    }
    for (final g in _data['goals'] ?? []) {
      if (_hit(q, [g['title']])) {
        out.add(_Result('Goal', g['title'] ?? '',
            '${((g['progress'] ?? 0) as num).toInt()}%', Icons.flag,
            const Color(0xFF3498DB)));
      }
    }
    for (final h in _data['habits'] ?? []) {
      if (_hit(q, [h['name']])) {
        out.add(_Result('Habit', h['name'] ?? '', '',
            Icons.local_fire_department, const Color(0xFFF39C12)));
      }
    }
    for (final j in _data['journal'] ?? []) {
      if (_hit(q, [j['text']])) {
        final d = DateTime.tryParse(j['date'] ?? '');
        out.add(_Result(
            'Journal',
            j['text'] ?? '',
            d == null ? '' : DateFormat('d MMM yyyy').format(d),
            Icons.book,
            const Color(0xFF9B59B6)));
      }
    }
    for (final a in _data['assignments'] ?? []) {
      if (_hit(q, [a['title'], a['subject']])) {
        out.add(_Result('Assignment', a['title'] ?? '',
            [a['subject'], a['due']]
                .where((e) => (e ?? '').toString().isNotEmpty)
                .join(' • '),
            Icons.assignment_outlined, const Color(0xFF8E44AD)));
      }
    }
    for (final m in _data['meetings'] ?? []) {
      if (_hit(q, [m['title'], m['notes']])) {
        final d = DateTime.tryParse(m['at'] ?? '');
        out.add(_Result('Meeting', m['title'] ?? '',
            d == null ? '' : DateFormat('d MMM, h:mm a').format(d),
            Icons.groups, const Color(0xFF34495E)));
      }
    }
    for (final i in _data['shopping'] ?? []) {
      if (_hit(q, [i['name'], i['list']])) {
        out.add(_Result('Shopping', i['name'] ?? '', i['list'] ?? '',
            Icons.shopping_cart_outlined, const Color(0xFFD35400)));
      }
    }
    for (final b in _data['bookmarks'] ?? []) {
      if (_hit(q, [b['title'], b['url']])) {
        out.add(_Result(
            'Bookmark',
            (b['title'] ?? '').toString().isEmpty ? b['url'] : b['title'],
            b['url'] ?? '',
            Icons.bookmark,
            const Color(0xFF16A085)));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    // Group by type so a search for a place shows its trip, notes and spend
    // together rather than as one flat list.
    final grouped = <String, List<_Result>>{};
    for (final r in results) {
      grouped.putIfAbsent(r.type, () => []).add(r);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Search everything...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _q = v),
        ),
        actions: [
          if (_q.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() => _q = '');
              },
            ),
        ],
      ),
      body: ContentWidth(
        child: _q.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search,
                        size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    Text(
                        'Search across every module —\nnotes, tasks, trips, assignments, meetings and more',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              )
            : results.isEmpty
                ? Center(
                    child: Text(context.t('nothing_here'),
                        style: TextStyle(color: Colors.grey.shade500)))
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: grouped.entries.expand((entry) {
                      return [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                          child: Text(
                              '${entry.key} (${entry.value.length})',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: entry.value.first.color)),
                        ),
                        ...entry.value.map((r) => Card(
                              child: ListTile(
                                leading: Icon(r.icon, color: r.color),
                                title: Text(r.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: r.subtitle.isEmpty
                                    ? null
                                    : Text(r.subtitle),
                              ),
                            )),
                      ];
                    }).toList(),
                  ),
      ),
    );
  }
}
