import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../services/db_service.dart';
import '../widgets/common.dart';

/// Shopping Hub — grocery lists, wishlists, anything to buy. Items carry
/// quantity and optional price, with a running total for what's still
/// unpurchased so you know the trip's cost before you go.
class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  static const lists = ['Grocery', 'Shopping', 'Wishlist'];
  String _list = 'Grocery';

  @override
  Widget build(BuildContext context) {
    final db = DbService.instance;
    return Scaffold(
      appBar: const GradientAppBar(title: Text('Shopping')),
      body: ContentWidth(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: lists
                    .map((l) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(l),
                            selected: _list == l,
                            onSelected: (_) => setState(() => _list = l),
                          ),
                        ))
                    .toList(),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: db.stream('shopping'),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items =
                      snap.data!.where((i) => (i['list'] ?? 'Grocery') == _list)
                          .toList();
                  if (items.isEmpty) {
                    return EmptyState(
                        icon: Icons.shopping_cart_outlined,
                        message: '$_list list is empty');
                  }

                  final pending =
                      items.where((i) => i['bought'] != true).toList();
                  final bought =
                      items.where((i) => i['bought'] == true).toList();
                  final remaining = pending.fold<double>(
                      0,
                      (s, i) =>
                          s +
                          ((i['price'] ?? 0) as num).toDouble() *
                              ((i['qty'] ?? 1) as num).toDouble());

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                    children: [
                      if (remaining > 0)
                        Card(
                          color: const Color(0xFF16A085)
                              .withValues(alpha: 0.12),
                          child: ListTile(
                            leading: const Icon(Icons.calculate_outlined,
                                color: Color(0xFF16A085)),
                            title: const Text('Estimated total'),
                            trailing: Text(
                                '₹${remaining.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF16A085))),
                          ),
                        ),
                      ...pending.map((i) => _tile(context, db, i)),
                      if (bought.isNotEmpty)
                        const SectionHeader('Purchased',
                            color: Color(0xFF7F8C8D)),
                      ...bought.map((i) => _tile(context, db, i)),
                      if (bought.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.delete_sweep_outlined),
                            label: const Text('Clear purchased'),
                            onPressed: () async {
                              for (final b in bought) {
                                await db.remove('shopping', b['id']);
                              }
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'shopFab',
        onPressed: () => _form(context, db),
        icon: const Icon(Icons.add),
        label: const Text('Item'),
      ),
    );
  }

  Widget _tile(BuildContext context, DbService db, Map<String, dynamic> i) {
    final bought = i['bought'] == true;
    final qty = ((i['qty'] ?? 1) as num).toInt();
    final price = ((i['price'] ?? 0) as num).toDouble();
    return Card(
      child: ListTile(
        onTap: () => _form(context, db, existing: i),
        leading: Checkbox(
          value: bought,
          onChanged: (v) =>
              db.update('shopping', i['id'], {'bought': v ?? false}),
        ),
        title: Text(i['name'] ?? '',
            style: TextStyle(
                decoration: bought ? TextDecoration.lineThrough : null,
                color: bought ? Colors.grey : null)),
        subtitle: Text([
          if (qty > 1) 'x$qty',
          if (price > 0) '₹${price.toStringAsFixed(0)} each',
        ].join(' • ')),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => deleteWithUndo(
            context,
            collection: 'shopping',
            id: i['id'],
            data: i,
            label: 'Item removed',
          ),
        ),
      ),
    );
  }

  void _form(BuildContext context, DbService db,
      {Map<String, dynamic>? existing}) {
    final nameC = TextEditingController(text: existing?['name'] ?? '');
    final qtyC = TextEditingController(
        text: '${((existing?['qty'] ?? 1) as num).toInt()}');
    final priceC = TextEditingController(
        text: existing == null || (existing['price'] ?? 0) == 0
            ? ''
            : '${existing['price']}');
    String list = existing?['list'] ?? _list;

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
            TextField(
                controller: nameC,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Item')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: qtyC,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Quantity')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                    controller: priceC,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Price each', prefixText: '₹ ')),
              ),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: list,
              decoration: const InputDecoration(labelText: 'List'),
              items: _ShoppingScreenState.lists
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => list = v ?? 'Grocery',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                onPressed: () async {
                  if (nameC.text.trim().isEmpty) return;
                  final data = {
                    'name': nameC.text.trim(),
                    'qty': int.tryParse(qtyC.text.trim()) ?? 1,
                    'price': double.tryParse(priceC.text.trim()) ?? 0,
                    'list': list,
                    'bought': existing?['bought'] ?? false,
                  };
                  if (existing != null) {
                    await saveWithUndo(
                      ctx,
                      collection: 'shopping',
                      id: existing['id'],
                      previousData: existing,
                      newData: data,
                      label: 'Item updated',
                    );
                  } else {
                    await db.add('shopping', data);
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
