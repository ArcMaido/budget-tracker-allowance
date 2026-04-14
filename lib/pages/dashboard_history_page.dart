part of '../main.dart';

extension _DashboardHistorySection on _AllowanceBudgetHomeState {
  Widget _buildHistorySection(
      List<ExpenseTx> rows, List<String> categories, List<String> months) {
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
                  const Text('Transaction History',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                      'Use filters to quickly find the expense you need.'),
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
                              controller: _searchController,
                              onChanged: (_) {
                                if (_historyPage != 0) {
                                  _runState(() => _historyPage = 0);
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Search by expense name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: compact ? constraints.maxWidth : 180,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _filterCategory,
                              items: [
                                const DropdownMenuItem(
                                    value: 'all',
                                    child: Text('All categories')),
                                ...categories.map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c,
                                        overflow: TextOverflow.ellipsis))),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  _runState(() {
                                    _filterCategory = v;
                                    _historyPage = 0;
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          SizedBox(
                            width: compact ? constraints.maxWidth : 180,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _filterMonth,
                              items: [
                                const DropdownMenuItem(
                                    value: 'all', child: Text('All months')),
                                ...months.map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(_monthLabel(m),
                                        overflow: TextOverflow.ellipsis))),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  _runState(() {
                                    _filterMonth = v;
                                    _historyPage = 0;
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          if (compact)
                            SizedBox(
                              width: constraints.maxWidth,
                              child: OutlinedButton(
                                onPressed: () {
                                  _runState(() {
                                    _searchController.clear();
                                    _filterCategory = 'all';
                                    _filterMonth = 'all';
                                    _historyPage = 0;
                                  });
                                },
                                child: const Text('Clear'),
                              ),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () => _exportHistoryToExcel(rows),
                              icon: const Icon(Icons.table_view_outlined),
                              label: const Text('Export Excel'),
                            ),
                          if (compact)
                            SizedBox(
                              width: constraints.maxWidth,
                              child: FilledButton.icon(
                                onPressed: () => _exportHistoryToExcel(rows),
                                icon: const Icon(Icons.table_view_outlined),
                                label: const Text('Export Excel'),
                              ),
                            )
                          else
                            OutlinedButton(
                              onPressed: () {
                                _runState(() {
                                  _searchController.clear();
                                  _filterCategory = 'all';
                                  _filterMonth = 'all';
                                  _historyPage = 0;
                                });
                              },
                              child: const Text('Clear'),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (rows.isEmpty)
                    const Text('No transactions found for this filter.')
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact =
                            constraints.maxWidth < AppBreakpoints.compact;
                      final maxPage = rows.isEmpty
                        ? 0
                        : ((rows.length - 1) ~/ _historyRowsPerPage);
                      final currentPage = _historyPage.clamp(0, maxPage);
                      final start = currentPage * _historyRowsPerPage;
                        final end =
                            math.min(start + _historyRowsPerPage, rows.length);
                        final paginatedRows = rows.sublist(start, end);
                        if (compact) {
                          return Column(
                            children: paginatedRows.map((tx) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(tx.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                      '${DateFormat('MMM d, yyyy').format(tx.date)} • ${tx.category}'),
                                  trailing: Text(
                                    _money(tx.amount),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 28,
                            dataRowMinHeight: 48,
                            dataRowMaxHeight: 56,
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Title')),
                              DataColumn(label: Text('Category')),
                              DataColumn(numeric: true, label: Text('Amount')),
                            ],
                            rows: paginatedRows.map((tx) {
                              return DataRow(cells: [
                                DataCell(Text(
                                    DateFormat('MMM d, yyyy').format(tx.date))),
                                DataCell(SizedBox(
                                    width: 220,
                                    child: Text(tx.title,
                                        overflow: TextOverflow.ellipsis))),
                                DataCell(SizedBox(
                                    width: 120,
                                    child: Text(tx.category,
                                        overflow: TextOverflow.ellipsis))),
                                DataCell(Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(_money(tx.amount)))),
                              ]);
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        rows.isEmpty
                            ? 'No rows'
                          : 'Showing ${((_historyPage.clamp(0, ((rows.length - 1) ~/ _historyRowsPerPage))) * _historyRowsPerPage) + 1} - ${math.min(((_historyPage.clamp(0, ((rows.length - 1) ~/ _historyRowsPerPage))) + 1) * _historyRowsPerPage, rows.length)} of ${rows.length}',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      Row(
                        children: [
                          IconButton(
                          onPressed: _historyPage.clamp(
                                0,
                                rows.isEmpty
                                  ? 0
                                  : ((rows.length - 1) ~/
                                    _historyRowsPerPage)) >
                              0
                            ? () => _runState(() => _historyPage =
                              _historyPage
                                  .clamp(
                                    0,
                                    rows.isEmpty
                                      ? 0
                                      : ((rows.length - 1) ~/
                                        _historyRowsPerPage)) -
                                1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            '${(_historyPage.clamp(0, rows.isEmpty ? 0 : ((rows.length - 1) ~/ _historyRowsPerPage))) + 1}/${rows.isEmpty ? 1 : ((rows.length - 1) ~/ _historyRowsPerPage) + 1}'),
                          IconButton(
                          onPressed: ((_historyPage.clamp(
                                    0,
                                    rows.isEmpty
                                      ? 0
                                      : ((rows.length - 1) ~/
                                        _historyRowsPerPage)) +
                                  1) *
                                _historyRowsPerPage) <
                              rows.length
                            ? () => _runState(() => _historyPage =
                              _historyPage
                                  .clamp(
                                    0,
                                    rows.isEmpty
                                      ? 0
                                      : ((rows.length - 1) ~/
                                        _historyRowsPerPage)) +
                                1)
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
          ),
        ),
      ),
    );
  }
}
