import 'package:flutter/material.dart';

import '../core/localization.dart';
import '../core/theme.dart';
import '../services/db_service.dart';

/// AppBar with the original web app's header gradient (90deg #667eea -> #764ba2)
/// instead of a flat color. Drop-in replacement for `AppBar(...)`.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;

  const GradientAppBar({
    super.key,
    this.title,
    this.actions,
    this.bottom,
    this.leading,
  });

  @override
  Size get preferredSize => Size.fromHeight(
      kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      actions: actions,
      bottom: bottom,
      leading: leading,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      ),
    );
  }
}

/// Pill-shaped gradient CTA button matching the original `.btn-primary`
/// (90deg #667eea -> #764ba2). API-compatible with ElevatedButton(onPressed, child)
/// so it drops in wherever a primary "Save" / "Login" action lives.
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const GradientButton({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Container(
      decoration: BoxDecoration(
        gradient: disabled ? null : AppColors.brandGradient,
        color: disabled ? Colors.grey.shade400 : null,
        borderRadius: BorderRadius.circular(30),
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Center(
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
                child: IconTheme.merge(
                  data: const IconThemeData(color: Colors.white),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Deletes a record but keeps it recoverable for a few seconds via a
/// snackbar "UNDO" action, restoring the exact same id and data if pressed.
/// [data] should be the record's map WITHOUT the 'id' field.
Future<void> deleteWithUndo(
  BuildContext context, {
  required String collection,
  required String id,
  required Map<String, dynamic> data,
  bool workspace = false,
  String label = 'Deleted',
}) async {
  final db = DbService.instance;
  final clean = Map<String, dynamic>.from(data)..remove('id');
  await db.remove(collection, id, workspace: workspace);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(label),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () => db.set(collection, id, clean, workspace: workspace),
      ),
    ),
  );
}

/// Saves an edit but keeps the previous version recoverable for a few
/// seconds via a snackbar "UNDO" action. [previousData] and [newData]
/// should NOT include the 'id' field.
Future<void> saveWithUndo(
  BuildContext context, {
  required String collection,
  required String id,
  required Map<String, dynamic> previousData,
  required Map<String, dynamic> newData,
  bool workspace = false,
  String label = 'Saved changes',
}) async {
  final db = DbService.instance;
  final prevClean = Map<String, dynamic>.from(previousData)..remove('id');
  final newClean = Map<String, dynamic>.from(newData)..remove('id');
  await db.set(collection, id, newClean, workspace: workspace);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(label),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () =>
            db.set(collection, id, prevClean, workspace: workspace),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String? message;
  const EmptyState({super.key, this.icon = Icons.inbox_outlined, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message ?? context.t('nothing_here'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const SectionHeader(this.title,
      {super.key, this.color = const Color(0xFF667EEA)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15, color: color)),
    );
  }
}

/// Instant idea capture — the "write it before it escapes" flow.
/// Opens from the global FAB. Saves to users/{uid}/notes with pinned=false.
Future<void> showQuickCapture(BuildContext context) async {
  final controller = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
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
            Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFF764BA2)),
                const SizedBox(width: 8),
                Text(ctx.t('quick_capture'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: ctx.t('quick_note_hint')),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: Text(ctx.t('save')),
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    Navigator.pop(ctx);
                    return;
                  }
                  await DbService.instance.add('notes', {
                    'title': '',
                    'body': text,
                    'color': 0,
                    'pinned': false,
                    'tags': '',
                    'createdAt': DateTime.now().toIso8601String(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Small colored stat tile used on the dashboard.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
