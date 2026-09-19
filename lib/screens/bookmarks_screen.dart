import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../services/db_service.dart';
import '../widgets/common.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    return Scaffold(
      appBar: GradientAppBar(title: Text(context.t('bookmarks'))),
      body: ContentWidth(
        child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.stream('bookmarks'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!
            ..sort((a, b) =>
                (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
          if (items.isEmpty) {
            return EmptyState(
                icon: Icons.bookmark_border,
                message: context.t('nothing_here'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final b = items[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF16A085),
                    child: Icon(Icons.link, color: Colors.white),
                  ),
                  title: Text(b['title']?.toString().isNotEmpty == true
                      ? b['title']
                      : b['url'] ?? ''),
                  subtitle: Text(b['url'] ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () =>
                            _openForm(context, db, existing: b),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => deleteWithUndo(
                          context,
                          collection: 'bookmarks',
                          id: b['id'],
                          data: b,
                          label: 'Bookmark deleted',
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _open(context, b['url']),
                  onLongPress: () => _openForm(context, db, existing: b),
                ),
              );
            },
          );
        },
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bmFab',
        onPressed: () => _openForm(context, db),
        icon: const Icon(Icons.add),
        label: Text(context.t('add')),
      ),
    );
  }

  Future<void> _open(BuildContext context, String? raw) async {
    if (raw == null || raw.isEmpty) return;
    var url = raw.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  /// Shared form for both Add and Edit. Pass [existing] to edit in place.
  void _openForm(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final titleC = TextEditingController(text: existing?['title'] ?? '');
    final urlC = TextEditingController(text: existing?['url'] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
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
              controller: urlC,
              keyboardType: TextInputType.url,
              autofocus: true,
              decoration: InputDecoration(labelText: context.t('url')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: titleC,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  InputDecoration(labelText: '${context.t('title')} (optional)'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                onPressed: () async {
                  if (urlC.text.trim().isEmpty) return;
                  final data = {
                    'url': urlC.text.trim(),
                    'title': titleC.text.trim(),
                    'createdAt': existing?['createdAt'] ??
                        DateTime.now().toIso8601String(),
                  };
                  if (existing != null) {
                    await saveWithUndo(
                      ctx,
                      collection: 'bookmarks',
                      id: existing['id'],
                      previousData: existing,
                      newData: data,
                      label: 'Bookmark updated',
                    );
                  } else {
                    await db.add('bookmarks', data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(context.t('save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
