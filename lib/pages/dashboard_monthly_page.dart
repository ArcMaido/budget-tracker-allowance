part of '../main.dart';

extension _DashboardMonthlySection on _AllowanceBudgetHomeState {
  Widget _buildMonthlySection() {
    final scheme = Theme.of(context).colorScheme;
    final summaryRows = _buildPeriodSummaryRows();
    const rowsPerPage = 8;
    final totalRows = summaryRows.length;
    final maxPage =
      totalRows == 0 ? 0 : ((totalRows - 1) ~/ rowsPerPage);
    final safePage = _monthlyPage.clamp(0, maxPage);
    if (safePage != _monthlyPage) {
      _monthlyPage = safePage;
    }
    final startIndex = totalRows == 0 ? 0 : safePage * rowsPerPage;
    final endIndex = totalRows == 0
        ? 0
      : math.min(startIndex + rowsPerPage, totalRows);
    final visibleRows = totalRows == 0
        ? <_PeriodSummaryRow>[]
        : summaryRows.sublist(startIndex, endIndex);
    final displayRows = List<_PeriodSummaryRow?>.generate(
      rowsPerPage,
      (index) => index < visibleRows.length ? visibleRows[index] : null,
    );
    final periodLabel = _summaryPeriod == 'month'
        ? 'Month'
        : _summaryPeriod == 'week'
            ? 'Week'
            : 'Year';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Summaries',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Compact calendar filters: pick period and date.'),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Month'),
                      selected: _summaryPeriod == 'month',
                      onSelected: (_) => _runState(() {
                        _summaryPeriod = 'month';
                        _monthlyPage = 0;
                      }),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Week'),
                      selected: _summaryPeriod == 'week',
                      onSelected: (_) => _runState(() {
                        _summaryPeriod = 'week';
                        _monthlyPage = 0;
                      }),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Year'),
                      selected: _summaryPeriod == 'year',
                      onSelected: (_) => _runState(() {
                        _summaryPeriod = 'year';
                        _monthlyPage = 0;
                      }),
                    ),
                    if (_summaryPeriod == 'week') ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_month_outlined,
                            size: 16),
                        label: const Text('Date'),
                        onPressed: _pickMonthlyAnchorDate,
                      ),
                    ],
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Manage Columns',
                      onSelected: (value) {
                        _runState(() {
                          switch (value) {
                            case 'allowance':
                              _monthlyShowAllowance = !_monthlyShowAllowance;
                              break;
                            case 'spent':
                              _monthlyShowSpent = !_monthlyShowSpent;
                              break;
                            case 'saved':
                              _monthlyShowSaved = !_monthlyShowSaved;
                              break;
                            case 'rate':
                              _monthlyShowRate = !_monthlyShowRate;
                              break;
                          }
                          if (_monthlyVisibleColumnCount() == 1) {
                            _monthlyShowAllowance = true;
                          }
                        });
                      },
                      itemBuilder: (context) => [
                        CheckedPopupMenuItem<String>(
                          value: 'allowance',
                          checked: _monthlyShowAllowance,
                          child: const Text('Allowance'),
                        ),
                        CheckedPopupMenuItem<String>(
                          value: 'spent',
                          checked: _monthlyShowSpent,
                          child: const Text('Spent'),
                        ),
                        CheckedPopupMenuItem<String>(
                          value: 'saved',
                          checked: _monthlyShowSaved,
                          child: const Text('Saved'),
                        ),
                        CheckedPopupMenuItem<String>(
                          value: 'rate',
                          checked: _monthlyShowRate,
                          child: const Text('Spend Rate'),
                        ),
                      ],
                      child: const Chip(
                        avatar: Icon(Icons.view_column_outlined, size: 16),
                        label: Text('Columns'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(scheme.surfaceContainerHigh),
                    headingTextStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    columnSpacing: 26,
                    horizontalMargin: 14,
                    columns: [
                      DataColumn(label: Text(periodLabel.toUpperCase())),
                      if (_monthlyShowAllowance)
                        const DataColumn(label: Text('ALLOWANCE')),
                      if (_monthlyShowSpent)
                        const DataColumn(label: Text('SPENT')),
                      if (_monthlyShowSaved)
                        const DataColumn(label: Text('SAVED')),
                      if (_monthlyShowRate)
                        const DataColumn(label: Text('SPEND RATE')),
                    ],
                    rows: displayRows.map((row) {
                      if (row == null) {
                        return DataRow(
                          cells: [
                            const DataCell(Text('')),
                            if (_monthlyShowAllowance)
                              const DataCell(Text('')),
                            if (_monthlyShowSpent)
                              const DataCell(Text('')),
                            if (_monthlyShowSaved)
                              const DataCell(Text('')),
                            if (_monthlyShowRate)
                              const DataCell(Text('')),
                          ],
                        );
                      }

                      final saved = row.allowance - row.spent;
                      final rate = row.allowance > 0
                          ? (row.spent / row.allowance) * 100
                          : 0.0;
                      return DataRow(cells: [
                        DataCell(Text(row.label)),
                        if (_monthlyShowAllowance)
                          DataCell(Text(_money(row.allowance))),
                        if (_monthlyShowSpent)
                          DataCell(Text(_money(row.spent))),
                        if (_monthlyShowSaved)
                          DataCell(Text(_money(saved),
                              style: TextStyle(
                                  color: saved < 0
                                      ? Colors.red.shade700
                                      : Colors.green.shade700))),
                        if (_monthlyShowRate)
                          DataCell(Text('${rate.toStringAsFixed(1)}%')),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalRows == 0
                      ? 'No rows'
                      : 'Showing ${startIndex + 1} - $endIndex of $totalRows',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: safePage > 0
                          ? () => _runState(() => _monthlyPage = safePage - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('${safePage + 1}/${maxPage + 1}'),
                    IconButton(
                      onPressed: safePage < maxPage
                          ? () => _runState(() => _monthlyPage = safePage + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
