part of '../main.dart';

extension _DashboardCategoriesSection on _AllowanceBudgetHomeState {
  Widget _buildCategorySection() {
    final current = _currentMonthTransactions();
    final spentByCategory = <String, double>{};
    for (final tx in current) {
      spentByCategory[tx.category] =
          (spentByCategory[tx.category] ?? 0) + tx.amount;
    }

    final names = _data.categories.keys.toList()..sort();
    final minPanelHeight = MediaQuery.sizeOf(context).height * 0.62;

    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minPanelHeight),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Categories',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                      'Assign budget per category to see where money goes.'),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          constraints.maxWidth < AppBreakpoints.compact;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: compact ? constraints.maxWidth : 220,
                            child: TextField(
                              controller: _categoryNameController,
                              decoration: const InputDecoration(
                                labelText: 'Category name',
                                hintText: 'e.g., Bills',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: compact ? constraints.maxWidth : 180,
                            child: TextField(
                              controller: _categoryBudgetController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Category budget',
                                hintText: 'e.g., 100',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: compact ? constraints.maxWidth : 230,
                            child: Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _upsertCategory,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      minimumSize: const Size(0, 40),
                                    ),
                                    child: const Text('Add / Update'),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _removeCategory,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      minimumSize: const Size(0, 40),
                                    ),
                                    child: const Text('Remove'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (names.isEmpty)
                    const Text(
                        'No categories yet. Add one above to start budgeting.')
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Budget')),
                          DataColumn(label: Text('Spent')),
                          DataColumn(label: Text('Remaining')),
                          DataColumn(label: Text('Usage')),
                        ],
                        rows: names.map((name) {
                          final budget = _data.categories[name] ?? 0;
                          final spent = spentByCategory[name] ?? 0;
                          final remaining = budget - spent;
                          final pct = budget > 0 ? (spent / budget) * 100 : 0.0;
                          return DataRow(cells: [
                            DataCell(Text(name)),
                            DataCell(Text(_money(budget))),
                            DataCell(Text(_money(spent))),
                            DataCell(Text(_money(remaining),
                                style: TextStyle(
                                    color: remaining < 0
                                        ? Colors.red.shade700
                                        : Colors.green.shade700))),
                            DataCell(SizedBox(
                                width: 130,
                                child: Text('${pct.toStringAsFixed(0)}%'))),
                          ]);
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
