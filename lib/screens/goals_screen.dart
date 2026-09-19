import 'package:flutter/material.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../services/db_service.dart';
import '../widgets/common.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    return Scaffold(
      appBar: GradientAppBar(title: Text(context.t('goals'))),
      body: ContentWidth(
        child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.stream('goals'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final goals = snap.data!;
          if (goals.isEmpty) {
            return EmptyState(
                icon: Icons.flag, message: context.t('nothing_here'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: goals.length,
            itemBuilder: (context, i) {
              final g = goals[i];
              final progress = ((g['progress'] ?? 0) as num).toInt();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _edit(context, db, existing: g),
                              child: Text(g['title'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                            ),
                          ),
                          Text('$progress%',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF3498DB))),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _edit(context, db, existing: g),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => deleteWithUndo(
                              context,
                              collection: 'goals',
                              id: g['id'],
                              data: g,
                              label: 'Goal deleted',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          color: progress >= 100
                              ? const Color(0xFF27AE60)
                              : const Color(0xFF3498DB),
                        ),
                      ),
                      Slider(
                        value: progress.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '$progress%',
                        onChanged: (v) => db.update(
                            'goals', g['id'], {'progress': v.toInt()}),
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
        heroTag: 'goalFab',
        onPressed: () => _edit(context, db),
        icon: const Icon(Icons.add),
        label: Text(context.t('add')),
      ),
    );
  }

  /// Shared dialog for both Add and Edit (title only; progress stays via slider).
  void _edit(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final c = TextEditingController(text: existing?['title'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null
            ? context.t('goals')
            : '${context.t('edit')} ${context.t('goals')}'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              hintText: 'e.g. Finish B.Tech project, Save ₹50,000'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.t('cancel'))),
          GradientButton(
            onPressed: () async {
              if (c.text.trim().isEmpty) return;
              if (existing != null) {
                final data = Map<String, dynamic>.from(existing)
                  ..['title'] = c.text.trim();
                await saveWithUndo(
                  ctx,
                  collection: 'goals',
                  id: existing['id'],
                  previousData: existing,
                  newData: data,
                  label: 'Goal updated',
                );
              } else {
                await db.add('goals', {
                  'title': c.text.trim(),
                  'progress': 0,
                  'createdAt': DateTime.now().toIso8601String(),
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing == null ? context.t('add') : context.t('save')),
          ),
        ],
      ),
    );
  }
}
