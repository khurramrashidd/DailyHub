import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/localization.dart';
import '../core/responsive.dart';
import '../services/db_service.dart';
import '../widgets/common.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  static const categories = [
    'Food',
    'Travel',
    'Shopping',
    'Bills',
    'Health',
    'Fun',
    'Other',
  ];

  static const catColors = [
    Color(0xFFE74C3C),
    Color(0xFF3498DB),
    Color(0xFF9B59B6),
    Color(0xFFF39C12),
    Color(0xFF27AE60),
    Color(0xFF1ABC9C),
    Color(0xFF7F8C8D),
  ];

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
    return Scaffold(
      appBar: GradientAppBar(title: Text(context.t('expenses'))),
      body: ContentWidth(
        child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.stream('expenses'),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!
            ..sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
          final thisMonth = all
              .where((e) => (e['date'] ?? '').toString().startsWith(monthKey))
              .toList();
          final total = thisMonth.fold<double>(
              0, (s, e) => s + ((e['amount'] ?? 0) as num).toDouble());

          final byCat = <String, double>{};
          for (final e in thisMonth) {
            final c = (e['category'] ?? 'Other') as String;
            byCat[c] = (byCat[c] ?? 0) +
                ((e['amount'] ?? 0) as num).toDouble();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(context.t('this_month'),
                          style: TextStyle(color: Colors.grey.shade700)),
                      Text('₹${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF27AE60))),
                    ],
                  ),
                ),
              ),
              if (byCat.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sections: byCat.entries.map((e) {
                        final idx = categories.indexOf(e.key);
                        return PieChartSectionData(
                          value: e.value,
                          title:
                              '${(e.value / total * 100).toStringAsFixed(0)}%',
                          color: catColors[idx < 0 ? 6 : idx],
                          radius: 60,
                          titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: byCat.keys.map((k) {
                    final idx = categories.indexOf(k);
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 12,
                          height: 12,
                          color: catColors[idx < 0 ? 6 : idx]),
                      const SizedBox(width: 4),
                      Text(k, style: const TextStyle(fontSize: 12)),
                    ]);
                  }).toList(),
                ),
              ],
              SectionHeader(context.t('expenses')),
              if (thisMonth.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(context.t('nothing_here'),
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
              ...thisMonth.map((e) {
                final idx = categories.indexOf(e['category'] ?? 'Other');
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: catColors[idx < 0 ? 6 : idx],
                      child: const Icon(Icons.currency_rupee,
                          color: Colors.white, size: 18),
                    ),
                    title: Text(e['note']?.toString().isNotEmpty == true
                        ? e['note']
                        : e['category'] ?? ''),
                    subtitle: Text([
                      e['category'],
                      e['date'],
                      if (((e['splitWays'] ?? 1) as num).toInt() > 1)
                        'split ${e['splitWays']} ways',
                    ].join(' • ')),
                    trailing: Text(
                        '₹${((e['amount'] ?? 0) as num).toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    onTap: () => _openForm(context, db, existing: e),
                    onLongPress: () => deleteWithUndo(
                      context,
                      collection: 'expenses',
                      id: e['id'],
                      data: e,
                      label: 'Expense deleted',
                    ),
                  ),
                );
              }),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expFab',
        onPressed: () => _openForm(context, db),
        icon: const Icon(Icons.add),
        label: Text(context.t('add_expense')),
      ),
    );
  }

  /// Shared form for both Add and Edit. Pass [existing] to edit in place.
  void _openForm(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final amountC = TextEditingController(
        text: existing == null ? '' : (existing['amount'] ?? '').toString());
    final noteC = TextEditingController(text: existing?['note'] ?? '');
    String category = existing?['category'] ?? 'Food';
    int splitWays = ((existing?['splitWays'] ?? 1) as num).toInt();
    DateTime date = existing != null && (existing['date'] ?? '').isNotEmpty
        ? (DateTime.tryParse(existing['date']) ?? DateTime.now())
        : DateTime.now();

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
                controller: amountC,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: context.t('amount'), prefixText: '₹ '),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration:
                    InputDecoration(labelText: context.t('category')),
                items: categories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => category = v ?? 'Food',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteC,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 10),
              // Split bill: divides the amount between people. Your share is
              // what gets stored as the expense; the full amount is kept for
              // reference so you can see what the whole bill was.
              Row(
                children: [
                  const Icon(Icons.call_split, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Split between'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: splitWays <= 1
                        ? null
                        : () => setSheet(() => splitWays--),
                  ),
                  Text('$splitWays',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setSheet(() => splitWays++),
                  ),
                ],
              ),
              if (splitWays > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Builder(builder: (_) {
                    final total = double.tryParse(amountC.text.trim()) ?? 0;
                    final share = total / splitWays;
                    return Text(
                      'Your share: ₹${share.toStringAsFixed(2)} of ₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF16A085),
                          fontWeight: FontWeight.w600),
                    );
                  }),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(DateFormat('d MMM yyyy').format(date)),
                onPressed: () async {
                  final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100));
                  if (d != null) setSheet(() => date = d);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  onPressed: () async {
                    final amt = double.tryParse(amountC.text.trim());
                    if (amt == null) return;
                    final data = {
                      // Only your share counts toward your spending totals.
                      'amount': splitWays > 1 ? amt / splitWays : amt,
                      'fullAmount': amt,
                      'splitWays': splitWays,
                      'category': category,
                      'note': noteC.text.trim(),
                      'date': DateFormat('yyyy-MM-dd').format(date),
                    };
                    if (existing != null) {
                      await saveWithUndo(
                        ctx,
                        collection: 'expenses',
                        id: existing['id'],
                        previousData: existing,
                        newData: data,
                        label: 'Expense updated',
                      );
                    } else {
                      await db.add('expenses', data);
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
