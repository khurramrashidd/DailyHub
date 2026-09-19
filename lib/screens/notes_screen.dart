import 'package:flutter/material.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../services/db_service.dart';
import '../widgets/common.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _search = TextEditingController();
  String _query = '';

  static const List<Color> palette = [
    Color(0xFFFFFFFF),
    Color(0xFFFFF3C4),
    Color(0xFFFFD8CC),
    Color(0xFFD3F9D8),
    Color(0xFFD0EBFF),
    Color(0xFFE5DBFF),
  ];

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    return Scaffold(
      appBar: GradientAppBar(
        title: Text(context.t('notes')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: context.t('search'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
      body: ContentWidth(
        child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.stream('notes'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var notes = snap.data!;
          if (_query.isNotEmpty) {
            notes = notes
                .where((n) =>
                    (n['title'] ?? '').toLowerCase().contains(_query) ||
                    (n['body'] ?? '').toLowerCase().contains(_query) ||
                    (n['tags'] ?? '').toLowerCase().contains(_query))
                .toList();
          }
          notes.sort((a, b) {
            final pin = ((b['pinned'] == true) ? 1 : 0) -
                ((a['pinned'] == true) ? 1 : 0);
            if (pin != 0) return pin;
            return (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? '');
          });
          if (notes.isEmpty) {
            return EmptyState(
                icon: Icons.sticky_note_2_outlined,
                message: context.t('nothing_here'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: notes.length,
            itemBuilder: (context, i) {
              final n = notes[i];
              final colorIdx = (n['color'] ?? 0) as int;
              return GestureDetector(
                onTap: () => _openForm(context, db, existing: n),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette[colorIdx % palette.length],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (n['title'] ?? '').toString().isEmpty
                                  ? (n['body'] ?? '')
                                  : n['title'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87),
                            ),
                          ),
                          InkWell(
                            onTap: () => db.update('notes', n['id'],
                                {'pinned': !(n['pinned'] == true)}),
                            child: Icon(
                                n['pinned'] == true
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                size: 18,
                                color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(n['body'] ?? '',
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black87)),
                      ),
                      if ((n['tags'] ?? '').toString().isNotEmpty)
                        Text('#${n['tags']}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54)),
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
        heroTag: 'noteFab',
        onPressed: () => _openForm(context, db),
        icon: const Icon(Icons.add),
        label: Text(context.t('add')),
      ),
    );
  }

  void _openForm(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final titleC = TextEditingController(text: existing?['title'] ?? '');
    final bodyC = TextEditingController(text: existing?['body'] ?? '');
    final tagsC = TextEditingController(text: existing?['tags'] ?? '');
    int color = (existing?['color'] ?? 0) as int;

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
              TextField(
                controller: titleC,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: context.t('title')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bodyC,
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    InputDecoration(labelText: context.t('description')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tagsC,
                decoration:
                    const InputDecoration(labelText: 'Tags (comma separated)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(palette.length, (i) {
                  return GestureDetector(
                    onTap: () => setSheet(() => color = i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: palette[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: color == i
                                ? const Color(0xFF667EEA)
                                : Colors.black26,
                            width: color == i ? 3 : 1),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (existing != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFE74C3C)),
                      onPressed: () async {
                        await deleteWithUndo(
                          ctx,
                          collection: 'notes',
                          id: existing['id'],
                          data: existing,
                          label: 'Note deleted',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  Expanded(
                    child: GradientButton(
                      onPressed: () async {
                        if (titleC.text.trim().isEmpty &&
                            bodyC.text.trim().isEmpty) {
                          Navigator.pop(ctx);
                          return;
                        }
                        final data = {
                          'title': titleC.text.trim(),
                          'body': bodyC.text.trim(),
                          'tags': tagsC.text.trim(),
                          'color': color,
                          'pinned': existing?['pinned'] ?? false,
                          'createdAt': existing?['createdAt'] ??
                              DateTime.now().toIso8601String(),
                        };
                        if (existing != null) {
                          await saveWithUndo(
                            ctx,
                            collection: 'notes',
                            id: existing['id'],
                            previousData: existing,
                            newData: data,
                            label: 'Note updated',
                          );
                        } else {
                          await db.add('notes', data);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(context.t('save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
