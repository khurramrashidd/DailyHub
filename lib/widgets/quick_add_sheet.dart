import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/quick_parse.dart';
import '../core/theme.dart';
import '../screens/bookmarks_screen.dart';
import '../screens/expenses_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/reminders_screen.dart';
import '../screens/todos_screen.dart';
import '../screens/trips_screen.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';

/// The unified "+" action. Opens a sheet offering every creatable type,
/// plus Smart Capture — type a brain-dump and it's split into tasks,
/// reminders, expenses and notes for confirmation.
Future<void> showQuickAdd(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _QuickAddSheet(),
  );
}

class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet();

  @override
  Widget build(BuildContext context) {
    final items = <_AddOption>[
      _AddOption(Icons.bolt, 'Smart Capture', const Color(0xFF764BA2),
          (c) => _openSmartCapture(c)),
      _AddOption(Icons.sticky_note_2, 'Note', const Color(0xFFF39C12),
          (c) => Navigator.push(
              c, MaterialPageRoute(builder: (_) => const NotesScreen()))),
      _AddOption(Icons.check_circle, 'Task', const Color(0xFF667EEA),
          (c) => Navigator.push(
              c, MaterialPageRoute(builder: (_) => const TodosScreen()))),
      _AddOption(Icons.alarm, 'Reminder', const Color(0xFFE74C3C),
          (c) => Navigator.push(
              c, MaterialPageRoute(builder: (_) => const RemindersScreen()))),
      _AddOption(Icons.flight, 'Trip', const Color(0xFF27AE60),
          (c) => Navigator.push(
              c, MaterialPageRoute(builder: (_) => const TripsScreen()))),
      _AddOption(Icons.account_balance_wallet, 'Expense',
          const Color(0xFF16A085),
          (c) => Navigator.push(
              c, MaterialPageRoute(builder: (_) => const ExpensesScreen()))),
      _AddOption(Icons.bookmark, 'Bookmark', const Color(0xFF9B59B6),
          (c) => Navigator.push(
              c, MaterialPageRoute(builder: (_) => const BookmarksScreen()))),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add to DailyHub',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items
                .map((it) => SizedBox(
                      width: 86,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pop(context);
                          it.onTap(context);
                        },
                        child: Column(
                          children: [
                            Container(
                              height: 54,
                              width: 54,
                              decoration: BoxDecoration(
                                color: it.color.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: it.color.withValues(alpha: 0.3)),
                              ),
                              child: Icon(it.icon, color: it.color, size: 26),
                            ),
                            const SizedBox(height: 6),
                            Text(it.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  void _openSmartCapture(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const SmartCaptureSheet(),
    );
  }
}

class _AddOption {
  final IconData icon;
  final String label;
  final Color color;
  final void Function(BuildContext) onTap;
  _AddOption(this.icon, this.label, this.color, this.onTap);
}

/// "Capture Now, Organize Later" — type everything at once, review the
/// suggested classification, then save in one go.
class SmartCaptureSheet extends StatefulWidget {
  const SmartCaptureSheet({super.key});

  @override
  State<SmartCaptureSheet> createState() => _SmartCaptureSheetState();
}

class _SmartCaptureSheetState extends State<SmartCaptureSheet> {
  final _controller = TextEditingController();
  List<ParsedItem> _parsed = [];
  bool _reviewing = false;
  bool _saving = false;

  void _analyze() {
    final items = QuickParse.parseAll(_controller.text);
    if (items.isEmpty) return;
    setState(() {
      _parsed = items;
      _reviewing = true;
    });
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    final db = DbService.instance;
    try {
      for (final item in _parsed) {
        switch (item.kind) {
          case CaptureKind.task:
            await db.add(
                'todos',
                {
                  'title': item.text,
                  'desc': '',
                  'date': item.when == null
                      ? ''
                      : DateFormat('yyyy-MM-dd').format(item.when!),
                  'time': item.when == null
                      ? ''
                      : DateFormat('HH:mm').format(item.when!),
                  'priority': 'Medium',
                  'status': 'upcoming',
                },
                workspace: true);
            break;
          case CaptureKind.reminder:
            final when =
                item.when ?? DateTime.now().add(const Duration(hours: 1));
            final id = await db.add('reminders', {
              'title': item.text,
              'when': when.toIso8601String(),
              'repeat': 'once',
              'createdAt': DateTime.now().toIso8601String(),
            });
            await NotificationService.instance.scheduleAt(
              key: 'rem_$id',
              title: item.text,
              body: 'Reminder',
              when: when,
            );
            break;
          case CaptureKind.expense:
            await db.add('expenses', {
              'amount': item.amount ?? 0,
              'category': 'Other',
              'note': item.text,
              'date': DateFormat('yyyy-MM-dd')
                  .format(item.when ?? DateTime.now()),
            });
            break;
          case CaptureKind.note:
            await db.add('notes', {
              'title': '',
              'body': item.text,
              'color': 0,
              'pinned': false,
              'tags': '',
              'createdAt': DateTime.now().toIso8601String(),
            });
            break;
        }
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${_parsed.length} item(s)')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Color _kindColor(CaptureKind k) => switch (k) {
        CaptureKind.task => const Color(0xFF667EEA),
        CaptureKind.reminder => const Color(0xFFE74C3C),
        CaptureKind.expense => const Color(0xFF16A085),
        CaptureKind.note => const Color(0xFFF39C12),
      };

  IconData _kindIcon(CaptureKind k) => switch (k) {
        CaptureKind.task => Icons.check_circle_outline,
        CaptureKind.reminder => Icons.alarm,
        CaptureKind.expense => Icons.currency_rupee,
        CaptureKind.note => Icons.sticky_note_2_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, color: Color(0xFF764BA2)),
              SizedBox(width: 8),
              Text('Smart Capture',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _reviewing
                ? 'Check what each line should become, then save.'
                : 'Dump everything. Separate with commas or new lines.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (!_reviewing) ...[
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Buy charger, call Rahul, remind me to book train tomorrow 5pm',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GradientCaptureButton(
                label: 'Organize',
                onPressed: _controller.text.trim().isEmpty ? null : _analyze,
              ),
            ),
          ] else ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _parsed.length,
                itemBuilder: (context, i) {
                  final item = _parsed[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: Icon(_kindIcon(item.kind),
                          color: _kindColor(item.kind)),
                      title: Text(item.text,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: item.when == null
                          ? null
                          : Text(DateFormat('EEE, d MMM • h:mm a')
                              .format(item.when!)),
                      trailing: DropdownButton<CaptureKind>(
                        value: item.kind,
                        underline: const SizedBox.shrink(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _parsed[i] = item.copyWith(kind: v));
                        },
                        items: CaptureKind.values
                            .map((k) => DropdownMenuItem(
                                  value: k,
                                  child: Text(
                                      switch (k) {
                                        CaptureKind.task => 'Task',
                                        CaptureKind.reminder => 'Reminder',
                                        CaptureKind.expense => 'Expense',
                                        CaptureKind.note => 'Note',
                                      },
                                      style: const TextStyle(fontSize: 12)),
                                ))
                            .toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _reviewing = false),
                  child: const Text('Back'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GradientCaptureButton(
                    label: _saving
                        ? 'Saving...'
                        : 'Save ${_parsed.length} item(s)',
                    onPressed: _saving ? null : _saveAll,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Local gradient button (kept here to avoid a circular import with common.dart).
class GradientCaptureButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const GradientCaptureButton(
      {super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Container(
      decoration: BoxDecoration(
        gradient: disabled ? null : AppColors.brandGradient,
        color: disabled ? Colors.grey.shade400 : null,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}
