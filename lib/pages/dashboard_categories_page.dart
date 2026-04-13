part of '../main.dart';

extension _DashboardCategoriesSection on _AllowanceBudgetHomeState {
  Widget _buildCategorySection() {
    final scheme = Theme.of(context).colorScheme;
    final current = _currentMonthTransactions();
    final spentByCategory = <String, double>{};
    for (final tx in current) {
      spentByCategory[tx.category] =
          (spentByCategory[tx.category] ?? 0) + tx.amount;
    }

    final names = _data.categories.keys.toList()..sort();
    final allowance = _allowanceForMonthKey(_nowMonthKey());
    final totalCategoryBudget = _data.categories.values
      .fold<double>(0, (sum, value) => sum + value);
    final remainingAllowanceAfterBudgets = allowance - totalCategoryBudget;
    final allocationRate =
      allowance > 0 ? (totalCategoryBudget / allowance) * 100 : 0.0;
    final allocationRatio = allowance > 0 ? (totalCategoryBudget / allowance) : 0.0;
    final statusGreen = const Color(0xFF166534);
    final statusOrange = Colors.orange.shade700;
    final statusRed = scheme.error;
    final statusColor = allowance <= 0
      ? scheme.onSurfaceVariant
      : allocationRatio >= 1
        ? statusRed
        : allocationRatio >= 0.85
          ? statusOrange
          : statusGreen;
    final statusText = allowance <= 0
      ? 'Set allowance first'
      : allocationRatio >= 1
        ? 'Reached allowance'
        : allocationRatio >= 0.85
          ? 'Almost reached allowance'
          : 'No need to worry';
    final remainingAllocationColor = allowance <= 0
      ? scheme.onSurfaceVariant
      : remainingAllowanceAfterBudgets <= 0
        ? statusRed
        : (remainingAllowanceAfterBudgets / allowance) <= 0.15
          ? statusOrange
          : statusGreen;
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
                    builder: (context, summaryConstraints) {
                      const spacing = 8.0;
                      final width = summaryConstraints.maxWidth;
                      final columns = width < AppBreakpoints.compact
                          ? 1
                          : width < AppBreakpoints.medium
                              ? 2
                              : 4;
                      final tileWidth =
                          (width - (spacing * (columns - 1))) / columns;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(
                            width: tileWidth,
                            child: _KpiTile(
                              title: 'This Month Allowance',
                              value: _money(allowance),
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: _KpiTile(
                              title: 'Total Category Budgets',
                              value: _money(totalCategoryBudget),
                              valueColor: statusColor,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: _KpiTile(
                              title: 'Budget Status',
                              value: allowance > 0
                                  ? '${allocationRate.toStringAsFixed(0)}% · $statusText'
                                  : statusText,
                              valueColor: statusColor,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: _KpiTile(
                              title: 'Remaining to Allocate',
                              value: _money(remainingAllowanceAfterBudgets),
                              valueColor: remainingAllocationColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
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
                    LayoutBuilder(
                      builder: (context, tableConstraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: tableConstraints.maxWidth,
                            ),
                            child: DataTable(
                              columnSpacing: 28,
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
                                final usageColor = budget <= 0
                                    ? scheme.onSurfaceVariant
                                    : pct >= 100
                                        ? statusRed
                                        : pct >= 85
                                            ? statusOrange
                                            : statusGreen;
                                final remainingColor = budget <= 0
                                    ? scheme.onSurfaceVariant
                                    : remaining <= 0
                                        ? statusRed
                                        : (remaining / budget) <= 0.15
                                            ? statusOrange
                                            : statusGreen;
                                return DataRow(cells: [
                                  DataCell(Text(name)),
                                  DataCell(Text(_money(budget))),
                                  DataCell(Text(_money(spent))),
                                  DataCell(Text(_money(remaining),
                                      style: TextStyle(color: remainingColor))),
                                  DataCell(SizedBox(
                                      width: 130,
                                      child: Text(
                                        '${pct.toStringAsFixed(0)}%',
                                        style: TextStyle(color: usageColor),
                                      ))),
                                ]);
                              }).toList(),
                            ),
                          ),
                        );
                      },
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
