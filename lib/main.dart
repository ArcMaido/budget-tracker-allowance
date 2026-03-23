import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:allowance_budget_dashboard/main.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
	runApp(const AllowanceBudgetApp());
}

class AllowanceBudgetApp extends StatefulWidget {
	const AllowanceBudgetApp({super.key});

	@override
	State<AllowanceBudgetApp> createState() => _AllowanceBudgetAppState();
}

class _AllowanceBudgetAppState extends State<AllowanceBudgetApp> {
	bool _darkMode = false;

	@override
	Widget build(BuildContext context) {
		const lightScheme = ColorScheme(
			brightness: Brightness.light,
			primary: Color(0xFF1A7A59),
			onPrimary: Color(0xFFFFFFFF),
			secondary: Color(0xFF4F6358),
			onSecondary: Color(0xFFFFFFFF),
			error: Color(0xFFBA1A1A),
			onError: Color(0xFFFFFFFF),
			surface: Color(0xFFF7FAF8),
			onSurface: Color(0xFF16201B),
			outline: Color(0xFF717D75),
		);
		const darkScheme = ColorScheme(
			brightness: Brightness.dark,
			primary: Color(0xFF7EDDB9),
			onPrimary: Color(0xFF003826),
			secondary: Color(0xFFB5CCBE),
			onSecondary: Color(0xFF21352C),
			error: Color(0xFFFFB4AB),
			onError: Color(0xFF690005),
			surface: Color(0xFF0F1613),
			onSurface: Color(0xFFDDE5DF),
			outline: Color(0xFF8B978F),
		);

		final base = ThemeData(
			useMaterial3: true,
			colorScheme: lightScheme,
			fontFamily: 'Segoe UI',
		);
		final darkBase = ThemeData(
			useMaterial3: true,
			colorScheme: darkScheme,
			fontFamily: 'Segoe UI',
		);

		return MaterialApp(
			debugShowCheckedModeBanner: false,
			title: 'Allowance Budget Dashboard',
			themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
			theme: base.copyWith(
				scaffoldBackgroundColor: lightScheme.surface,
				cardTheme: const CardThemeData(
					color: Colors.white,
					elevation: 0,
					margin: EdgeInsets.zero,
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.all(Radius.circular(16)),
						side: BorderSide(color: Color(0xFFD8E3DC)),
					),
				),
				dividerColor: const Color(0xFFE5ECE7),
				inputDecorationTheme: InputDecorationTheme(
					filled: true,
					fillColor: const Color(0xFFFBFDFC),
					border: OutlineInputBorder(
						borderRadius: BorderRadius.circular(12),
						borderSide: const BorderSide(color: Color(0xFFD5E0D8)),
					),
				),
			),
			darkTheme: darkBase.copyWith(
				scaffoldBackgroundColor: darkScheme.surface,
				cardTheme: const CardThemeData(
					color: Color(0xFF17201C),
					elevation: 0,
					margin: EdgeInsets.zero,
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.all(Radius.circular(16)),
						side: BorderSide(color: Color(0xFF2D3933)),
					),
				),
				dividerColor: const Color(0xFF31403A),
				inputDecorationTheme: InputDecorationTheme(
					filled: true,
					fillColor: const Color(0xFF121A17),
					border: OutlineInputBorder(
						borderRadius: BorderRadius.circular(12),
						borderSide: const BorderSide(color: Color(0xFF304039)),
					),
				),
			),
			home: DashboardPage(
				isDarkMode: _darkMode,
				onToggleDarkMode: (enabled) {
					setState(() => _darkMode = enabled);
				},
			),
		);
	}
}

class DashboardPage extends StatefulWidget {
	const DashboardPage({
		super.key,
		required this.isDarkMode,
		required this.onToggleDarkMode,
	});

	final bool isDarkMode;
	final ValueChanged<bool> onToggleDarkMode;

	@override
	State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
	static const _storageKey = 'allowance-dashboard-v3-flutter';
	static const _defaultProfileName = 'Student User';
	static const _defaultProfileRole = 'Budget Tracker Owner';

	final NumberFormat _moneyFormat = NumberFormat.currency(
		locale: 'en_PH',
		symbol: 'PHP ',
		decimalDigits: 0,
	);

	BudgetData _data = BudgetData.defaultState();
	bool _loading = true;

	final _allowanceController = TextEditingController();
	final _expenseTitleController = TextEditingController();
	final _expenseAmountController = TextEditingController();
	final _categoryNameController = TextEditingController();
	final _categoryBudgetController = TextEditingController();
	final _searchController = TextEditingController();

	String _expenseCategory = 'Food';
	DateTime _expenseDate = DateTime.now();
	String _filterCategory = 'all';
	String _filterMonth = 'all';
	String _lineChartCategory = 'all';
	final Map<String, Color> _categoryLineColors = <String, Color>{};
	String _summaryPeriod = 'month';
	int _summaryYear = DateTime.now().year;
	int _summaryMonth = DateTime.now().month;
	int _summaryStartDay = 1;
	int _monthlyRowsPerPage = 8;
	int _monthlyPage = 0;
	int _historyRowsPerPage = 10;
	int _historyPage = 0;
	bool _monthlyShowAllowance = true;
	bool _monthlyShowSpent = true;
	bool _monthlyShowSaved = true;
	bool _monthlyShowRate = true;
	int _selectedNavIndex = 0;
	String _profileName = _defaultProfileName;
	String _profileRole = _defaultProfileRole;
	IconData _profileAvatarIcon = Icons.person;
	Uint8List? _profileAvatarImageBytes;

	static const List<String> _navLabels = [
		'Overview',
		'Expenses',
		'Categories',
		'Monthly',
		'History',
		'About',
	];

	static const List<IconData> _navIcons = [
		Icons.dashboard_outlined,
		Icons.receipt_long_outlined,
		Icons.category_outlined,
		Icons.bar_chart_outlined,
		Icons.history,
		Icons.info_outline,
	];

	static const List<Color> _categoryLineSeedColors = [
		Color(0xFF1A7A59),
		Color(0xFFE06C2F),
		Color(0xFF2E7D32),
		Color(0xFF1565C0),
		Color(0xFF6A1B9A),
		Color(0xFFAD1457),
		Color(0xFF00897B),
		Color(0xFFF4511E),
		Color(0xFF3949AB),
		Color(0xFF43A047),
		Color(0xFFC62828),
		Color(0xFF546E7A),
	];

	@override
	void initState() {
		super.initState();
		_load();
		_searchController.addListener(() => setState(() {}));
	}

	@override
	void dispose() {
		_allowanceController.dispose();
		_expenseTitleController.dispose();
		_expenseAmountController.dispose();
		_categoryNameController.dispose();
		_categoryBudgetController.dispose();
		_searchController.dispose();
		super.dispose();
	}

	Future<void> _load() async {
		final prefs = await SharedPreferences.getInstance();
		final raw = prefs.getString(_storageKey);
		setState(() {
			_data = raw == null ? BudgetData.defaultState() : BudgetData.fromJson(raw);
			_syncCategoryLineColors();
			_allowanceController.text = _data.monthlyAllowance.toStringAsFixed(0);
			_expenseCategory = _data.categories.keys.isNotEmpty
					? _data.categories.keys.first
					: 'General';
			_loading = false;
		});
	}

	void _syncCategoryLineColors() {
		final names = _data.categories.keys.toSet();
		_categoryLineColors.removeWhere((name, _) => !names.contains(name));
		final used = _categoryLineColors.values.toSet();
		final sortedNames = names.toList()..sort();
		for (final name in sortedNames) {
			if (_categoryLineColors.containsKey(name)) {
				continue;
			}
			_categoryLineColors[name] = _nextAvailableCategoryColor(used);
			used.add(_categoryLineColors[name]!);
		}
	}

	Color _nextAvailableCategoryColor(Set<Color> used) {
		for (final seed in _categoryLineSeedColors) {
			if (!used.contains(seed)) {
				return seed;
			}
		}

		for (var i = 0; i < 360; i++) {
			final hue = ((used.length * 41) + (i * 37)) % 360;
			final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.67, 0.46).toColor();
			if (!used.contains(color)) {
				return color;
			}
		}

		return Colors.primaries[used.length % Colors.primaries.length];
	}

	Future<void> _save() async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setString(_storageKey, _data.toJson());
	}

	String _money(num value) => _moneyFormat.format(value);

	String _monthKey(DateTime dt) => DateFormat('yyyy-MM').format(dt);

	String _monthLabel(String key) {
		final parts = key.split('-');
		if (parts.length != 2) {
			return key;
		}
		final year = int.tryParse(parts[0]) ?? DateTime.now().year;
		final month = int.tryParse(parts[1]) ?? DateTime.now().month;
		return DateFormat('MMM yyyy').format(DateTime(year, month));
	}

	String _nowMonthKey() => _monthKey(DateTime.now());

	List<ExpenseTx> _currentMonthTransactions() {
		final key = _nowMonthKey();
		return _data.transactions.where((tx) => _monthKey(tx.date) == key).toList();
	}

	DashboardStats _stats() => DashboardStats.fromData(_data, DateTime.now());

	List<String> _recentMonths(int count) {
		final now = DateTime.now();
		return List<String>.generate(count, (i) {
			final dt = DateTime(now.year, now.month - i, 1);
			return _monthKey(dt);
		});
	}

	List<String> _uniqueMonths() {
		final months = _data.transactions.map((tx) => _monthKey(tx.date)).toSet().toList();
		months.sort((a, b) => b.compareTo(a));
		return months;
	}

	List<int> _availableYears() {
		final years = <int>{
			..._data.transactions.map((tx) => tx.date.year),
			DateTime.now().year,
		}.toList();
		years.sort((a, b) => b.compareTo(a));
		return years;
	}

	List<_PeriodSummaryRow> _buildPeriodSummaryRows() {
		final years = _availableYears();
		final selectedYear = years.contains(_summaryYear) ? _summaryYear : years.first;

		if (_summaryPeriod == 'year') {
			return years.map((year) {
				final start = DateTime(year, 1, 1);
				final end = DateTime(year + 1, 1, 1);
				final spent = _data.transactions
						.where((tx) => !tx.date.isBefore(start) && tx.date.isBefore(end))
						.fold<double>(0, (sum, tx) => sum + tx.amount);
				final allowance = _data.monthlyAllowance * 12;
				return _PeriodSummaryRow(label: '$year', allowance: allowance, spent: spent);
			}).toList();
		}

		if (_summaryPeriod == 'week') {
			final daysInMonth = DateTime(selectedYear, _summaryMonth + 1, 0).day;
			final startDaySeed = _summaryStartDay.clamp(1, daysInMonth);
			final rows = <_PeriodSummaryRow>[];
			for (var startDay = startDaySeed, i = 1; startDay <= daysInMonth; startDay += 7, i++) {
				final endDay = math.min(startDay + 6, daysInMonth);
				final start = DateTime(selectedYear, _summaryMonth, startDay);
				final end = DateTime(selectedYear, _summaryMonth, endDay + 1);
				final spent = _data.transactions
						.where((tx) => !tx.date.isBefore(start) && tx.date.isBefore(end))
						.fold<double>(0, (sum, tx) => sum + tx.amount);
				final ratio = (endDay - startDay + 1) / daysInMonth;
				final allowance = _data.monthlyAllowance * ratio;
				rows.add(
					_PeriodSummaryRow(
						label: 'Week $i (${DateFormat('MMM d').format(start)} - ${DateFormat('d').format(DateTime(selectedYear, _summaryMonth, endDay))})',
						allowance: allowance,
						spent: spent,
					),
				);
			}
			return rows;
		}

		return List<_PeriodSummaryRow>.generate(12, (i) {
			final month = i + 1;
			final start = DateTime(selectedYear, month, 1);
			final end = DateTime(selectedYear, month + 1, 1);
			final spent = _data.transactions
					.where((tx) => !tx.date.isBefore(start) && tx.date.isBefore(end))
					.fold<double>(0, (sum, tx) => sum + tx.amount);
			return _PeriodSummaryRow(
				label: DateFormat('MMM yyyy').format(start),
				allowance: _data.monthlyAllowance,
				spent: spent,
			);
		});
	}

	String _monthlyRangeLabel(int selectedYear) {
		if (_summaryPeriod == 'year') {
			final years = _availableYears();
			if (years.isEmpty) {
				return '$selectedYear';
			}
			return '${years.last} - ${years.first}';
		}
		if (_summaryPeriod == 'week') {
			final start = DateTime(selectedYear, _summaryMonth, 1);
			final end = DateTime(selectedYear, _summaryMonth + 1, 0);
			return '${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
		}
		return 'Jan 1, $selectedYear - Dec 31, $selectedYear';
	}

	int _monthlyVisibleColumnCount() {
		var count = 1; // Period column is always visible.
		if (_monthlyShowAllowance) count++;
		if (_monthlyShowSpent) count++;
		if (_monthlyShowSaved) count++;
		if (_monthlyShowRate) count++;
		return count;
	}

	Future<void> _pickMonthlyAnchorDate() async {
		final initial = DateTime(_summaryYear, _summaryMonth, 1);
		final picked = await showDatePicker(
			context: context,
			initialDate: initial,
			firstDate: DateTime(2020),
			lastDate: DateTime(2100),
		);
		if (picked == null) {
			return;
		}
		setState(() {
			_summaryYear = picked.year;
			_summaryMonth = picked.month;
			_summaryStartDay = picked.day;
			_monthlyPage = 0;
		});
	}

	List<ExpenseTx> _filteredTransactions() {
		final query = _searchController.text.trim().toLowerCase();
		return _data.transactions.where((tx) {
			if (query.isNotEmpty && !tx.title.toLowerCase().contains(query)) {
				return false;
			}
			if (_filterCategory != 'all' && tx.category != _filterCategory) {
				return false;
			}
			if (_filterMonth != 'all' && _monthKey(tx.date) != _filterMonth) {
				return false;
			}
			return true;
		}).toList()
			..sort((a, b) => b.date.compareTo(a.date));
	}

	Future<void> _saveAllowance() async {
		final next = double.tryParse(_allowanceController.text.trim());
		if (next == null || next <= 0) {
			_showHint('Enter a valid monthly allowance greater than 0.');
			return;
		}
		setState(() => _data.monthlyAllowance = next);
		await _save();
	}

	Future<void> _addExpense() async {
		final title = _expenseTitleController.text.trim();
		final amount = double.tryParse(_expenseAmountController.text.trim());
		final category = _expenseCategory;
		if (title.isEmpty || amount == null || amount <= 0) {
			_showHint('Add an expense name and an amount greater than 0.');
			return;
		}

		final tx = ExpenseTx(
			id: '${DateTime.now().microsecondsSinceEpoch}',
			title: title,
			amount: amount,
			category: category,
			date: _expenseDate,
		);

		setState(() {
			_data.transactions.add(tx);
			_expenseTitleController.clear();
			_expenseAmountController.clear();
		});
		await _save();
	}

	Future<void> _upsertCategory() async {
		final name = _categoryNameController.text.trim();
		final budget = double.tryParse(_categoryBudgetController.text.trim());
		if (name.isEmpty || budget == null || budget <= 0) {
			_showHint('Category name and budget must both be valid.');
			return;
		}

		setState(() {
			_data.categories[name] = budget;
			_syncCategoryLineColors();
			_categoryNameController.clear();
			_categoryBudgetController.clear();
			if (!_data.categories.containsKey(_expenseCategory)) {
				_expenseCategory = name;
			}
		});
		await _save();
	}

	Future<void> _addCategory() async {
		final name = _categoryNameController.text.trim();
		final budget = double.tryParse(_categoryBudgetController.text.trim());
		if (name.isEmpty || budget == null || budget <= 0) {
			_showHint('Category name and budget must both be valid.');
			return;
		}

		if (_data.categories.containsKey(name)) {
			_showHint('Category already exists. Use Update instead.');
			return;
		}

		setState(() {
			_data.categories[name] = budget;
			_syncCategoryLineColors();
			_categoryNameController.clear();
			_categoryBudgetController.clear();
			if (_expenseCategory.isEmpty || !_data.categories.containsKey(_expenseCategory)) {
				_expenseCategory = name;
			}
		});
		await _save();
	}

	Future<void> _updateCategory() async {
		final name = _categoryNameController.text.trim();
		final budget = double.tryParse(_categoryBudgetController.text.trim());
		if (name.isEmpty || budget == null || budget <= 0) {
			_showHint('Category name and budget must both be valid.');
			return;
		}

		if (!_data.categories.containsKey(name)) {
			_showHint('Category not found. Use Add instead.');
			return;
		}

		setState(() {
			_data.categories[name] = budget;
			_categoryNameController.clear();
			_categoryBudgetController.clear();
		});
		await _save();
	}

	Future<void> _removeCategory() async {
		final name = _categoryNameController.text.trim();
		if (name.isEmpty) {
			_showHint('Enter a category name to remove.');
			return;
		}

		if (!_data.categories.containsKey(name)) {
			_showHint('Category not found.');
			return;
		}

		setState(() {
			_data.categories.remove(name);
			_categoryLineColors.remove(name);
			_categoryNameController.clear();
			_categoryBudgetController.clear();

			final remaining = _data.categories.keys.toList()..sort();
			if (_expenseCategory == name) {
				_expenseCategory = remaining.isNotEmpty ? remaining.first : '';
			}
			if (_filterCategory == name) {
				_filterCategory = 'all';
			}
			if (_lineChartCategory == name) {
				_lineChartCategory = 'all';
			}
		});
		await _save();
	}

	void _showHint(String text) {
		ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
	}

	void _openProfilePage() {
		Navigator.of(context).push(
			MaterialPageRoute<void>(
				builder: (_) => ProfilePage(
					isDarkMode: widget.isDarkMode,
					onToggleDarkMode: widget.onToggleDarkMode,
					initialName: _profileName,
					initialRole: _profileRole,
					initialAvatarIcon: _profileAvatarIcon,
					initialAvatarImageBytes: _profileAvatarImageBytes,
					onProfileChanged: ({required name, required role, required avatarIcon, avatarImageBytes}) {
						setState(() {
							_profileName = name;
							_profileRole = role;
							_profileAvatarIcon = avatarIcon;
							_profileAvatarImageBytes = avatarImageBytes;
						});
					},
				),
			),
		);
	}

	Widget _buildProfileButtonAvatar() {
		if (_profileAvatarImageBytes != null) {
			return CircleAvatar(
				radius: 16,
				backgroundImage: MemoryImage(_profileAvatarImageBytes!),
			);
		}

		return Icon(_profileAvatarIcon);
	}

	Widget _buildProfileButton() {
		return IconButton(
			onPressed: _openProfilePage,
			icon: _buildProfileButtonAvatar(),
			style: IconButton.styleFrom(
				backgroundColor: _profileAvatarImageBytes == null ? const Color(0xFF1A7A59) : Colors.transparent,
				foregroundColor: Colors.white,
			),
			tooltip: 'Open profile',
		);
	}

	void _openSettingsPage() {
		Navigator.of(context).push(
			MaterialPageRoute<void>(
				builder: (_) => SettingsPage(
					onLogout: () {
						Navigator.pop(context);
						setState(() {
							_data = BudgetData.defaultState();
							_profileName = _defaultProfileName;
							_profileRole = _defaultProfileRole;
							_profileAvatarIcon = Icons.account_circle;
							_profileAvatarImageBytes = null;
						});
						_save();
					},
				),
			),
		);
	}

	Widget _buildSettingsButton() {
		return IconButton(
			onPressed: _openSettingsPage,
			icon: const Icon(Icons.settings),
			style: IconButton.styleFrom(
				backgroundColor: const Color(0xFF1A7A59),
				foregroundColor: Colors.white,
			),
			tooltip: 'Settings',
		);
	}

	@override
	Widget build(BuildContext context) {
		if (_loading) {
			return const Scaffold(body: Center(child: CircularProgressIndicator()));
		}

		final stats = _stats();
		final categoryNames = _data.categories.keys.toList()..sort();
		final txRows = _filteredTransactions();
		final now = DateTime.now();
		final monthOptions = _uniqueMonths();

		if (_expenseCategory.isEmpty && categoryNames.isNotEmpty) {
			_expenseCategory = categoryNames.first;
		}
		if (!categoryNames.contains(_expenseCategory) && categoryNames.isNotEmpty) {
			_expenseCategory = categoryNames.first;
		}

		return Scaffold(
			body: SafeArea(
				child: LayoutBuilder(
					builder: (context, constraints) {
						final compact = constraints.maxWidth < AppBreakpoints.compact;
						final wide = constraints.maxWidth >= AppBreakpoints.medium;
						final padding = EdgeInsets.all(
								compact ? AppStyles.pagePaddingCompact : AppStyles.pagePaddingRegular,
						);

						final content = Padding(
							padding: padding,
							child: _buildSelectedSection(
								now: now,
								stats: stats,
								categoryNames: categoryNames,
								txRows: txRows,
								monthOptions: monthOptions,
							),
						);

						if (wide) {
							return Row(
								children: [
									NavigationRail(
										selectedIndex: _selectedNavIndex,
										onDestinationSelected: (index) {
											setState(() => _selectedNavIndex = index);
										},
										labelType: NavigationRailLabelType.all,
										destinations: List.generate(
											_navLabels.length,
											(i) => NavigationRailDestination(
												icon: Icon(_navIcons[i]),
												label: Text(_navLabels[i]),
											),
										),
									),
									const VerticalDivider(width: 1),
									Expanded(child: content),
								],
							);
						}

						return Column(
							children: [
								Expanded(child: content),
								NavigationBar(
									selectedIndex: _selectedNavIndex,
									onDestinationSelected: (index) {
										setState(() => _selectedNavIndex = index);
									},
									destinations: List.generate(
										_navLabels.length,
										(i) => NavigationDestination(
											icon: Icon(_navIcons[i]),
											label: _navLabels[i],
										),
									),
								),
							],
						);
					},
				),
			),
		);
	}

	Widget _buildSelectedSection({
		required DateTime now,
		required DashboardStats stats,
		required List<String> categoryNames,
		required List<ExpenseTx> txRows,
		required List<String> monthOptions,
	}) {
		final showProfileButton = _selectedNavIndex != 5;
		Widget section;
		switch (_selectedNavIndex) {
			case 0:
				section = SingleChildScrollView(
					key: const ValueKey('overview'),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							_buildHeader(now),
							const SizedBox(height: 10),
							_buildSummary(stats),
							const SizedBox(height: 10),
							_buildVisualsSection(),
						],
					),
				);
				break;
			case 1:
				section = SingleChildScrollView(
					key: const ValueKey('expenses'),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							_buildSectionHeading(
								title: 'Expenses',
								subtitle: 'Add and monitor expenses quickly with clear guidance.',
							),
							const SizedBox(height: 10),
							_buildMainArea(stats, categoryNames),
						],
					),
				);
				break;
			case 2:
				section = SingleChildScrollView(
					key: const ValueKey('categories'),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							_buildSectionHeading(
								title: 'Categories',
								subtitle: 'Set category budgets to make spending limits easier to follow.',
							),
							const SizedBox(height: 10),
							_buildCategorySection(),
						],
					),
				);
				break;
			case 3:
				section = SingleChildScrollView(
					key: const ValueKey('monthly'),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							_buildSectionHeading(
								title: 'Monthly Summaries Table',
								subtitle: 'Review monthly totals in a clean table view.',
							),
							const SizedBox(height: 10),
							_buildMonthlySection(),
						],
					),
				);
				break;
			case 4:
				section = SingleChildScrollView(
					key: const ValueKey('history'),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							_buildSectionHeading(
								title: 'Transaction History',
								subtitle: 'Filter and search your transactions without scrolling through other sections.',
							),
							const SizedBox(height: 10),
							_buildHistorySection(txRows, categoryNames, monthOptions),
						],
					),
				);
				break;
			case 5:
				section = SingleChildScrollView(
					key: const ValueKey('about'),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							_buildSectionHeading(
								title: 'About',
								subtitle: 'About this allowance and budget tracker.',
							),
							const SizedBox(height: 10),
							_buildAboutCard(),
						],
					),
				);
				break;
			default:
				section = const SizedBox.shrink();
		}

		if (showProfileButton) {
			section = Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(
						children: [
							Text(
								'Coinzyss',
								style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
							),
							const Spacer(),
							_buildProfileButton(),
							const SizedBox(width: 4),
							_buildSettingsButton(),
						],
					),
					const SizedBox(height: 10),
					Expanded(child: section),
				],
			);
		}

		return AnimatedSwitcher(
			duration: const Duration(milliseconds: 220),
			switchInCurve: Curves.easeOut,
			switchOutCurve: Curves.easeIn,
			child: section,
		);
	}

	Widget _buildSectionHeading({required String title, required String subtitle}) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text(
					title,
					style: Theme.of(context).textTheme.headlineSmall?.copyWith(
							fontWeight: FontWeight.w700,
					),
				),
				const SizedBox(height: 4),
				Text(subtitle),
			],
		);
	}

	Widget _buildHeader(DateTime now) {
		final scheme = Theme.of(context).colorScheme;
		return LayoutBuilder(
			builder: (context, constraints) {
				final heading = Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text(
							'Allowance Budget Tracker',
							style: Theme.of(context).textTheme.headlineSmall?.copyWith(
									fontWeight: FontWeight.w700,
							),
						),
						const SizedBox(height: 4),
						const Text('Track your allowance, spending, and savings in one clear view.'),
					],
				);

				final dateLabel = Center(
					child: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							Icon(Icons.calendar_today_outlined, size: 20, color: scheme.primary),
							const SizedBox(width: 8),
							Text(
								DateFormat('EEEE, MMM d, yyyy').format(now),
								style: Theme.of(context).textTheme.titleMedium?.copyWith(
									fontSize: 18,
									fontWeight: FontWeight.w700,
									color: scheme.onSurface,
								),
							),
						],
					),
				);

				return Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						heading,
						const SizedBox(height: 12),
						dateLabel,
					],
				);
			},
		);
	}

	Widget _buildSummary(DashboardStats stats) {
		final cards = [
			_SummaryCard(label: 'Monthly Allowance', value: _money(_data.monthlyAllowance), note: 'Current month allocation'),
			_SummaryCard(label: 'Expenses', value: _money(stats.spent), note: '${stats.count} transactions', tone: SummaryTone.warn),
			_SummaryCard(
				label: 'Remaining',
				value: _money(stats.remaining),
				note: stats.remaining < 0 ? '${_money(stats.remaining.abs())} over budget' : 'Healthy pace',
				tone: stats.remaining < 0 ? SummaryTone.warn : SummaryTone.good,
			),
			_SummaryCard(
				label: 'Daily Avg Spent',
				value: _money(stats.dailyAverage),
				note: 'Projected month spend: ${_money(stats.projected)}',
			),
		];

		return LayoutBuilder(
			builder: (context, constraints) {
				final compact = constraints.maxWidth < AppBreakpoints.compact;
				final medium = constraints.maxWidth < AppBreakpoints.medium;
				double cardWidth;
				if (compact) {
					cardWidth = constraints.maxWidth;
				} else if (medium) {
					cardWidth = (constraints.maxWidth - 10) / 2;
				} else {
					cardWidth = 260;
				}

				return Wrap(
					spacing: 8,
					runSpacing: 8,
					children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
				);
			},
		);
	}

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
												style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
									label: Text('MONTH ${_monthLabel(_nowMonthKey()).toUpperCase()}'),
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
												keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
												initialValue: categoryNames.contains(_expenseCategory) ? _expenseCategory : (categoryNames.isNotEmpty ? categoryNames.first : null),
												items: categoryNames
														.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis)))
														.toList(),
												onChanged: categoryNames.isEmpty
														? null
														: (v) {
																if (v != null) {
																	setState(() => _expenseCategory = v);
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
													padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
														setState(() => _expenseDate = picked);
													}
												},
											),
										),
										if (compact)
											SizedBox(
												width: constraints.maxWidth,
												child: FilledButton(
													onPressed: categoryNames.isEmpty ? null : _addExpense,
													style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
													child: const Text('Add Expense'),
												),
											)
										else
											FilledButton(
												onPressed: categoryNames.isEmpty ? null : _addExpense,
												style: FilledButton.styleFrom(
													padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
													minimumSize: const Size(0, 38),
												),
												child: const Text('Add Expense'),
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
											SizedBox(width: constraints.maxWidth, child: _KpiTile(title: 'Top Category', value: stats.topCategoryLabel)),
											SizedBox(width: constraints.maxWidth, child: _KpiTile(title: 'This Week Spent', value: _money(stats.weekSpent))),
											SizedBox(width: constraints.maxWidth, child: _KpiTile(title: 'Largest Expense', value: _money(stats.largestExpense))),
										],
									);
								}

								return Row(
									children: [
										Expanded(child: _KpiTile(title: 'Top Category', value: stats.topCategoryLabel)),
										const SizedBox(width: 8),
										Expanded(child: _KpiTile(title: 'This Week Spent', value: _money(stats.weekSpent))),
										const SizedBox(width: 8),
										Expanded(child: _KpiTile(title: 'Largest Expense', value: _money(stats.largestExpense))),
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
										: scheme.tertiaryContainer,
								borderRadius: BorderRadius.circular(10),
								border: Border.all(
									color: stats.remaining < 0 || stats.percentUsed >= 85
											? scheme.error
											: scheme.tertiary,
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
											: scheme.onTertiaryContainer,
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
						const Text('Allowance', style: TextStyle(fontWeight: FontWeight.w700)),
						const SizedBox(height: 4),
						const Text('Set your monthly spending limit in PHP.'),
						const SizedBox(height: 12),
						TextField(
							controller: _allowanceController,
							keyboardType: const TextInputType.numberWithOptions(decimal: true),
							decoration: const InputDecoration(
								labelText: 'Monthly allowance',
								hintText: 'e.g., 350',
								border: OutlineInputBorder(),
							),
						),
						const SizedBox(height: 10),
						FilledButton.tonal(onPressed: _saveAllowance, child: const Text('Save')),
						const SizedBox(height: 8),
						const Text('Tip: Values are saved locally in your device storage.'),
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
							spentVsAllowancePanel,
							const SizedBox(height: 10),
							panelLeft,
							const SizedBox(height: 10),
							allowancePanel,
						],
					);
				}
				return Column(
					children: [
						spentVsAllowancePanel,
						const SizedBox(height: 10),
						Row(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Expanded(flex: 2, child: panelLeft),
								const SizedBox(width: 10),
								Expanded(child: allowancePanel),
							],
						),
					],
				);
			},
		);
	}

	Widget _buildVisualsSection() {
		final months = _recentMonths(12).reversed.toList();
		final values = months
				.map((month) => _data.transactions
						.where((tx) => _monthKey(tx.date) == month)
						.fold<double>(0, (sum, tx) => sum + tx.amount))
				.toList();
		final labels = months.map((m) => _monthLabel(m).split(' ').first).toList();

		final categories = _data.categories.keys.toList()..sort();
		final effectiveLineCategory = categories.contains(_lineChartCategory) ? _lineChartCategory : 'all';
		final selectedCategories = effectiveLineCategory == 'all' ? categories : [effectiveLineCategory];

		final lineSeries = selectedCategories
				.map(
					(name) => _LineSeries(
						name: name,
						values: months
								.map(
									(month) => _data.transactions
											.where((tx) => _monthKey(tx.date) == month && tx.category == name)
											.fold<double>(0, (sum, tx) => sum + tx.amount),
								)
								.toList(),
					),
				)
				.toList();
		final lineColors = lineSeries.map((s) => _categoryLineColors[s.name] ?? _categoryLineSeedColors.first).toList();

		return Card(
			child: Padding(
				padding: const EdgeInsets.all(10),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text('Visual Overview', style: TextStyle(fontWeight: FontWeight.w700)),
						const SizedBox(height: 4),
						const Text('All graphs are grouped here for a quick visual summary.'),
						const SizedBox(height: 8),
						LayoutBuilder(
							builder: (context, constraints) {
								final chartA = _ChartCard(
									title: '12-Month Spending (Bar)',
									child: MonthlyBarChart(values: values, labels: labels),
								);
								final chartB = _ChartCard(
									title: '12-Month Spending (Line graph)',
									child: MonthlyLineChart(series: lineSeries, labels: labels, lineColors: lineColors),
									footer: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											if (lineSeries.isNotEmpty)
												Wrap(
													spacing: 14,
													runSpacing: 6,
													children: List.generate(lineSeries.length, (i) {
														final color = lineColors[i % lineColors.length];
														return Row(
															mainAxisSize: MainAxisSize.min,
															children: [
																Container(width: 24, height: 2.5, color: color),
																const SizedBox(width: 6),
																Text(lineSeries[i].name),
															],
														);
													}),
												),
											const SizedBox(height: 8),
											SizedBox(
												width: 180,
												child: DropdownButton<String>(
													isExpanded: true,
													value: effectiveLineCategory,
													onChanged: (value) {
														if (value != null) {
															setState(() => _lineChartCategory = value);
														}
													},
													items: [
														const DropdownMenuItem(
															value: 'all',
															child: Text('All Categories'),
														),
														...categories.map(
															(name) => DropdownMenuItem(
																value: name,
																child: Text(name, overflow: TextOverflow.ellipsis),
															),
														),
													],
												),
											),
										],
									),
								);

								if (constraints.maxWidth < 900) {
									return Column(
										children: [
											chartA,
											const SizedBox(height: 8),
											chartB,
										],
									);
								}

								final cardWidth = (constraints.maxWidth - 10) / 2;
								return Wrap(
									spacing: 8,
									runSpacing: 8,
									children: [
										SizedBox(width: cardWidth, child: chartA),
										SizedBox(width: cardWidth, child: chartB),
									],
								);
							},
						),
					],
				),
			),
		);
	}

	Widget _buildCategorySection() {
		final current = _currentMonthTransactions();
		final spentByCategory = <String, double>{};
		for (final tx in current) {
			spentByCategory[tx.category] = (spentByCategory[tx.category] ?? 0) + tx.amount;
		}

		final names = _data.categories.keys.toList()..sort();

		return Card(
			child: Padding(
				padding: const EdgeInsets.all(10),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text('Categories', style: TextStyle(fontWeight: FontWeight.w700)),
						const SizedBox(height: 4),
						const Text('Assign budget per category to see where money goes.'),
						const SizedBox(height: 8),
						LayoutBuilder(
							builder: (context, constraints) {
								final compact = constraints.maxWidth < AppBreakpoints.compact;
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
												keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
																			padding: const EdgeInsets.symmetric(vertical: 8),
																			minimumSize: const Size(0, 34),
																			visualDensity: VisualDensity.compact,
																		),
																		child: const Text('Add / Update'),
																	),
																),
																const SizedBox(width: 6),
																Expanded(
																	child: OutlinedButton(
																		onPressed: _removeCategory,
																		style: OutlinedButton.styleFrom(
																			padding: const EdgeInsets.symmetric(vertical: 8),
																			minimumSize: const Size(0, 34),
																			visualDensity: VisualDensity.compact,
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
							const Text('No categories yet. Add one above to start budgeting.')
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
											DataCell(Text(_money(remaining), style: TextStyle(color: remaining < 0 ? Colors.red.shade700 : Colors.green.shade700))),
											DataCell(SizedBox(width: 130, child: Text('${pct.toStringAsFixed(0)}%'))),
										]);
									}).toList(),
								),
							),
					],
				),
			),
		);
	}

	Widget _buildMonthlySection() {
		final scheme = Theme.of(context).colorScheme;
		final years = _availableYears();
		final selectedYear = years.contains(_summaryYear) ? _summaryYear : years.first;
		final summaryRows = _buildPeriodSummaryRows();
		final totalRows = summaryRows.length;
		final maxPage = totalRows == 0 ? 0 : ((totalRows - 1) ~/ _monthlyRowsPerPage);
		final safePage = _monthlyPage.clamp(0, maxPage);
		if (safePage != _monthlyPage) {
			_monthlyPage = safePage;
		}
		final startIndex = totalRows == 0 ? 0 : safePage * _monthlyRowsPerPage;
		final endIndex = totalRows == 0
				? 0
				: math.min(startIndex + _monthlyRowsPerPage, totalRows);
		final visibleRows = totalRows == 0 ? <_PeriodSummaryRow>[] : summaryRows.sublist(startIndex, endIndex);
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
						const Text('Monthly Summaries', style: TextStyle(fontWeight: FontWeight.w700)),
						const SizedBox(height: 4),
						const Text('Compact calendar filters: pick period and date.'),
						const SizedBox(height: 8),
						LayoutBuilder(
							builder: (context, constraints) {
								return Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Wrap(
											spacing: 8,
											runSpacing: 8,
											children: [
												ChoiceChip(
													label: const Text('Month'),
													selected: _summaryPeriod == 'month',
													onSelected: (_) => setState(() {
														_summaryPeriod = 'month';
														_monthlyPage = 0;
													}),
												),
												ChoiceChip(
													label: const Text('Week'),
													selected: _summaryPeriod == 'week',
													onSelected: (_) => setState(() {
														_summaryPeriod = 'week';
														_monthlyPage = 0;
													}),
												),
												ChoiceChip(
													label: const Text('Year'),
													selected: _summaryPeriod == 'year',
													onSelected: (_) => setState(() {
														_summaryPeriod = 'year';
														_monthlyPage = 0;
													}),
												),
												if (_summaryPeriod == 'week')
													ActionChip(
														avatar: const Icon(Icons.calendar_month_outlined, size: 16),
														label: const Text('Date'),
														onPressed: _pickMonthlyAnchorDate,
													),
												PopupMenuButton<int>(
													tooltip: 'Rows per page',
													onSelected: (value) {
														setState(() {
															_monthlyRowsPerPage = value;
															_monthlyPage = 0;
														});
													},
													itemBuilder: (context) => const [
														PopupMenuItem(value: 5, child: Text('5 rows')),
														PopupMenuItem(value: 8, child: Text('8 rows')),
														PopupMenuItem(value: 10, child: Text('10 rows')),
														PopupMenuItem(value: 20, child: Text('20 rows')),
													],
													child: Chip(
														avatar: const Icon(Icons.table_rows_outlined, size: 16),
														label: Text('$_monthlyRowsPerPage rows'),
													),
												),
												PopupMenuButton<String>(
													tooltip: 'Manage Columns',
													onSelected: (value) {
														setState(() {
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
									],
								);
							},
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
										headingRowColor: WidgetStateProperty.all(scheme.surfaceContainerHigh),
										headingTextStyle: TextStyle(
											fontWeight: FontWeight.w700,
											color: scheme.onSurfaceVariant,
											fontSize: 12,
										),
										columnSpacing: 26,
										horizontalMargin: 14,
										columns: [
											DataColumn(label: Text(periodLabel.toUpperCase())),
											if (_monthlyShowAllowance) const DataColumn(label: Text('ALLOWANCE')),
											if (_monthlyShowSpent) const DataColumn(label: Text('SPENT')),
											if (_monthlyShowSaved) const DataColumn(label: Text('SAVED')),
											if (_monthlyShowRate) const DataColumn(label: Text('SPEND RATE')),
										],
										rows: visibleRows.map((row) {
											final saved = row.allowance - row.spent;
											final rate = row.allowance > 0 ? (row.spent / row.allowance) * 100 : 0.0;
											return DataRow(cells: [
												DataCell(Text(row.label)),
												if (_monthlyShowAllowance) DataCell(Text(_money(row.allowance))),
												if (_monthlyShowSpent) DataCell(Text(_money(row.spent))),
												if (_monthlyShowSaved)
													DataCell(Text(_money(saved), style: TextStyle(color: saved < 0 ? Colors.red.shade700 : Colors.green.shade700))),
												if (_monthlyShowRate) DataCell(Text('${rate.toStringAsFixed(1)}%')),
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
												? () => setState(() => _monthlyPage = safePage - 1)
												: null,
											icon: const Icon(Icons.chevron_left),
										),
										Text('${safePage + 1}/${maxPage + 1}'),
										IconButton(
											onPressed: safePage < maxPage
												? () => setState(() => _monthlyPage = safePage + 1)
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

	Widget _buildHistorySection(List<ExpenseTx> rows, List<String> categories, List<String> months) {
		return Card(
			child: Padding(
				padding: const EdgeInsets.all(10),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text('Transaction History', style: TextStyle(fontWeight: FontWeight.w700)),
						const SizedBox(height: 4),
						const Text('Use filters to quickly find the expense you need.'),
						const SizedBox(height: 8),
						LayoutBuilder(
							builder: (context, constraints) {
								final compact = constraints.maxWidth < AppBreakpoints.compact;
								return Wrap(
									spacing: 10,
									runSpacing: 10,
									children: [
										SizedBox(
											width: compact ? constraints.maxWidth : 220,
											child: TextField(
												controller: _searchController,
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
													const DropdownMenuItem(value: 'all', child: Text('All categories')),
													...categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
												],
												onChanged: (v) {
													if (v != null) {
														setState(() => _filterCategory = v);
													}
												},
												decoration: const InputDecoration(border: OutlineInputBorder()),
											),
										),
										SizedBox(
											width: compact ? constraints.maxWidth : 180,
											child: DropdownButtonFormField<String>(
												isExpanded: true,
												initialValue: _filterMonth,
												items: [
													const DropdownMenuItem(value: 'all', child: Text('All months')),
													...months.map((m) => DropdownMenuItem(value: m, child: Text(_monthLabel(m), overflow: TextOverflow.ellipsis))),
												],
												onChanged: (v) {
													if (v != null) {
														setState(() => _filterMonth = v);
													}
												},
												decoration: const InputDecoration(border: OutlineInputBorder()),
											),
										),
										if (compact)
											SizedBox(
												width: constraints.maxWidth,
												child: OutlinedButton(
													onPressed: () {
														setState(() {
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
											OutlinedButton(
												onPressed: () {
													setState(() {
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
									final compact = constraints.maxWidth < AppBreakpoints.compact;
									final start = _historyPage * _historyRowsPerPage;
									final end = math.min(start + _historyRowsPerPage, rows.length);
									final paginatedRows = rows.sublist(start, end);
									if (compact) {
										return Column(
											children: paginatedRows.map((tx) {
												return Card(
													margin: const EdgeInsets.only(bottom: 8),
													child: ListTile(
														title: Text(tx.title, maxLines: 1, overflow: TextOverflow.ellipsis),
														subtitle: Text('${DateFormat('MMM d, yyyy').format(tx.date)} • ${tx.category}'),
														trailing: Text(
															_money(tx.amount),
															style: const TextStyle(fontWeight: FontWeight.w700),
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
													DataCell(Text(DateFormat('MMM d, yyyy').format(tx.date))),
													DataCell(SizedBox(width: 220, child: Text(tx.title, overflow: TextOverflow.ellipsis))),
													DataCell(SizedBox(width: 120, child: Text(tx.category, overflow: TextOverflow.ellipsis))),
													DataCell(Align(alignment: Alignment.centerRight, child: Text(_money(tx.amount)))),
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
											: 'Showing ${(_historyPage * _historyRowsPerPage) + 1} - ${math.min((_historyPage + 1) * _historyRowsPerPage, rows.length)} of ${rows.length}',
									style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
								),
								Row(
									children: [
										IconButton(
											onPressed: _historyPage > 0 ? () => setState(() => _historyPage--) : null,
											icon: const Icon(Icons.chevron_left),
										),
										Text('${_historyPage + 1}/${rows.isEmpty ? 1 : ((rows.length - 1) ~/ _historyRowsPerPage) + 1}'),
										IconButton(
											onPressed: ((_historyPage + 1) * _historyRowsPerPage) < rows.length ? () => setState(() => _historyPage++) : null,
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

	Widget _buildAboutCard() {
		return Card(
			child: Padding(
				padding: const EdgeInsets.all(10),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text('Allowance Budget Tracker', style: TextStyle(fontWeight: FontWeight.w700)),
						const SizedBox(height: 6),
						const Text('This app helps students track monthly allowance, categorize expenses, and review spending trends with simple and clear sections.'),
						const SizedBox(height: 8),
						const Text('Steps', style: TextStyle(fontWeight: FontWeight.w700)),
						const SizedBox(height: 8),
						LayoutBuilder(
							builder: (context, constraints) {
								final compact = constraints.maxWidth < AppBreakpoints.compact;
								final medium = constraints.maxWidth < AppBreakpoints.medium;
								double cardWidth;
								if (compact) {
									cardWidth = constraints.maxWidth;
								} else if (medium) {
									cardWidth = (constraints.maxWidth - 10) / 2;
								} else {
									cardWidth = 280;
								}

								return Wrap(
									spacing: 10,
									runSpacing: 10,
									children: const [
										_GuideCard(step: 'Step 1', title: 'Set your monthly allowance', body: 'Use the Allowance card to save your budget in PHP.'),
										_GuideCard(step: 'Step 2', title: 'Add expenses as they happen', body: 'Each entry updates your totals, progress bar, and insights automatically.'),
										_GuideCard(step: 'Step 3', title: 'Review trends monthly', body: 'Check categories, monthly summaries, and filter transaction history.'),
									].map((g) => SizedBox(width: cardWidth, child: g)).toList(),
								);
							},
						),
					],
				),
			),
		);
	}
}

enum SummaryTone { normal, good, warn }

class _SummaryCard extends StatelessWidget {
	const _SummaryCard({
		required this.label,
		required this.value,
		required this.note,
		this.tone = SummaryTone.normal,
	});

	final String label;
	final String value;
	final String note;
	final SummaryTone tone;

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		Color valueColor;
		switch (tone) {
			case SummaryTone.good:
				valueColor = scheme.tertiary;
				break;
			case SummaryTone.warn:
				valueColor = scheme.error;
				break;
			default:
				valueColor = scheme.onSurface;
		}
		return Card(
			child: Padding(
				padding: const EdgeInsets.all(12),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
						const SizedBox(height: 6),
						Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: valueColor)),
						const SizedBox(height: 4),
						Text(note),
					],
				),
			),
		);
	}
}

class _KpiTile extends StatelessWidget {
	const _KpiTile({required this.title, required this.value});

	final String title;
	final String value;

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
			decoration: BoxDecoration(
				color: scheme.surfaceContainerLow,
				borderRadius: BorderRadius.circular(10),
				border: Border.all(color: scheme.outlineVariant),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(title, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
					const SizedBox(height: 2),
					Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: scheme.onSurface), overflow: TextOverflow.ellipsis),
				],
			),
		);
	}
}

class _GuideCard extends StatelessWidget {
	const _GuideCard({required this.step, required this.title, required this.body});

	final String step;
	final String title;
	final String body;

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		return Card(
			child: Padding(
				padding: const EdgeInsets.all(12),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text(step, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)),
						const SizedBox(height: 4),
						Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
						const SizedBox(height: 4),
						Text(body),
					],
				),
			),
		);
	}
}

class _PeriodSummaryRow {
	const _PeriodSummaryRow({
		required this.label,
		required this.allowance,
		required this.spent,
	});

	final String label;
	final double allowance;
	final double spent;
}

class _ChartCard extends StatelessWidget {
	const _ChartCard({required this.title, required this.child, this.footer});

	final String title;
	final Widget child;
	final Widget? footer;

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		return Container(
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				color: scheme.surfaceContainerLow,
				borderRadius: BorderRadius.circular(12),
				border: Border.all(color: scheme.outlineVariant),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
					const SizedBox(height: 10),
					SizedBox(height: 220, child: child),
					if (footer != null) ...[
						const SizedBox(height: 10),
						footer!,
					],
				],
			),
		);
	}
}

class _LineSeries {
	const _LineSeries({required this.name, required this.values});

	final String name;
	final List<double> values;
}

class CategoryBarChart extends StatelessWidget {
	const CategoryBarChart({super.key, required this.values, required this.moneyLabel});

	final Map<String, double> values;
	final String Function(num) moneyLabel;

	@override
	Widget build(BuildContext context) {
		if (values.isEmpty) {
			return const Center(child: Text('No spending data for this month yet.'));
		}
		final scheme = Theme.of(context).colorScheme;
		final entries = values.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
		return CustomPaint(
			painter: _CategoryBarPainter(
				entries: entries.take(6).toList(),
				moneyLabel: moneyLabel,
				labelColor: scheme.onSurface,
				valueColor: scheme.onSurfaceVariant,
				barBgColor: scheme.surfaceContainerHighest,
				barColor: scheme.primary,
			),
			child: const SizedBox.expand(),
		);
	}
}

class _CategoryBarPainter extends CustomPainter {
	_CategoryBarPainter({
		required this.entries,
		required this.moneyLabel,
		required this.labelColor,
		required this.valueColor,
		required this.barBgColor,
		required this.barColor,
	});

	final List<MapEntry<String, double>> entries;
	final String Function(num) moneyLabel;
	final Color labelColor;
	final Color valueColor;
	final Color barBgColor;
	final Color barColor;

	@override
	void paint(Canvas canvas, Size size) {
		final maxValue = entries.fold<double>(1, (m, e) => math.max(m, e.value));
		const left = 8.0;
		const barStart = 96.0;
		final usableWidth = size.width - barStart - 12;
		const lineHeight = 30.0;

		final labelStyle = TextStyle(color: labelColor, fontSize: 12);
		final valueStyle = TextStyle(color: valueColor, fontSize: 11);

		for (var i = 0; i < entries.length; i++) {
			final e = entries[i];
			final y = 10.0 + i * lineHeight;
			final w = maxValue > 0 ? (e.value / maxValue) * usableWidth : 0.0;

			final bg = Paint()..color = barBgColor;
			final fg = Paint()..color = barColor;

			canvas.drawRRect(
				RRect.fromRectAndRadius(Rect.fromLTWH(barStart, y, usableWidth, 12), const Radius.circular(8)),
				bg,
			);
			canvas.drawRRect(
				RRect.fromRectAndRadius(Rect.fromLTWH(barStart, y, w, 12), const Radius.circular(8)),
				fg,
			);

			final labelPainter = TextPainter(
				text: TextSpan(text: e.key.length > 12 ? '${e.key.substring(0, 12)}...' : e.key, style: labelStyle),
				textDirection: TextDirection.ltr,
			)..layout(maxWidth: 84);
			labelPainter.paint(canvas, const Offset(left, 8));

			final valuePainter = TextPainter(
				text: TextSpan(text: moneyLabel(e.value), style: valueStyle),
				textDirection: TextDirection.ltr,
			)..layout(maxWidth: 80);
			valuePainter.paint(canvas, Offset(barStart + math.min(w + 6, usableWidth - 72), y - 1));
		}
	}

	@override
	bool shouldRepaint(covariant _CategoryBarPainter oldDelegate) {
		return oldDelegate.entries != entries;
	}
}

class MonthlyBarChart extends StatelessWidget {
	const MonthlyBarChart({super.key, required this.values, required this.labels});

	final List<double> values;
	final List<String> labels;

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		return CustomPaint(
			painter: _MonthlyBarPainter(
				values: values,
				labels: labels,
				axisColor: scheme.outlineVariant,
				barColor: scheme.primary,
				labelColor: scheme.onSurfaceVariant,
				gridColor: scheme.outlineVariant.withValues(alpha: 0.45),
				valueColor: scheme.onSurface,
			),
			child: const SizedBox.expand(),
		);
	}
}

class _MonthlyBarPainter extends CustomPainter {
	_MonthlyBarPainter({
		required this.values,
		required this.labels,
		required this.axisColor,
		required this.barColor,
		required this.labelColor,
		required this.gridColor,
		required this.valueColor,
	});

	final List<double> values;
	final List<String> labels;
	final Color axisColor;
	final Color barColor;
	final Color labelColor;
	final Color gridColor;
	final Color valueColor;

	@override
	void paint(Canvas canvas, Size size) {
		if (values.isEmpty) {
			return;
		}
		const padLeft = 18.0;
		const padRight = 44.0;
		const padTop = 14.0;
		const padBottom = 30.0;
		final chartW = size.width - padLeft - padRight;
		final chartH = size.height - padTop - padBottom;
		final maxValue = values.fold<double>(1, (m, v) => math.max(m, v));
		final yMax = math.max(1000.0, (maxValue / 1000.0).ceil() * 1000.0);

		final axisPaint = Paint()
			..color = axisColor
			..strokeWidth = 1;
		final gridPaint = Paint()
			..color = gridColor
			..strokeWidth = 1;
		final barPaint = Paint()..color = barColor;

		canvas.drawLine(
			Offset(padLeft, padTop + chartH),
			Offset(size.width - padRight, padTop + chartH),
			axisPaint,
		);

		for (var tick = 1000.0; tick <= yMax; tick += 1000.0) {
			final y = padTop + chartH - ((tick / yMax) * chartH);
			canvas.drawLine(Offset(padLeft, y), Offset(size.width - padRight, y), gridPaint);
			final valuePainter = TextPainter(
				text: TextSpan(text: tick.toInt().toString(), style: TextStyle(color: valueColor, fontSize: 10)),
				textDirection: TextDirection.ltr,
			)..layout(maxWidth: padRight - 4);
			valuePainter.paint(canvas, Offset(size.width - padRight + 4, y - (valuePainter.height / 2)));
		}

		final count = values.length;
		const gap = 8.0;
		final barW = ((chartW - ((count + 1) * gap)) / count).clamp(8.0, 36.0);

		final style = TextStyle(color: labelColor, fontSize: 10);
		for (var i = 0; i < count; i++) {
			final x = padLeft + gap + i * (barW + gap);
			final h = yMax > 0 ? (values[i] / yMax) * chartH : 0.0;
			final y = padTop + chartH - h;

			canvas.drawRRect(
				RRect.fromRectAndRadius(
					Rect.fromLTWH(x, y, barW, h),
					const Radius.circular(6),
				),
				barPaint,
			);

			if (i >= labels.length) {
				continue;
			}

			final painter = TextPainter(
				text: TextSpan(text: labels[i], style: style),
				textDirection: TextDirection.ltr,
			)..layout(maxWidth: math.max(barW + 12, 24));
			painter.paint(canvas, Offset(x - ((painter.width - barW) / 2), size.height - 16));
		}
	}

	@override
	bool shouldRepaint(covariant _MonthlyBarPainter oldDelegate) {
		return oldDelegate.values != values || oldDelegate.labels != labels;
	}
}

class MonthlyLineChart extends StatelessWidget {
	const MonthlyLineChart({
		super.key,
		required this.series,
		required this.labels,
		required this.lineColors,
	});

	final List<_LineSeries> series;
	final List<String> labels;
	final List<Color> lineColors;

	@override
	Widget build(BuildContext context) {
		if (series.isEmpty) {
			return const Center(child: Text('No spending data for selected category.'));
		}

		final scheme = Theme.of(context).colorScheme;

		return CustomPaint(
			painter: _MonthlyLinePainter(
				series: series,
				labels: labels,
				axisColor: scheme.outlineVariant,
				gridColor: scheme.outlineVariant.withValues(alpha: 0.45),
				lineColors: lineColors,
				labelColor: scheme.onSurfaceVariant,
				valueColor: scheme.onSurface,
			),
			child: const SizedBox.expand(),
		);
	}
}

class _MonthlyLinePainter extends CustomPainter {
	_MonthlyLinePainter({
		required this.series,
		required this.labels,
		required this.axisColor,
		required this.gridColor,
		required this.lineColors,
		required this.labelColor,
		required this.valueColor,
	});

	final List<_LineSeries> series;
	final List<String> labels;
	final Color axisColor;
	final Color gridColor;
	final List<Color> lineColors;
	final Color labelColor;
	final Color valueColor;

	@override
	void paint(Canvas canvas, Size size) {
		if (series.isEmpty) {
			return;
		}

		const padLeft = 18.0;
		const padRight = 44.0;
		const padTop = 14.0;
		const padBottom = 30.0;
		final chartW = size.width - padLeft - padRight;
		final chartH = size.height - padTop - padBottom;
		var maxValue = 0.0;
		for (final line in series) {
			for (final v in line.values) {
				if (v > maxValue) {
					maxValue = v;
				}
			}
		}
		final yMax = math.max(300.0, (maxValue / 100.0).ceil() * 100.0);

		final axisPaint = Paint()
			..color = axisColor
			..strokeWidth = 1;
		final gridPaint = Paint()
			..color = gridColor
			..strokeWidth = 1;

		canvas.drawLine(
			Offset(padLeft, padTop + chartH),
			Offset(size.width - padRight, padTop + chartH),
			axisPaint,
		);

		for (var tick = 100.0; tick <= yMax; tick += 100.0) {
			final y = padTop + chartH - ((tick / yMax) * chartH);
			canvas.drawLine(Offset(padLeft, y), Offset(size.width - padRight, y), gridPaint);
			final valuePainter = TextPainter(
				text: TextSpan(text: tick.toInt().toString(), style: TextStyle(color: valueColor, fontSize: 10)),
				textDirection: TextDirection.ltr,
			)..layout(maxWidth: padRight - 4);
			valuePainter.paint(canvas, Offset(size.width - padRight + 4, y - (valuePainter.height / 2)));
		}

		final count = labels.length;
		final xStep = count > 1 ? chartW / (count - 1) : 0.0;

		for (var lineIndex = 0; lineIndex < series.length; lineIndex++) {
			final line = series[lineIndex];
			if (line.values.isEmpty) {
				continue;
			}

			final linePaint = Paint()
				..color = lineColors[lineIndex % lineColors.length]
				..strokeWidth = 2.8
				..style = PaintingStyle.stroke;

			final points = <Offset>[];
			for (var i = 0; i < count; i++) {
				final x = padLeft + (count > 1 ? i * xStep : chartW / 2);
				final value = i < line.values.length ? line.values[i] : 0.0;
				final h = yMax > 0 ? (value / yMax) * chartH : 0.0;
				final y = padTop + chartH - h;
				points.add(Offset(x, y));
			}

			final path = Path()..moveTo(points.first.dx, points.first.dy);
			for (var i = 1; i < points.length; i++) {
				path.lineTo(points[i].dx, points[i].dy);
			}
			canvas.drawPath(path, linePaint);
		}

		for (var i = 0; i < labels.length; i++) {
			final x = padLeft + (count > 1 ? i * xStep : chartW / 2);
			final painter = TextPainter(
				text: TextSpan(text: labels[i], style: TextStyle(color: labelColor, fontSize: 10)),
				textDirection: TextDirection.ltr,
			)..layout(maxWidth: 42);
			painter.paint(canvas, Offset(x - painter.width / 2, size.height - 16));
		}
	}

	@override
	bool shouldRepaint(covariant _MonthlyLinePainter oldDelegate) {
		return oldDelegate.series != series || oldDelegate.labels != labels;
	}
}

class CategoryPieChart extends StatelessWidget {
	const CategoryPieChart({super.key, required this.values});

	final Map<String, double> values;

	@override
	Widget build(BuildContext context) {
		if (values.isEmpty) {
			return const Center(child: Text('No spending data for this month yet.'));
		}

		final scheme = Theme.of(context).colorScheme;
		final dark = Theme.of(context).brightness == Brightness.dark;
		final palette = dark
				? [
					const Color(0xFF7EDDB9),
					const Color(0xFF59CAA0),
					const Color(0xFF37B689),
					const Color(0xFF1E9E73),
					const Color(0xFF5FAE95),
					const Color(0xFF3F8D74),
				]
				: [
					const Color(0xFF1A7A59),
					const Color(0xFF5AA386),
					const Color(0xFF8FC6B2),
					const Color(0xFF3C8D73),
					const Color(0xFFAEDBCA),
					const Color(0xFF2F6B58),
				];
		final entries = values.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
		return CustomPaint(
			painter: _CategoryPiePainter(
				entries: entries.take(6).toList(),
				palette: palette,
				innerColor: scheme.surface,
				labelColor: scheme.onSurfaceVariant,
				valueColor: scheme.onSurface,
				legendColor: scheme.onSurface,
			),
			child: const SizedBox.expand(),
		);
	}
}

class _CategoryPiePainter extends CustomPainter {
	_CategoryPiePainter({
		required this.entries,
		required this.palette,
		required this.innerColor,
		required this.labelColor,
		required this.valueColor,
		required this.legendColor,
	});

	final List<MapEntry<String, double>> entries;
	final List<Color> palette;
	final Color innerColor;
	final Color labelColor;
	final Color valueColor;
	final Color legendColor;

	@override
	void paint(Canvas canvas, Size size) {
		final total = entries.fold<double>(0, (sum, e) => sum + e.value);
		if (total <= 0) {
			return;
		}

		final center = Offset(size.width * 0.32, size.height * 0.5);
		final radius = math.min(size.height * 0.36, size.width * 0.24);
		final rect = Rect.fromCircle(center: center, radius: radius);

		double start = -math.pi / 2;
		for (var i = 0; i < entries.length; i++) {
			final sweep = (entries[i].value / total) * math.pi * 2;
			final paint = Paint()
				..style = PaintingStyle.fill
				..color = palette[i % palette.length];
			canvas.drawArc(rect, start, sweep, true, paint);
			start += sweep;
		}

		canvas.drawCircle(center, radius * 0.52, Paint()..color = innerColor);

		final totalPainter = TextPainter(
			text: TextSpan(
				text: 'Spent',
				style: TextStyle(color: labelColor, fontSize: 11),
			),
			textDirection: TextDirection.ltr,
		)..layout();
		totalPainter.paint(canvas, Offset(center.dx - totalPainter.width / 2, center.dy - 16));

		final valuePainter = TextPainter(
			text: TextSpan(
				text: total.toStringAsFixed(0),
				style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w700),
			),
			textDirection: TextDirection.ltr,
		)..layout();
		valuePainter.paint(canvas, Offset(center.dx - valuePainter.width / 2, center.dy - 2));

		final legendX = center.dx + radius + 16;
		var legendY = size.height * 0.18;
		for (var i = 0; i < entries.length; i++) {
			final pct = (entries[i].value / total) * 100;
			final color = palette[i % palette.length];

			canvas.drawCircle(Offset(legendX, legendY + 6), 5, Paint()..color = color);

			final text = '${entries[i].key}: ${pct.toStringAsFixed(0)}%';
			final tp = TextPainter(
				text: TextSpan(
					text: text,
					style: TextStyle(color: legendColor, fontSize: 11),
				),
				textDirection: TextDirection.ltr,
			)..layout(maxWidth: size.width - legendX - 8);
			tp.paint(canvas, Offset(legendX + 10, legendY));

			legendY += 24;
			if (legendY > size.height - 20) {
				break;
			}
		}
	}

	@override
	bool shouldRepaint(covariant _CategoryPiePainter oldDelegate) {
		return oldDelegate.entries != entries;
	}
}

class ProfilePage extends StatefulWidget {
	const ProfilePage({
		super.key,
		required this.isDarkMode,
		required this.onToggleDarkMode,
		required this.initialName,
		required this.initialRole,
		required this.initialAvatarIcon,
		required this.initialAvatarImageBytes,
		required this.onProfileChanged,
	});

	final bool isDarkMode;
	final ValueChanged<bool> onToggleDarkMode;
	final String initialName;
	final String initialRole;
	final IconData initialAvatarIcon;
	final Uint8List? initialAvatarImageBytes;
	final void Function({required String name, required String role, required IconData avatarIcon, Uint8List? avatarImageBytes}) onProfileChanged;

	@override
	State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
	late String _name;
	late String _role;
	static const String _email = 'student@example.com';
	bool _isEditing = false;
	late IconData _avatarIcon;
	Uint8List? _avatarImageBytes;
	Color _avatarColor = const Color(0xFF1A7A59);

	late final TextEditingController _nameController;
	late final TextEditingController _roleController;

	@override
	void initState() {
		super.initState();
		_name = widget.initialName;
		_role = widget.initialRole;
		_avatarIcon = widget.initialAvatarIcon;
		_avatarImageBytes = widget.initialAvatarImageBytes;
		_nameController = TextEditingController(text: _name);
		_roleController = TextEditingController(text: _role);
	}

	@override
	void dispose() {
		_nameController.dispose();
		_roleController.dispose();
		super.dispose();
	}

	void _startEditing() {
		setState(() {
			_nameController.text = _name;
			_roleController.text = _role;
			_isEditing = true;
		});
	}

	void _cancelEditing() {
		FocusScope.of(context).unfocus();
		setState(() {
			_isEditing = false;
		});
	}

	void _notifyProfileChanged() {
		widget.onProfileChanged(
			name: _name,
			role: _role,
			avatarIcon: _avatarIcon,
			avatarImageBytes: _avatarImageBytes,
		);
	}

	void _saveProfile() {
		final updatedName = _nameController.text.trim();
		final updatedRole = _roleController.text.trim();
		if (updatedName.isEmpty || updatedRole.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Name and role are required.')),
			);
			return;
		}

		FocusScope.of(context).unfocus();
		setState(() {
			_name = updatedName;
			_role = updatedRole;
			_isEditing = false;
		});
		_notifyProfileChanged();
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text('Profile saved successfully.')),
		);
	}

	Future<void> _pickImageFromAlbum() async {
		final picker = ImagePicker();
		final file = await picker.pickImage(
			source: ImageSource.gallery,
			maxWidth: 1200,
			maxHeight: 1200,
			imageQuality: 90,
		);
		if (file == null) {
			return;
		}

		final bytes = await file.readAsBytes();
		setState(() {
			_avatarImageBytes = bytes;
		});
		_notifyProfileChanged();
	}

	void _openAvatarPicker() {
		final avatars = <IconData>[
			Icons.person,
			Icons.face,
			Icons.sentiment_very_satisfied,
			Icons.school,
			Icons.psychology,
			Icons.sports_esports,
		];
		showModalBottomSheet<void>(
			context: context,
			showDragHandle: true,
			builder: (context) {
				return SafeArea(
					child: Padding(
						padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
						child: Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									'Choose Profile Picture',
									style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
								),
								const SizedBox(height: 10),
								Wrap(
									spacing: 8,
									runSpacing: 8,
									children: [
										ActionChip(
											avatar: const Icon(Icons.photo_library_outlined, size: 16),
											label: const Text('Photo Album'),
											onPressed: () async {
												Navigator.of(context).pop();
												await _pickImageFromAlbum();
											},
										),
										if (_avatarImageBytes != null)
											ActionChip(
												avatar: const Icon(Icons.delete_outline, size: 16),
												label: const Text('Remove Image'),
												onPressed: () {
													setState(() => _avatarImageBytes = null);
													_notifyProfileChanged();
													Navigator.of(context).pop();
												},
											),
									],
								),
								const SizedBox(height: 10),
								Wrap(
									spacing: 12,
									runSpacing: 12,
									children: avatars.map((icon) {
										final selected = icon == _avatarIcon;
										return IconButton(
											onPressed: () {
												setState(() {
													_avatarIcon = icon;
													_avatarImageBytes = null;
												});
												_notifyProfileChanged();
												Navigator.of(context).pop();
											},
											style: IconButton.styleFrom(
												backgroundColor: selected ? _avatarColor : Theme.of(context).colorScheme.surfaceContainerHighest,
												foregroundColor: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
											),
											icon: Icon(icon),
											tooltip: 'Select avatar',
										);
									}).toList(),
								),
							],
						),
					),
				);
			},
		);
	}

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;
		final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

		return Scaffold(
			appBar: AppBar(title: const Text('Profile')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					Center(
						child: Stack(
							clipBehavior: Clip.none,
							children: [
								CircleAvatar(
									radius: 44,
									backgroundColor: _avatarImageBytes == null
											? _avatarColor.withValues(alpha: 0.2)
											: Colors.transparent,
									backgroundImage: _avatarImageBytes != null
											? MemoryImage(_avatarImageBytes!)
											: null,
									child: _avatarImageBytes == null
											? Icon(_avatarIcon, size: 44, color: _avatarColor)
											: null,
								),
								Positioned(
									right: -4,
									bottom: -4,
									child: IconButton(
										onPressed: _openAvatarPicker,
										icon: const Icon(Icons.edit),
										style: IconButton.styleFrom(
											backgroundColor: _avatarColor,
											foregroundColor: Colors.white,
										),
										tooltip: 'Edit profile picture',
									),
								),
							],
						),
					),
					const SizedBox(height: 12),
					Center(
						child: Text(
							_name,
							style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
						),
					),
					const SizedBox(height: 4),
					Center(
						child: Text(
							_role,
							style: Theme.of(context).textTheme.bodyMedium,
						),
					),
					const SizedBox(height: 18),
					Card(
						child: Padding(
							padding: const EdgeInsets.all(14),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Row(
										children: [
											Text('Account Details', style: titleStyle),
											const Spacer(),
											if (!_isEditing)
												IconButton(
													onPressed: _startEditing,
													icon: const Icon(Icons.edit_outlined),
													tooltip: 'Edit account details',
												),
											if (_isEditing)
												IconButton(
													onPressed: _cancelEditing,
													icon: const Icon(Icons.close),
													tooltip: 'Cancel editing',
												),
										],
									),
									const SizedBox(height: 10),
									if (!_isEditing) ...[
										_ProfileDetailRow(label: 'Name', value: _name),
										_ProfileDetailRow(label: 'Role', value: _role),
										const _ProfileDetailRow(label: 'Email', value: _email),
									],
									if (_isEditing) ...[
										TextField(
											controller: _nameController,
											decoration: const InputDecoration(labelText: 'Name'),
										),
										const SizedBox(height: 10),
										TextField(
											controller: _roleController,
											decoration: const InputDecoration(labelText: 'Role'),
										),
										const SizedBox(height: 10),
										const _ProfileDetailRow(label: 'Email', value: _email),
										const SizedBox(height: 14),
										SizedBox(
											width: double.infinity,
											child: FilledButton.icon(
												onPressed: _saveProfile,
												icon: const Icon(Icons.save_outlined),
												label: const Text('Save'),
											),
										),
									],
								],
							),
						),
					),
					const SizedBox(height: 12),
					Container(
						decoration: BoxDecoration(
							border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
							borderRadius: BorderRadius.circular(12),
						),
						child: SwitchListTile.adaptive(
							value: widget.isDarkMode,
							onChanged: widget.onToggleDarkMode,
							title: const Text('Dark Mode'),
							subtitle: const Text('Apply dark theme to the entire application.'),
						),
					),
					const SizedBox(height: 12),
					Card(
						child: Padding(
							padding: const EdgeInsets.all(14),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text('Tips', style: titleStyle),
									const SizedBox(height: 8),
									const Text('Keep category budgets updated monthly to keep your dashboard accurate.'),
									const SizedBox(height: 6),
									const Text('Use the History tab to quickly review spending patterns by month.'),
								],
							),
						),
					),
				],
			),
		);
	}
}

class _ProfileDetailRow extends StatelessWidget {
	const _ProfileDetailRow({required this.label, required this.value});

	final String label;
	final String value;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 4),
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					SizedBox(
						width: 70,
						child: Text(
							label,
							style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
						),
					),
					Expanded(child: Text(value)),
				],
			),
		);
	}
}

class DashboardStats {
	DashboardStats({
		required this.spent,
		required this.remaining,
		required this.dailyAverage,
		required this.projected,
		required this.topCategory,
		required this.topCategoryAmount,
		required this.weekSpent,
		required this.largestExpense,
		required this.count,
		required this.percentUsed,
	});

	final double spent;
	final double remaining;
	final double dailyAverage;
	final double projected;
	final String topCategory;
	final double topCategoryAmount;
	final double weekSpent;
	final double largestExpense;
	final int count;
	final double percentUsed;

	String get topCategoryLabel {
		if (topCategory == '-') {
			return '-';
		}
		return topCategory;
	}

	factory DashboardStats.fromData(BudgetData data, DateTime now) {
		final monthKey = DateFormat('yyyy-MM').format(now);
		final monthTx = data.transactions.where((tx) => DateFormat('yyyy-MM').format(tx.date) == monthKey).toList();

		final spent = monthTx.fold<double>(0, (sum, tx) => sum + tx.amount);
		final remaining = data.monthlyAllowance - spent;
		final day = now.day;
		final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
		final dailyAverage = day > 0 ? spent / day : 0.0;
		final projected = dailyAverage * daysInMonth;

		final byCategory = <String, double>{};
		for (final tx in monthTx) {
			byCategory[tx.category] = (byCategory[tx.category] ?? 0) + tx.amount;
		}
		String topCategory = '-';
		double topAmount = 0;
		byCategory.forEach((name, amount) {
			if (amount > topAmount) {
				topCategory = name;
				topAmount = amount;
			}
		});

		final weekStart = now.subtract(const Duration(days: 7));
		final weekSpent = monthTx
				.where((tx) => tx.date.isAfter(weekStart) || tx.date.isAtSameMomentAs(weekStart))
				.fold<double>(0, (sum, tx) => sum + tx.amount);

		final largest = monthTx.fold<double>(0, (max, tx) => math.max(max, tx.amount));

		final percentUsed = data.monthlyAllowance > 0 ? (spent / data.monthlyAllowance) * 100 : 0.0;

		return DashboardStats(
			spent: spent,
			remaining: remaining,
			dailyAverage: dailyAverage,
			projected: projected,
			topCategory: topCategory,
			topCategoryAmount: topAmount,
			weekSpent: weekSpent,
			largestExpense: largest,
			count: monthTx.length,
			percentUsed: percentUsed,
		);
	}
}

class BudgetData {
	BudgetData({
		required this.monthlyAllowance,
		required this.categories,
		required this.transactions,
	});

	double monthlyAllowance;
	Map<String, double> categories;
	List<ExpenseTx> transactions;

	String toJson() {
		final map = {
			'monthlyAllowance': monthlyAllowance,
			'categories': categories,
			'transactions': transactions.map((t) => t.toMap()).toList(),
		};
		return jsonEncode(map);
	}

	factory BudgetData.fromJson(String raw) {
		try {
			final map = jsonDecode(raw) as Map<String, dynamic>;
			final categoriesRaw = map['categories'] as Map<String, dynamic>? ?? {};
			final txRaw = map['transactions'] as List<dynamic>? ?? [];
			final categories = <String, double>{};
			categoriesRaw.forEach((key, value) {
				final amount = (value as num?)?.toDouble();
				if (amount != null && amount > 0) {
					categories[key] = amount;
				}
			});
			return BudgetData(
				monthlyAllowance: ((map['monthlyAllowance'] as num?)?.toDouble() ?? 350),
				categories: categories.isEmpty ? BudgetData.defaultState().categories : categories,
				transactions: txRaw
						.map((item) => ExpenseTx.fromMap(item as Map<String, dynamic>))
						.toList(),
			);
		} catch (_) {
			return BudgetData.defaultState();
		}
	}

	factory BudgetData.defaultState() {
		return BudgetData(
			monthlyAllowance: 350,
			categories: {
				'Food': 120,
				'Transport': 70,
				'School': 80,
				'Leisure': 60,
			},
			transactions: [
				ExpenseTx(id: '1', title: 'Lunch', amount: 18, category: 'Food', date: DateTime(2026, 3, 2)),
				ExpenseTx(id: '2', title: 'Bus Card', amount: 22, category: 'Transport', date: DateTime(2026, 3, 4)),
				ExpenseTx(id: '3', title: 'Notebook', amount: 14, category: 'School', date: DateTime(2026, 3, 6)),
				ExpenseTx(id: '4', title: 'Snacks', amount: 11, category: 'Food', date: DateTime(2026, 3, 9)),
				ExpenseTx(id: '5', title: 'Movie', amount: 20, category: 'Leisure', date: DateTime(2026, 2, 18)),
			],
		);
	}
}

class ExpenseTx {
	ExpenseTx({
		required this.id,
		required this.title,
		required this.amount,
		required this.category,
		required this.date,
	});

	final String id;
	final String title;
	final double amount;
	final String category;
	final DateTime date;

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'title': title,
			'amount': amount,
			'category': category,
			'date': date.toIso8601String(),
		};
	}

	factory ExpenseTx.fromMap(Map<String, dynamic> map) {
		return ExpenseTx(
			id: map['id'] as String? ?? '${DateTime.now().microsecondsSinceEpoch}',
			title: map['title'] as String? ?? 'Untitled',
			amount: (map['amount'] as num?)?.toDouble() ?? 0,
			category: map['category'] as String? ?? 'General',
			date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
		);
	}
}

class SettingsPage extends StatefulWidget {
	const SettingsPage({
		super.key,
		required this.onLogout,
	});

	final VoidCallback onLogout;

	@override
	State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Settings'),
				centerTitle: true,
			),
			body: SafeArea(
				child: LayoutBuilder(
					builder: (context, constraints) {
						final padding = EdgeInsets.all(
							constraints.maxWidth < AppBreakpoints.compact ? AppStyles.pagePaddingCompact : AppStyles.pagePaddingRegular,
						);
						return SingleChildScrollView(
							padding: padding,
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
									const SizedBox(height: 12),
									Card(
										child: Padding(
											padding: const EdgeInsets.all(14),
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													const Text('Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
													const SizedBox(height: 12),
													SizedBox(
														width: double.infinity,
														child: FilledButton(
															style: FilledButton.styleFrom(
																backgroundColor: Colors.red.shade700,
																foregroundColor: Colors.white,
															),
															onPressed: () {
																showDialog(
																	context: context,
																	builder: (context) => AlertDialog(
																		title: const Text('Logout'),
																		content: const Text('Are you sure you want to logout? All data will be cleared.'),
																		actions: [
																			TextButton(
																				onPressed: () => Navigator.pop(context),
																				child: const Text('Cancel'),
																			),
																			FilledButton(
																				style: FilledButton.styleFrom(
																					backgroundColor: Colors.red.shade700,
																				),
																				onPressed: () {
																					Navigator.pop(context);
																					widget.onLogout();
																				},
																				child: const Text('Logout'),
																			),
																		],
																	),
																);
															},
															child: const Text('Logout'),
														),
													),
												],
											),
										),
									),
									const SizedBox(height: 12),
									Card(
										child: Padding(
											padding: const EdgeInsets.all(14),
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													const Text('About', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
													const SizedBox(height: 8),
													const Text('Allowance Budget Tracker v1.0'),
													const SizedBox(height: 8),
													const Text('Track your allowance, spending, and savings in one clear view.'),
												],
											),
										),
									),
								],
							),
						);
					},
				),
			),
		);
	}
}
