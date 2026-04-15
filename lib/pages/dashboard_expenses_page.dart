part of '../main.dart';

extension _DashboardExpensesSection on _AllowanceBudgetHomeState {
  Widget _buildMainArea(DashboardStats stats, List<String> categoryNames) {
    final scheme = Theme.of(context).colorScheme;

    final panelLeft = Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expenses + Insights',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Quick add and monitor spending.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                      'MONTH ${_monthLabel(_nowMonthKey()).toUpperCase()}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < AppBreakpoints.compact;
                final titleWidth = compact ? constraints.maxWidth : 190.0;
                final amountWidth = compact ? constraints.maxWidth : 130.0;
                final categoryWidth = compact ? constraints.maxWidth : 150.0;
                final dateWidth = compact ? constraints.maxWidth : 150.0;

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: titleWidth,
                      child: TextField(
                        controller: _expenseTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Expense name',
                          hintText: 'e.g., Lunch',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: amountWidth,
                      child: TextField(
                        controller: _expenseAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          hintText: 'e.g., 15',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: categoryWidth,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: categoryNames.contains(_expenseCategory)
                            ? _expenseCategory
                            : (categoryNames.isNotEmpty
                                ? categoryNames.first
                                : null),
                        items: categoryNames
                            .map((name) => DropdownMenuItem(
                                value: name,
                                child: Text(name,
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: categoryNames.isEmpty
                            ? null
                            : (v) {
                                if (v != null) {
                                  _runState(() => _expenseCategory = v);
                                }
                              },
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: dateWidth,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                        ),
                        icon: const Icon(Icons.event),
                        label: Text(
                          DateFormat('MMM d, yyyy').format(_expenseDate),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _expenseDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            _runState(() => _expenseDate = picked);
                          }
                        },
                      ),
                    ),
                    if (compact)
                      SizedBox(
                        width: constraints.maxWidth,
                        child: FilledButton.icon(
                          onPressed: categoryNames.isEmpty ? null : _addExpense,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            minimumSize: const Size(0, 44),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Add Expense'),
                        ),
                      )
                    else
                      FilledButton.icon(
                        onPressed: categoryNames.isEmpty ? null : _addExpense,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          minimumSize: const Size(0, 44),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add Expense'),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < AppBreakpoints.compact;
                if (compact) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                          width: constraints.maxWidth,
                          child: _KpiTile(
                              title: 'Top Category',
                              value: stats.topCategoryLabel)),
                      SizedBox(
                          width: constraints.maxWidth,
                          child: _KpiTile(
                              title: 'This Week Spent',
                              value: _money(stats.weekSpent))),
                      SizedBox(
                          width: constraints.maxWidth,
                          child: _KpiTile(
                              title: 'Largest Expense',
                              value: _money(stats.largestExpense))),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                        child: _KpiTile(
                            title: 'Top Category',
                            value: stats.topCategoryLabel)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _KpiTile(
                            title: 'This Week Spent',
                            value: _money(stats.weekSpent))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _KpiTile(
                            title: 'Largest Expense',
                            value: _money(stats.largestExpense))),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: stats.remaining < 0 || stats.percentUsed >= 85
                    ? scheme.errorContainer
                    : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: stats.remaining < 0 || stats.percentUsed >= 85
                      ? scheme.error
                      : scheme.primary,
                ),
              ),
              child: Text(
                stats.remaining < 0
                    ? 'Budget exceeded. Reduce non-essential expenses.'
                    : (stats.percentUsed >= 85
                        ? 'Close to monthly limit.'
                        : 'You are on track for this month.'),
                style: TextStyle(
                  color: stats.remaining < 0 || stats.percentUsed >= 85
                      ? scheme.onErrorContainer
                      : scheme.onPrimaryContainer,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final allowancePanel = Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Allowance',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Allowance for ${DateFormat('MMM yyyy').format(_allowanceMonth)}: ${_money(_allowanceForMonthKey(_monthKey(_allowanceMonth)))}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
            ),
            const SizedBox(height: 10),
            if (!_isEditingAllowance)
              OutlinedButton.icon(
                onPressed: () {
                  _runState(() {
                    _allowanceController.text =
                        _allowanceForMonthKey(_monthKey(_allowanceMonth))
                            .toStringAsFixed(0);
                    _isEditingAllowance = true;
                  });
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Set amount'),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: _pickAllowanceMonth,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                    'Select month (${DateFormat('MMM yyyy').format(_allowanceMonth)})'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _allowanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monthly allowance',
                  hintText: 'e.g., 350',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton(
                    onPressed: () async {
                      final saved = await _saveAllowance();
                      if (saved && mounted) {
                        _runState(() => _isEditingAllowance = false);
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 14),
                    ),
                    child: const Text('Save'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      _runState(() => _isEditingAllowance = false);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            const Text(
                'Tip: Allowance is stored per month in your device storage.'),
          ],
        ),
      ),
    );

    final spentVsAllowancePanel = Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spent vs allowance: ${stats.percentUsed.toStringAsFixed(1)}% used',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: math.min(stats.percentUsed / 100, 1),
                minHeight: 16,
                backgroundColor: scheme.surfaceContainerHighest,
                color: stats.percentUsed > 100 ? scheme.error : scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            children: [
              allowancePanel,
              const SizedBox(height: 10),
              spentVsAllowancePanel,
              const SizedBox(height: 10),
              panelLeft,
            ],
          );
        }
        return Column(
          children: [
            allowancePanel,
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: panelLeft),
                const SizedBox(width: 10),
                Expanded(child: spentVsAllowancePanel),
              ],
            ),
          ],
        );
      },
    );
  }
}
