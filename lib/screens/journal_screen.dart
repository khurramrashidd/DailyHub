import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../services/db_service.dart';
import '../widgets/common.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  static const moods = ['😄', '🙂', '😐', '😔', '😣'];

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    return Scaffold(
      appBar: GradientAppBar(title: Text(context.t('journal'))),
      body: ContentWidth(
        child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.stream('journal'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data!
            ..sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
          if (entries.isEmpty) {
            return EmptyState(
                icon: Icons.book, message: context.t('nothing_here'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              final d = DateTime.tryParse(e['date'] ?? '');
              return Card(
                child: ListTile(
                  leading: Text(e['mood'] ?? '🙂',
                      style: const TextStyle(fontSize: 28)),
                  title: Text(d == null
                      ? ''
                      : DateFormat('EEEE, d MMM yyyy').format(d)),
                  subtitle: Text(e['text'] ?? '',
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => deleteWithUndo(
                      context,
                      collection: 'journal',
                      id: e['id'],
                      data: e,
                      label: 'Journal entry deleted',
                    ),
                  ),
                  onTap: () => _add(context, db, existing: e),
                ),
              );
            },
          );
        },
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'journalFab',
        onPressed: () => _add(context, db),
        icon: const Icon(Icons.edit),
        label: Text(context.t('add')),
      ),
    );
  }

  void _add(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final textC = TextEditingController(text: existing?['text'] ?? '');
    String mood = existing?['mood'] ?? '🙂';

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
              Text(context.t('mood'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: moods.map((m) {
                  return GestureDetector(
                    onTap: () => setSheet(() => mood = m),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: mood == m
                                ? const Color(0xFF667EEA)
                                : Colors.transparent,
                            width: 2),
                      ),
                      child: Text(m, style: const TextStyle(fontSize: 30)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textC,
                minLines: 4,
                maxLines: 10,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    InputDecoration(hintText: context.t('how_was_day')),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  onPressed: () async {
                    if (textC.text.trim().isEmpty) {
                      Navigator.pop(ctx);
                      return;
                    }
                    final data = {
                      'text': textC.text.trim(),
                      'mood': mood,
                      'date': existing?['date'] ??
                          DateTime.now().toIso8601String(),
                    };
                    if (existing != null) {
                      await saveWithUndo(
                        ctx,
                        collection: 'journal',
                        id: existing['id'],
                        previousData: existing,
                        newData: data,
                        label: 'Journal entry updated',
                      );
                    } else {
                      await db.add('journal', data);
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
    );
  }
}
