import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../core/workspace_provider.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  IconData _icon(String? type) => switch (type) {
        'flight' => Icons.flight,
        'train' => Icons.train,
        'bus' => Icons.directions_bus,
        'car' => Icons.directions_car,
        _ => Icons.map,
      };

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    final ws = context.watch<WorkspaceProvider>();
    return Scaffold(
      appBar: GradientAppBar(title: Text(context.t('trips'))),
      body: ContentWidth(
        child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.stream('trips', workspace: true),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!
            ..sort((a, b) =>
                (a['depDate'] ?? '9999').compareTo(b['depDate'] ?? '9999'));
          if (all.isEmpty) {
            return EmptyState(
                icon: Icons.flight_outlined,
                message: context.t('nothing_here'));
          }
          final upcoming =
              all.where((t) => (t['status'] ?? 'upcoming') == 'upcoming').toList();
          final completed =
              all.where((t) => t['status'] == 'completed').toList();
          final cancelled =
              all.where((t) => t['status'] == 'cancelled').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (upcoming.isNotEmpty)
                SectionHeader(context.t('upcoming'),
                    color: const Color(0xFF27AE60)),
              ...upcoming.map((t) => _card(context, db, t, ws)),
              if (completed.isNotEmpty)
                SectionHeader(context.t('completed'),
                    color: const Color(0xFF3498DB)),
              ...completed.map((t) => _card(context, db, t, ws)),
              if (cancelled.isNotEmpty)
                SectionHeader(context.t('cancelled'),
                    color: const Color(0xFFE74C3C)),
              ...cancelled.map((t) => _card(context, db, t, ws)),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      ),
      floatingActionButton: ws.canAdd
          ? FloatingActionButton.extended(
              heroTag: 'tripFab',
              onPressed: () => _openForm(context, db),
              icon: const Icon(Icons.add),
              label: Text(context.t('add')),
            )
          : null,
    );
  }

  Widget _card(BuildContext context, DbService db, Map<String, dynamic> t,
      WorkspaceProvider ws) {
    return Card(
      child: InkWell(
        onTap: ws.canEdit ? () => _openForm(context, db, existing: t) : null,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon(t['type']), color: const Color(0xFF667EEA)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${t['from']} → ${t['to']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  if (ws.canAdd)
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') {
                          _openForm(context, db, existing: t);
                        } else if (v == 'delete') {
                          await NotificationService.instance
                              .cancel('trip_${t['id']}');
                          if (!context.mounted) return;
                          await deleteWithUndo(
                            context,
                            collection: 'trips',
                            id: t['id'],
                            data: t,
                            workspace: true,
                            label: 'Trip deleted',
                          );
                        } else {
                          await db.update('trips', t['id'], {'status': v},
                              workspace: true);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'completed',
                            child: Text(context.t('done'))),
                        PopupMenuItem(
                            value: 'cancelled',
                            child: Text(context.t('cancelled'))),
                        PopupMenuItem(
                            value: 'upcoming',
                            child: Text(context.t('upcoming'))),
                        if (ws.canEdit)
                          PopupMenuItem(
                              value: 'edit', child: Text(context.t('edit'))),
                        if (ws.canEdit)
                          PopupMenuItem(
                              value: 'delete',
                              child: Text(context.t('delete'))),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                  '${_fmt(t['depDate'])} ${t['depTime'] ?? ''}  →  ${_fmt(t['arrDate'])} ${t['arrTime'] ?? ''}',
                  style: TextStyle(color: Colors.grey.shade600)),
              if ((t['pnr'] ?? '').toString().isNotEmpty)
                Text('PNR: ${t['pnr']}'),
              if ((t['airline'] ?? '').toString().isNotEmpty)
                Text('Airline: ${t['airline']}'),
              if ((t['trainName'] ?? '').toString().isNotEmpty)
                Text('Train: ${t['trainName']}'),
              if ((t['busOperator'] ?? '').toString().isNotEmpty)
                Text('Bus: ${t['busOperator']}'),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('d MMM').format(d);
  }

  /// Shared form for both Add and Edit. Pass [existing] to edit in place.
  void _openForm(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final fromC = TextEditingController(text: existing?['from'] ?? '');
    final toC = TextEditingController(text: existing?['to'] ?? '');
    final pnrC = TextEditingController(text: existing?['pnr'] ?? '');
    String type = existing?['type'] ?? 'flight';
    final extraC = TextEditingController(
      text: existing == null
          ? ''
          : (existing['airline'] ??
              existing['trainName'] ??
              existing['busOperator'] ??
              existing['carDetails'] ??
              ''),
    );
    DateTime? depDate = existing != null && (existing['depDate'] ?? '').isNotEmpty
        ? DateTime.tryParse(existing['depDate'])
        : null;
    DateTime? arrDate = existing != null && (existing['arrDate'] ?? '').isNotEmpty
        ? DateTime.tryParse(existing['arrDate'])
        : null;
    TimeOfDay? parseTime(String? v) {
      if (v == null || !v.contains(':')) return null;
      final p = v.split(':');
      return TimeOfDay(
          hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0);
    }

    TimeOfDay? depTime = parseTime(existing?['depTime']);
    TimeOfDay? arrTime = parseTime(existing?['arrTime']);

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    existing == null
                        ? context.t('trips')
                        : '${context.t('edit')} ${context.t('trips')}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Mode'),
                  items: const [
                    DropdownMenuItem(value: 'flight', child: Text('Flight ✈️')),
                    DropdownMenuItem(value: 'train', child: Text('Train 🚆')),
                    DropdownMenuItem(value: 'bus', child: Text('Bus 🚌')),
                    DropdownMenuItem(value: 'car', child: Text('Car 🚗')),
                  ],
                  onChanged: (v) => setSheet(() => type = v ?? 'flight'),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: fromC,
                    decoration: const InputDecoration(labelText: 'From')),
                const SizedBox(height: 10),
                TextField(
                    controller: toC,
                    decoration: const InputDecoration(labelText: 'To')),
                const SizedBox(height: 10),
                if (type != 'car')
                  TextField(
                      controller: pnrC,
                      decoration:
                          const InputDecoration(labelText: 'PNR / Ticket No')),
                if (type != 'car') const SizedBox(height: 10),
                TextField(
                    controller: extraC,
                    decoration: InputDecoration(
                        labelText: switch (type) {
                      'flight' => 'Airline',
                      'train' => 'Train name / number',
                      'bus' => 'Bus operator',
                      _ => 'Car details',
                    })),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: ctx,
                            initialDate: depDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100));
                        if (d != null) setSheet(() => depDate = d);
                      },
                      child: Text(depDate == null
                          ? 'Dep date'
                          : DateFormat('d MMM').format(depDate!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final tm = await showTimePicker(
                            context: ctx, initialTime: depTime ?? TimeOfDay.now());
                        if (tm != null) setSheet(() => depTime = tm);
                      },
                      child: Text(
                          depTime == null ? 'Dep time' : depTime!.format(ctx)),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: ctx,
                            initialDate: arrDate ?? depDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100));
                        if (d != null) setSheet(() => arrDate = d);
                      },
                      child: Text(arrDate == null
                          ? 'Arr date'
                          : DateFormat('d MMM').format(arrDate!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final tm = await showTimePicker(
                            context: ctx, initialTime: arrTime ?? TimeOfDay.now());
                        if (tm != null) setSheet(() => arrTime = tm);
                      },
                      child: Text(
                          arrTime == null ? 'Arr time' : arrTime!.format(ctx)),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    onPressed: () async {
                      if (fromC.text.trim().isEmpty ||
                          toC.text.trim().isEmpty) {
                        return;
                      }
                      String fmtD(DateTime? d) => d == null
                          ? ''
                          : DateFormat('yyyy-MM-dd').format(d);
                      String fmtT(TimeOfDay? t) => t == null
                          ? ''
                          : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                      final data = {
                        'type': type,
                        'from': fromC.text.trim(),
                        'to': toC.text.trim(),
                        'depDate': fmtD(depDate),
                        'arrDate': fmtD(arrDate),
                        'depTime': fmtT(depTime),
                        'arrTime': fmtT(arrTime),
                        'status': existing?['status'] ?? 'upcoming',
                        'pnr': pnrC.text.trim(),
                      };
                      if (type == 'flight') data['airline'] = extraC.text.trim();
                      if (type == 'train') {
                        data['trainName'] = extraC.text.trim();
                      }
                      if (type == 'bus') {
                        data['busOperator'] = extraC.text.trim();
                      }
                      if (type == 'car') {
                        data['carDetails'] = extraC.text.trim();
                      }

                      String id;
                      if (existing != null) {
                        id = existing['id'];
                        await saveWithUndo(
                          ctx,
                          collection: 'trips',
                          id: id,
                          previousData: existing,
                          newData: data,
                          workspace: true,
                          label: 'Trip updated',
                        );
                      } else {
                        id = await db.add('trips', data, workspace: true);
                      }

                      // Reminder 3 hours before departure (reschedule on edit).
                      await NotificationService.instance.cancel('trip_$id');
                      if (depDate != null && depTime != null) {
                        final dep = DateTime(depDate!.year, depDate!.month,
                            depDate!.day, depTime!.hour, depTime!.minute);
                        await NotificationService.instance.scheduleAt(
                          key: 'trip_$id',
                          title: 'Trip soon: ${fromC.text} → ${toC.text}',
                          body: 'Departs at ${fmtT(depTime)}',
                          when: dep.subtract(const Duration(hours: 3)),
                        );
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
      ),
    );
  }
}
