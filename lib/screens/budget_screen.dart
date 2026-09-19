import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/responsive.dart';
import '../services/db_service.dart';
import '../widgets/common.dart';
import 'expenses_screen.dart';

/// Monthly budgets per category, checked against this month's real spending.
class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    final monthKey = DateFormat('yyyy-MM').format(DateTime.now());

    return Scaffold(
      appBar: const GradientAppBar(title: Text('Budgets')),
      body: ContentWidth(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: db.stream('budgets'),
          builder: (context, budgetSnap) =>
              StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.stream('expenses'),
            builder: (context, expSnap) {
              if (!budgetSnap.hasData || !expSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final budgets = budgetSnap.data!;
              final thisMonth = expSnap.data!
                  .where((e) =>
                      (e['date'] ?? '').toString().startsWith(monthKey))
                  .toList();

              final spentByCat = <String, double>{};
              for (final e in thisMonth) {
                final c = (e['category'] ?? 'Other') as String;
                spentByCat[c] = (spentByCat[c] ?? 0) +
                    ((e['amount'] ?? 0) as num).toDouble();
              }

              final totalBudget = budgets.fold<double>(
                  0, (s, b) => s + ((b['limit'] ?? 0) as num).toDouble());
              final totalSpent =
                  spentByCat.values.fold<double>(0, (s, v) => s + v);

              if (budgets.isEmpty) {
                return const EmptyState(
                    icon: Icons.savings_outlined,
                    message: 'Set a budget to track your spending');
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Text(DateFormat('MMMM yyyy').format(DateTime.now()),
                              style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(height: 6),
                          Text(
                              '₹${totalSpent.toStringAsFixed(0)} / ₹${totalBudget.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: totalSpent > totalBudget
                                      ? const Color(0xFFE74C3C)
                                      : const Color(0xFF27AE60))),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: totalBudget == 0
                                  ? 0
                                  : (totalSpent / totalBudget).clamp(0, 1),
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade200,
                              color: totalSpent > totalBudget
                                  ? const Color(0xFFE74C3C)
                                  : const Color(0xFF27AE60),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...budgets.map((b) {
                    final cat = b['category'] ?? 'Other';
                    final limit = ((b['limit'] ?? 0) as num).toDouble();
                    final spent = spentByCat[cat] ?? 0;
                    final ratio = limit == 0 ? 0.0 : spent / limit;
                    final over = spent > limit;
                    final color = over
                        ? const Color(0xFFE74C3C)
                        : ratio > 0.8
                            ? const Color(0xFFF39C12)
                            : const Color(0xFF27AE60);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(cat,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                                Text(
                                    '₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: color)),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                  onPressed: () =>
                                      _form(context, db, existing: b),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => deleteWithUndo(
                                    context,
                                    collection: 'budgets',
                                    id: b['id'],
                                    data: b,
                                    label: 'Budget removed',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ratio.clamp(0, 1).toDouble(),
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                                color: color,
                              ),
                            ),
                            if (over)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                    'Over by ₹${(spent - limit).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFE74C3C),
                                        fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'budgetFab',
        onPressed: () => _form(context, db),
        icon: const Icon(Icons.add),
        label: const Text('Budget'),
      ),
    );
  }

  void _form(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final limitC = TextEditingController(
        text: existing == null ? '' : '${existing['limit'] ?? ''}');
    String category = existing?['category'] ?? 'Food';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ExpensesScreen.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => category = v ?? 'Food',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: limitC,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Monthly limit', prefixText: '₹ '),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                onPressed: () async {
                  final limit = double.tryParse(limitC.text.trim());
                  if (limit == null) return;
                  final data = {'category': category, 'limit': limit};
                  if (existing != null) {
                    await saveWithUndo(
                      ctx,
                      collection: 'budgets',
                      id: existing['id'],
                      previousData: existing,
                      newData: data,
                      label: 'Budget updated',
                    );
                  } else {
                    await db.add('budgets', data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
