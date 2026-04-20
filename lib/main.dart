import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:country_flags/country_flags.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'data_service.dart';
import 'firebase_options.dart';
import 'app_styles.dart';
import 'pages/login_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/profile_page.dart';

part 'pages/dashboard_about_page.dart';
part 'pages/dashboard_categories_page.dart';
part 'pages/dashboard_expenses_page.dart';
part 'pages/dashboard_history_page.dart';
part 'pages/dashboard_faq_page.dart';
part 'pages/dashboard_monthly_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final prefs = await SharedPreferences.getInstance();
  runApp(CoinzyApp(initialDarkMode: prefs.getBool('darkMode') ?? false));
}

class CoinzyApp extends StatefulWidget {
  const CoinzyApp({super.key, required this.initialDarkMode});

  final bool initialDarkMode;

  @override
  State<CoinzyApp> createState() => _CoinzyAppState();
}

class _CoinzyAppState extends State<CoinzyApp> {
  late bool _isDarkMode;
  late final Stream<User?> _authStateChanges;
  late Future<bool> _onboardingFuture;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
    _authStateChanges = FirebaseAuth.instance.authStateChanges();
    // Cache the Future so it doesn't rebuild on theme changes
    _onboardingFuture = AuthService.isNewUser();
  }

  Future<void> _toggleDarkMode(bool value) async {
    if (value == _isDarkMode) return;

    if (mounted) {
      setState(() => _isDarkMode = value);
    }

    // Save preference in background
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
  }

  Future<void> _completeOnboardingAndRefresh() async {
    await AuthService.completeOnboarding();
    if (mounted) {
      // Refresh the onboarding check after completion
      setState(() {
        _onboardingFuture = AuthService.isNewUser();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A7A59),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A7A59),
          brightness: Brightness.dark,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: StreamBuilder<User?>(
        stream: _authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.data == null) {
            return LoginPage(
              isDarkMode: _isDarkMode,
              onToggleDarkMode: _toggleDarkMode,
            );
          }

          return FutureBuilder<bool>(
            future: _onboardingFuture,
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final needsOnboarding = onboardingSnapshot.data ?? false;
              if (needsOnboarding) {
                return OnboardingPage(
                  onComplete: _completeOnboardingAndRefresh,
                );
              }

              return AllowanceBudgetHome(
                isDarkMode: _isDarkMode,
                onToggleDarkMode: _toggleDarkMode,
              );
            },
          );
        },
      ),
    );
  }
}

/*

*/

class AllowanceBudgetHome extends StatefulWidget {
  const AllowanceBudgetHome({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;

  @override
  State<AllowanceBudgetHome> createState() => _AllowanceBudgetHomeState();
}

class _AllowanceBudgetHomeState extends State<AllowanceBudgetHome> {
  static const _storageKey = 'allowance-dashboard-v3-flutter';
  static const _legacyStorageKey = 'allowance-dashboard-v3-flutter';
  static const _currencyStoragePrefix = 'currency_code';

  static const Map<String, String> _currencySymbols = {
    'PHP': 'PHP ',
    'USD': 'USD ',
    'EUR': 'EUR ',
    'GBP': 'GBP ',
    'JPY': 'JPY ',
    'AUD': 'AUD ',
    'CAD': 'CAD ',
    'INR': 'INR ',
    'SGD': 'SGD ',
    'MXN': 'MXN ',
    'BRL': 'BRL ',
    'ZAR': 'ZAR ',
    'NZD': 'NZD ',
    'CHF': 'CHF ',
    'CNY': 'CNY ',
    'HKD': 'HKD ',
    'IDR': 'IDR ',
    'MYR': 'MYR ',
    'THB': 'THB ',
    'VND': 'VND ',
    'KRW': 'KRW ',
    'TWD': 'TWD ',
    'SEK': 'SEK ',
    'NOK': 'NOK ',
    'DKK': 'DKK ',
    'PLN': 'PLN ',
    'CZK': 'CZK ',
    'HUF': 'HUF ',
    'RON': 'RON ',
    'BGN': 'BGN ',
    'HRK': 'HRK ',
    'RUB': 'RUB ',
    'TRY': 'TRY ',
    'AED': 'AED ',
    'SAR': 'SAR ',
    'QAR': 'QAR ',
    'KWD': 'KWD ',
  };

  BudgetData _data = BudgetData.defaultState();
  bool _loading = true;

  final _allowanceController = TextEditingController();
  final _expenseTitleController = TextEditingController();
  final _expenseAmountController = TextEditingController();
  final _categoryNameController = TextEditingController();
  final _categoryBudgetController = TextEditingController();
  final _searchController = TextEditingController();

  String _expenseCategory = 'Food';
  DateTime _allowanceMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _expenseDate = DateTime.now();
  String _filterCategory = 'all';
  String _filterMonth = 'all';
  String _lineChartCategory = 'all';
  String _lineChartMonth = DateFormat('yyyy-MM').format(DateTime.now());
  int _lineChartWeek = 1;
  final Map<String, Color> _categoryLineColors = <String, Color>{};
  String _summaryPeriod = 'month';
  int _summaryYear = DateTime.now().year;
  int _summaryMonth = DateTime.now().month;
  int _summaryStartDay = 1;
  int _monthlyPage = 0;
  final int _historyRowsPerPage = 10;
  int _historyPage = 0;
  bool _monthlyShowAllowance = true;
  bool _monthlyShowSpent = true;
  bool _monthlyShowSaved = true;
  bool _monthlyShowRate = true;
  bool _isEditingAllowance = false;
  bool _isAddingExpense = false;
  int _selectedNavIndex = 0;
  String _currencyCode = 'PHP';

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
    Color(0xFF006BA4),
    Color(0xFFFF800E),
    Color(0xFFABABAB),
    Color(0xFF595959),
    Color(0xFF5F9ED1),
    Color(0xFFC85200),
    Color(0xFF898989),
    Color(0xFFA2C8EC),
    Color(0xFFFFBC79),
    Color(0xFFCFCFCF),
    Color(0xFFB30000),
    Color(0xFF7F3C8D),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    // _loadProfilePreview();
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_scopedStorageKey());
      final storedCurrency = prefs.getString(_scopedCurrencyKey());
      var nextData =
          raw == null ? BudgetData.defaultState() : BudgetData.fromJson(raw);

      // Reinstall clears local storage. If local is empty, restore from Firestore.
      final shouldRestoreFromCloud = _isDataEffectivelyEmpty(nextData);
      if (shouldRestoreFromCloud) {
        final restored = await _restoreDataFromFirestore();
        if (restored != null && !_isDataEffectivelyEmpty(restored)) {
          nextData = restored;
          await prefs.setString(_scopedStorageKey(), nextData.toJson());
        }
      }

      // One-time cleanup: remove old shared key so users do not inherit
      // previous account data from older app versions.
      if (prefs.containsKey(_legacyStorageKey)) {
        await prefs.remove(_legacyStorageKey);
      }

      setState(() {
        _data = nextData;
        _data.transactions = _dedupeTransactions(_data.transactions);
        if (_data.monthAllowances.isEmpty && _data.monthlyAllowance > 0) {
          // Backward compatibility: migrate legacy single allowance to current month only.
          _data.monthAllowances[_nowMonthKey()] = _data.monthlyAllowance;
        }
        _syncCategoryLineColors();
        _allowanceController.text =
            _allowanceForMonthKey(_monthKey(_allowanceMonth))
                .toStringAsFixed(0);
        _expenseCategory = _data.categories.keys.isNotEmpty
            ? _data.categories.keys.first
            : 'General';
        _currencyCode = _currencySymbols.containsKey(storedCurrency)
            ? storedCurrency!
            : 'PHP';
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  bool _isDataEffectivelyEmpty(BudgetData data) {
    final hasAllowance =
        data.monthlyAllowance > 0 || data.monthAllowances.isNotEmpty;
    final hasCategories = data.categories.isNotEmpty;
    final hasTransactions = data.transactions.isNotEmpty;
    return !hasAllowance && !hasCategories && !hasTransactions;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  Future<BudgetData?> _restoreDataFromFirestore() async {
    try {
      final remoteTransactions = await DataService.getAllTransactions();
      final remoteCategories = await DataService.getAllCategories();
      final remoteAllowance = await DataService.getMonthlyAllowance();

      if (remoteTransactions.isEmpty &&
          remoteCategories.isEmpty &&
          remoteAllowance <= 0) {
        return null;
      }

      final categories = <String, double>{};
      for (final row in remoteCategories) {
        final name =
            ((row['name'] as String?) ?? (row['id'] as String?) ?? '').trim();
        final budget = (row['budget'] as num?)?.toDouble() ?? 0;
        if (name.isNotEmpty && budget > 0) {
          categories[name] = budget;
        }
      }

      final transactions = <ExpenseTx>[];
      for (final row in remoteTransactions) {
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        if (amount <= 0) {
          continue;
        }

        final category = ((row['category'] as String?) ?? '').trim();
        final title = ((row['description'] as String?) ?? '').trim();
        final date = _toDateTime(row['date']) ?? DateTime.now();

        transactions.add(
          ExpenseTx(
            id: (row['id'] as String?) ??
                '${date.microsecondsSinceEpoch}_${transactions.length}',
            title: title.isEmpty ? 'Untitled' : title,
            amount: amount,
            category: category.isEmpty ? 'General' : category,
            date: date,
          ),
        );
      }

      final monthAllowances = <String, double>{};
      if (remoteAllowance > 0) {
        monthAllowances[_nowMonthKey()] = remoteAllowance;
      }

      return BudgetData(
        monthlyAllowance: remoteAllowance,
        monthAllowances: monthAllowances,
        categories: categories,
        transactions: _dedupeTransactions(transactions),
      );
    } catch (e) {
      debugPrint('Error restoring data from Firestore: $e');
      return null;
    }
  }

  List<ExpenseTx> _dedupeTransactions(List<ExpenseTx> source) {
    final seenIds = <String>{};
    final seenFingerprints = <String>{};
    final result = <ExpenseTx>[];

    for (final tx in source) {
      if (seenIds.contains(tx.id)) {
        continue;
      }

      final fingerprint =
          '${tx.title.trim().toLowerCase()}|${tx.category.trim().toLowerCase()}|${tx.amount.toStringAsFixed(2)}|${tx.date.toIso8601String()}';
      if (seenFingerprints.contains(fingerprint)) {
        continue;
      }

      seenIds.add(tx.id);
      seenFingerprints.add(fingerprint);
      result.add(tx);
    }

    return result;
  }

  String _scopedCurrencyKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return '${_currencyStoragePrefix}_guest';
    }
    return '${_currencyStoragePrefix}_$uid';
  }

  Future<void> _setCurrencyCode(String nextCode) async {
    if (!_currencySymbols.containsKey(nextCode)) {
      return;
    }

    setState(() => _currencyCode = nextCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedCurrencyKey(), nextCode);
  }

  Future<void> _logoutFromSettings() async {
    await AuthService.signOut();
  }

  String? _findCategoryKeyIgnoreCase(String input) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    for (final key in _data.categories.keys) {
      if (key.toLowerCase() == normalized) {
        return key;
      }
    }
    return null;
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
      if (!used.contains(seed) && _isDistinctColor(seed, used)) {
        return seed;
      }
    }

    const saturations = <double>[0.72, 0.62, 0.82];
    const lightnesses = <double>[0.48, 0.40, 0.56];
    for (var i = 0; i < 360; i++) {
      final hue = ((used.length * 41) + (i * 37)) % 360;
      for (final saturation in saturations) {
        for (final lightness in lightnesses) {
          final color =
              HSLColor.fromAHSL(1, hue.toDouble(), saturation, lightness)
                  .toColor();
          if (!used.contains(color) && _isDistinctColor(color, used)) {
            return color;
          }
        }
      }
    }

    Color best = Colors.primaries[used.length % Colors.primaries.length];
    var bestScore = -1.0;
    for (var i = 0; i < 360; i++) {
      final hue = (i * 17) % 360;
      final candidate =
          HSLColor.fromAHSL(1, hue.toDouble(), 0.70, 0.46).toColor();
      if (used.contains(candidate)) {
        continue;
      }
      final score = _minDistanceToUsed(candidate, used);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    return best;
  }

  bool _isDistinctColor(Color candidate, Set<Color> used,
      {double minDistance = 90}) {
    if (used.isEmpty) {
      return true;
    }
    return used.every(
        (existing) => _colorDistance(candidate, existing) >= minDistance);
  }

  double _minDistanceToUsed(Color candidate, Set<Color> used) {
    if (used.isEmpty) {
      return double.infinity;
    }
    var minDistance = double.infinity;
    for (final existing in used) {
      final distance = _colorDistance(candidate, existing);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    return minDistance;
  }

  double _colorDistance(Color a, Color b) {
    final dr = (a.red - b.red).toDouble();
    final dg = (a.green - b.green).toDouble();
    final db = (a.blue - b.blue).toDouble();
    return math.sqrt((dr * dr) + (dg * dg) + (db * db));
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_scopedStorageKey(), _data.toJson());
      debugPrint('[Save] SharedPreferences updated successfully');
    } catch (e) {
      debugPrint('[Save] SharedPreferences error: $e');
      rethrow;
    }
  }

  String _scopedStorageKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return '${_storageKey}_guest';
    }
    return '${_storageKey}_$uid';
  }

  String _money(num value) {
    final symbol = _currencySymbols[_currencyCode] ?? 'PHP ';
    return NumberFormat.currency(symbol: symbol, decimalDigits: 0)
        .format(value);
  }

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

  double _allowanceForMonthKey(String monthKey) {
    final fromMap = _data.monthAllowances[monthKey];
    if (fromMap != null && fromMap > 0) {
      return fromMap;
    }

    // Legacy fallback: only treat old global value as current-month allowance.
    if (monthKey == _nowMonthKey() && _data.monthlyAllowance > 0) {
      return _data.monthlyAllowance;
    }

    return 0;
  }

  Future<void> _pickAllowanceMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _allowanceMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) {
      return;
    }

    final monthStart = DateTime(picked.year, picked.month, 1);
    if (!mounted) {
      return;
    }
    setState(() {
      _allowanceMonth = monthStart;
      _allowanceController.text =
          _allowanceForMonthKey(_monthKey(monthStart)).toStringAsFixed(0);
      _isEditingAllowance = true;
    });
  }

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
    final months =
        _data.transactions.map((tx) => _monthKey(tx.date)).toSet().toList();
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
    final selectedYear =
        years.contains(_summaryYear) ? _summaryYear : years.first;

    if (_summaryPeriod == 'year') {
      return years.map((year) {
        final start = DateTime(year, 1, 1);
        final end = DateTime(year + 1, 1, 1);
        final spent = _data.transactions
            .where((tx) => !tx.date.isBefore(start) && tx.date.isBefore(end))
            .fold<double>(0, (sum, tx) => sum + tx.amount);
        final allowance = List<int>.generate(12, (idx) => idx + 1)
            .map((month) =>
                _allowanceForMonthKey(_monthKey(DateTime(year, month, 1))))
            .fold<double>(0, (sum, value) => sum + value);
        return _PeriodSummaryRow(
            label: '$year', allowance: allowance, spent: spent);
      }).toList();
    }

    if (_summaryPeriod == 'week') {
      final daysInMonth = DateTime(selectedYear, _summaryMonth + 1, 0).day;
      final startDaySeed = _summaryStartDay.clamp(1, daysInMonth);
      final rows = <_PeriodSummaryRow>[];
      for (var startDay = startDaySeed, i = 1;
          startDay <= daysInMonth;
          startDay += 7, i++) {
        final endDay = math.min(startDay + 6, daysInMonth);
        final start = DateTime(selectedYear, _summaryMonth, startDay);
        final end = DateTime(selectedYear, _summaryMonth, endDay + 1);
        final spent = _data.transactions
            .where((tx) => !tx.date.isBefore(start) && tx.date.isBefore(end))
            .fold<double>(0, (sum, tx) => sum + tx.amount);
        final ratio = (endDay - startDay + 1) / daysInMonth;
        final monthAllowance = _allowanceForMonthKey(
            _monthKey(DateTime(selectedYear, _summaryMonth, 1)));
        final allowance = monthAllowance * ratio;
        rows.add(
          _PeriodSummaryRow(
            label:
                'Week $i (${DateFormat('MMM d').format(start)} - ${DateFormat('d').format(DateTime(selectedYear, _summaryMonth, endDay))})',
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
        allowance: _allowanceForMonthKey(_monthKey(start)),
        spent: spent,
      );
    });
  }

  int _monthlyVisibleColumnCount() {
    var count = 1;
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
      if (query.isNotEmpty) {
        final titleMatch = tx.title.toLowerCase().contains(query);
        final categoryMatch = tx.category.toLowerCase().contains(query);
        if (!titleMatch && !categoryMatch) {
          return false;
        }
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

  List<ExpenseTx> _sortedHistoryRowsForExport(List<ExpenseTx> rows) {
    final exportedRows = List<ExpenseTx>.from(rows)
      ..sort((a, b) {
        final categoryCompare =
            a.category.toLowerCase().compareTo(b.category.toLowerCase());
        if (categoryCompare != 0) {
          return categoryCompare;
        }
        return a.date.compareTo(b.date);
      });
    return exportedRows;
  }

  String _historyExportBaseFileName() {
    final exportDate = DateFormat('MM-dd-yyyy').format(DateTime.now());
    final selectedCategory = _filterCategory == 'all'
        ? null
        : _filterCategory
            .trim()
            .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
            .replaceAll(RegExp(r'\s+'), '_');
    return selectedCategory == null || selectedCategory.isEmpty
        ? 'History_Transaction_($exportDate)'
        : 'History_Transaction_($selectedCategory)_($exportDate)';
  }

  Future<void> _saveHistoryExportFile({
    required Uint8List bytes,
    required String fileExtension,
    required MimeType mimeType,
  }) async {
    final fileName = _historyExportBaseFileName();
    String? savedPath;

    try {
      savedPath = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: bytes,
        fileExtension: fileExtension,
        mimeType: mimeType,
      );
    } catch (_) {
      savedPath = null;
    }

    if (savedPath == null || savedPath.trim().isEmpty) {
      savedPath = await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: fileExtension,
        mimeType: mimeType,
      );
    }

    final normalizedPath = savedPath.trim();
    if (normalizedPath.isEmpty ||
        normalizedPath.toLowerCase().contains('something went wrong')) {
      throw Exception('File saver did not return a valid save path.');
    }
  }

  Future<void> _exportHistoryToExcel(List<ExpenseTx> rows) async {
    if (rows.isEmpty) {
      _showHint('There are no transactions to export for this filter.');
      return;
    }

    try {
      final excel = Excel.createExcel();
      final sheet = excel['History'];
      final exportedRows = _sortedHistoryRowsForExport(rows);
      final totalSpent =
          exportedRows.fold<double>(0, (sum, tx) => sum + tx.amount);
      final categoryCount =
          exportedRows.map((tx) => tx.category).toSet().length;
      final firstDate = exportedRows.first.date;
      final lastDate = exportedRows.last.date;

      excel.merge(
        'History',
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0),
        customValue: TextCellValue('Coinzy Transaction History'),
      );
      sheet.appendRow([
        TextCellValue(''),
      ]);

      excel.merge(
        'History',
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1),
        customValue: TextCellValue(
          'Allowance and spending export • ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
        ),
      );

      sheet.appendRow([
        TextCellValue('Transactions'),
        TextCellValue(exportedRows.length.toString()),
        TextCellValue('Total Spent'),
        TextCellValue(_money(totalSpent)),
      ]);

      sheet.appendRow([
        TextCellValue('Categories'),
        TextCellValue(categoryCount.toString()),
        TextCellValue('Range'),
        TextCellValue(
          '${DateFormat('MMM d').format(firstDate)} - ${DateFormat('MMM d').format(lastDate)}',
        ),
      ]);

      final titleCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      );
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 20,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('FF1A7A59'),
        fontColorHex: ExcelColor.white,
      );

      final subtitleCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      );
      subtitleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 11,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('FFE2EFE8'),
        fontColorHex: ExcelColor.fromHexString('FF1A7A59'),
      );

      final summaryLabelsStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('FFE2EFE8'),
        fontColorHex: ExcelColor.fromHexString('FF1A7A59'),
      );
      final summaryValuesStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('FFF7FBF8'),
      );

      for (var col = 0; col < 4; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2))
            .cellStyle = col.isEven ? summaryLabelsStyle : summaryValuesStyle;
      }
      for (var col = 0; col < 4; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3))
            .cellStyle = col.isEven ? summaryLabelsStyle : summaryValuesStyle;
      }

      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Title'),
        TextCellValue('Amount ($_currencyCode)'),
      ]);

      final headerCellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('FF1A7A59'),
        fontColorHex: ExcelColor.white,
      );
      final dataCellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      for (var col = 0; col < 4; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 4))
            .cellStyle = headerCellStyle;
      }

      final categoryStyles = <String, CellStyle>{};
      CellStyle styleForCategory(String category) {
        return categoryStyles.putIfAbsent(category, () {
          final chartColor = _categoryLineColors[category] ?? Colors.grey;
          final backgroundHex = chartColor
              .toARGB32()
              .toRadixString(16)
              .toUpperCase()
              .padLeft(8, '0');
          final fontColor = chartColor.computeLuminance() < 0.5
              ? ExcelColor.white
              : ExcelColor.black;

          return CellStyle(
            backgroundColorHex: ExcelColor.fromHexString(backgroundHex),
            fontColorHex: fontColor,
            horizontalAlign: HorizontalAlign.Center,
            verticalAlign: VerticalAlign.Center,
          );
        });
      }

      for (var i = 0; i < exportedRows.length; i++) {
        final tx = exportedRows[i];
        sheet.appendRow([
          TextCellValue(DateFormat('yyyy-MM-dd').format(tx.date)),
          TextCellValue(tx.category),
          TextCellValue(tx.title),
          DoubleCellValue(tx.amount),
        ]);

        final categoryCell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: i + 5,
          ),
        );
        categoryCell.cellStyle = styleForCategory(tx.category);

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 5))
            .cellStyle = dataCellStyle;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 5))
            .cellStyle = dataCellStyle;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 5))
            .cellStyle = dataCellStyle;
      }

      var maxDateLen = 'Date'.length;
      var maxCategoryLen = 'Category'.length;
      var maxTitleLen = 'Title'.length;
      var maxAmountLen = 'Amount ($_currencyCode)'.length;
      for (final tx in exportedRows) {
        maxDateLen = math.max(
            maxDateLen, DateFormat('yyyy-MM-dd').format(tx.date).length);
        maxCategoryLen = math.max(maxCategoryLen, tx.category.length);
        maxTitleLen = math.max(maxTitleLen, tx.title.length);
        maxAmountLen = math.max(maxAmountLen, _money(tx.amount).length);
      }
      double columnWidth(int len, double min, double max) {
        final calculated = len + 2.0;
        return calculated.clamp(min, max);
      }

      sheet.setColumnWidth(0, columnWidth(maxDateLen, 11, 16));
      sheet.setColumnWidth(1, columnWidth(maxCategoryLen, 10, 18));
      sheet.setColumnWidth(2, columnWidth(maxTitleLen, 14, 34));
      sheet.setColumnWidth(3, columnWidth(maxAmountLen, 14, 22));

      final fileBytes = excel.save();
      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception('Unable to generate Excel file bytes.');
      }

      await _saveHistoryExportFile(
        bytes: Uint8List.fromList(fileBytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) {
        return;
      }

      _showSweetNotification(
        title: 'Export Successful',
        message: 'Done! Your history Excel file is ready.',
        icon: Icons.download_done_rounded,
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('Error exporting history to Excel: $e');
      if (!mounted) {
        return;
      }
      _showSweetNotification(
        title: 'Export Failed',
        message: 'Could not export Excel file. Please try again.',
        icon: Icons.error_outline_rounded,
        backgroundColor: const Color(0xFFB91C1C),
        foregroundColor: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _exportHistoryToPdf(List<ExpenseTx> rows) async {
    if (rows.isEmpty) {
      _showHint('There are no transactions to export for this filter.');
      return;
    }

    try {
      final exportedRows = _sortedHistoryRowsForExport(rows);
      final pdf = pw.Document();
      final totalSpent =
          exportedRows.fold<double>(0, (sum, tx) => sum + tx.amount);
      final categoryCount =
          exportedRows.map((tx) => tx.category).toSet().length;
      final exportDateLabel = DateFormat('MMM d, yyyy').format(DateTime.now());

      pw.Widget plainCell(String value) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Center(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        );
      }

      pw.Widget buildSummaryCard({
        required String title,
        required String value,
      }) {
        return pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(const Color(0xFFE2EFE8).toARGB32()),
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(
                color: PdfColor.fromInt(const Color(0xFF1A7A59).toARGB32()),
                width: 0.8,
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromInt(const Color(0xFF1A7A59).toARGB32()),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      pw.Widget categoryCell(String category) {
        final chartColor = _categoryLineColors[category] ?? Colors.grey;
        final bgColor = PdfColor.fromInt(chartColor.toARGB32());
        final fgColor = chartColor.computeLuminance() < 0.5
            ? PdfColors.white
            : PdfColors.black;

        return pw.Container(
          color: bgColor,
          padding: const pw.EdgeInsets.all(6),
          child: pw.Center(
            child: pw.Text(
              category,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(color: fgColor, fontSize: 10),
            ),
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(const Color(0xFF1A7A59).toARGB32()),
                borderRadius: pw.BorderRadius.circular(16),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 52,
                    height: 52,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(16),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'C',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(
                              const Color(0xFF1A7A59).toARGB32()),
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Coinzy Transaction History',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Allowance and spending export • $exportDateLabel',
                          style: const pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                buildSummaryCard(
                  title: 'Transactions',
                  value: exportedRows.length.toString(),
                ),
                pw.SizedBox(width: 8),
                buildSummaryCard(
                  title: 'Total Spent',
                  value: _money(totalSpent),
                ),
                pw.SizedBox(width: 8),
                buildSummaryCard(
                  title: 'Categories',
                  value: categoryCount.toString(),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Table(
              tableWidth: pw.TableWidth.min,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.IntrinsicColumnWidth(),
                1: const pw.IntrinsicColumnWidth(),
                2: const pw.IntrinsicColumnWidth(flex: 2),
                3: const pw.IntrinsicColumnWidth(),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Container(
                      color:
                          PdfColor.fromInt(const Color(0xFFE2EFE8).toARGB32()),
                      child: plainCell('Date'),
                    ),
                    pw.Container(
                      color:
                          PdfColor.fromInt(const Color(0xFFE2EFE8).toARGB32()),
                      child: plainCell('Category'),
                    ),
                    pw.Container(
                      color:
                          PdfColor.fromInt(const Color(0xFFE2EFE8).toARGB32()),
                      child: plainCell('Title'),
                    ),
                    pw.Container(
                      color:
                          PdfColor.fromInt(const Color(0xFFE2EFE8).toARGB32()),
                      child: plainCell('Amount ($_currencyCode)'),
                    ),
                  ],
                ),
                ...exportedRows.map((tx) {
                  return pw.TableRow(
                    children: [
                      plainCell(DateFormat('yyyy-MM-dd').format(tx.date)),
                      categoryCell(tx.category),
                      plainCell(tx.title),
                      plainCell(_money(tx.amount)),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      );

      await _saveHistoryExportFile(
        bytes: Uint8List.fromList(await pdf.save()),
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );

      if (!mounted) {
        return;
      }

      _showSweetNotification(
        title: 'Export Successful',
        message: 'Done! Your history PDF file is ready.',
        icon: Icons.picture_as_pdf_outlined,
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('Error exporting history to PDF: $e');
      if (!mounted) {
        return;
      }
      _showSweetNotification(
        title: 'Export Failed',
        message: 'Could not export PDF file. Please try again.',
        icon: Icons.error_outline_rounded,
        backgroundColor: const Color(0xFFB91C1C),
        foregroundColor: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<bool> _saveAllowance() async {
    final next = double.tryParse(_allowanceController.text.trim());
    if (next == null || next <= 0) {
      _showBasicSnack('Enter a valid monthly allowance greater than 0.');
      return false;
    }
    final selectedMonthKey = _monthKey(_allowanceMonth);
    final isCurrentMonth = selectedMonthKey == _nowMonthKey();

    try {
      setState(() {
        _data.monthAllowances[selectedMonthKey] = next;
        if (isCurrentMonth) {
          _data.monthlyAllowance = next;
        }
      });
      await _save();
      if (isCurrentMonth) {
        unawaited(DataService.setMonthlyAllowance(next));
      }

      if (!mounted) {
        return true;
      }

      _showBasicSnack(
        'Allowance for ${DateFormat('MMM yyyy').format(_allowanceMonth)} has been set successfully.',
        backgroundColor: const Color(0xFF166534),
        textColor: Colors.white,
      );
      return true;
    } catch (e) {
      debugPrint('Error saving allowance: $e');
      if (mounted) {
        _showBasicSnack(
          'Error saving allowance: $e',
          backgroundColor: const Color(0xFFB91C1C),
          textColor: Colors.white,
        );
      }
      return false;
    }
  }

  void _showBasicSnack(
    String text, {
    Color? backgroundColor,
    Color? textColor,
  }) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        content: Text(
          text,
          style: textColor == null ? null : TextStyle(color: textColor),
        ),
      ),
    );
  }

  Future<void> _addExpense() async {
    if (_isAddingExpense) {
      return;
    }

    final title = _expenseTitleController.text.trim();
    final amount = double.tryParse(_expenseAmountController.text.trim());
    final category = _expenseCategory;
    if (title.isEmpty || amount == null || amount <= 0) {
      _showHint('Add an expense name and an amount greater than 0.');
      return;
    }

    setState(() => _isAddingExpense = true);
    try {
      final expenseMonthKey = _monthKey(_expenseDate);
      final categoryBudget = _data.categories[category] ?? 0;
      if (categoryBudget > 0) {
        final currentCategorySpent = _data.transactions
            .where((tx) =>
                tx.category == category &&
                _monthKey(tx.date) == expenseMonthKey)
            .fold<double>(0, (sum, tx) => sum + tx.amount);
        final projectedSpent = currentCategorySpent + amount;

        if (projectedSpent > categoryBudget) {
          final shouldContinue = await _showCategoryBudgetWarning(
            category: category,
            budget: categoryBudget,
            currentSpent: currentCategorySpent,
            nextAmount: amount,
            monthKey: expenseMonthKey,
          );
          if (!shouldContinue) {
            return;
          }
        }
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
        _data.transactions = _dedupeTransactions(_data.transactions);
        _expenseTitleController.clear();
        _expenseAmountController.clear();
      });
      await _save();
      _showSweetNotification(
        title: 'Expense Added',
        message: '$title was added under $category.',
        icon: Icons.check_circle_outline_rounded,
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
      );
      unawaited(DataService.saveTransaction(
        transactionId: tx.id,
        category: tx.category,
        amount: tx.amount,
        date: tx.date,
        description: tx.title,
      ));
    } finally {
      if (mounted) {
        setState(() => _isAddingExpense = false);
      } else {
        _isAddingExpense = false;
      }
    }
  }

  Future<void> _upsertCategory() async {
    final name = _categoryNameController.text.trim();
    final budget = double.tryParse(_categoryBudgetController.text.trim());
    if (name.isEmpty || budget == null || budget <= 0) {
      _showHint('Category name and budget must both be valid.');
      return;
    }

    final existingKey = _findCategoryKeyIgnoreCase(name);
    final targetKey = existingKey ?? name;
    final existed = existingKey != null;
    final currentBudget = existed ? (_data.categories[targetKey] ?? 0) : null;

    if (existed &&
        currentBudget != null &&
        (currentBudget - budget).abs() < 0.0001) {
      _showHint(
          'No changes detected. The category budget is already set to this amount.');
      return;
    }

    final allowanceMonthLabel = DateFormat('MMM yyyy').format(DateTime.now());
    final currentMonthAllowance = _allowanceForMonthKey(_nowMonthKey());
    final existingTotalCategoryBudget =
        _data.categories.values.fold<double>(0, (sum, value) => sum + value);
    final projectedTotalCategoryBudget =
        existingTotalCategoryBudget - (currentBudget ?? 0) + budget;

    if (currentMonthAllowance > 0 &&
        projectedTotalCategoryBudget > currentMonthAllowance) {
      final remainingAllowance =
          currentMonthAllowance - existingTotalCategoryBudget;
      final shouldContinue = await _showCategoryAllowanceWarning(
        category: targetKey,
        categoryBudget: budget,
        allowance: remainingAllowance,
        allowanceMonthLabel: allowanceMonthLabel,
      );
      if (!shouldContinue) {
        return;
      }
    }

    try {
      setState(() {
        _data.categories[targetKey] = budget;
        _syncCategoryLineColors();
        _categoryNameController.clear();
        _categoryBudgetController.clear();
        if (!_data.categories.containsKey(_expenseCategory)) {
          _expenseCategory = targetKey;
        }
      });

      _showSweetNotification(
        title: existed ? 'Category Updated' : 'Category Added',
        message: existed
            ? 'Category updated successfully.'
            : 'Category added successfully.',
        icon: Icons.check_circle_rounded,
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
      );
      unawaited(DataService.saveCategory(
        categoryName: targetKey,
        budget: budget,
      ));
      unawaited(_saveWithHintOnError('saving category'));
    } catch (e) {
      debugPrint('Error upserting category: $e');
      if (mounted) {
        _showHint('Error saving category: $e');
      }
    }
  }

  Future<void> _removeCategory() async {
    final name = _categoryNameController.text.trim();
    if (name.isEmpty) {
      _showHint('Enter a category name to remove.');
      return;
    }

    final targetKey = _findCategoryKeyIgnoreCase(name);
    if (targetKey == null) {
      _showHint('Category not found.');
      return;
    }

    setState(() {
      _data.categories.remove(targetKey);
      _categoryLineColors.remove(targetKey);
      _categoryNameController.clear();
      _categoryBudgetController.clear();

      final remaining = _data.categories.keys.toList()..sort();
      if (_expenseCategory == targetKey) {
        _expenseCategory = remaining.isNotEmpty ? remaining.first : '';
      }
      if (_filterCategory == targetKey) {
        _filterCategory = 'all';
      }
      if (_lineChartCategory == targetKey) {
        _lineChartCategory = 'all';
      }
    });
    _showSweetNotification(
      title: 'Category Removed',
      message: 'Category removed successfully.',
      icon: Icons.delete_outline_rounded,
      backgroundColor: const Color(0xFF166534),
      foregroundColor: Colors.white,
    );
    unawaited(DataService.deleteCategory(targetKey));
    unawaited(_saveWithHintOnError('removing category'));
  }

  void _showHint(String text) {
    final scheme = Theme.of(context).colorScheme;
    _showSweetNotification(
      title: 'Notice',
      message: text,
      icon: Icons.info_outline_rounded,
      backgroundColor: scheme.surfaceContainerHighest,
      foregroundColor: scheme.onSurface,
    );
  }

  void _showSweetNotification({
    required String title,
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        elevation: 10,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foregroundColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                        color: foregroundColor.withValues(alpha: 0.95)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveWithHintOnError(String action) async {
    try {
      await _save();
    } catch (e) {
      if (mounted) {
        _showSweetNotification(
          title: 'Save Failed',
          message: 'Error $action: $e',
          icon: Icons.error_outline_rounded,
          backgroundColor: const Color(0xFFB91C1C),
          foregroundColor: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  void _runState(VoidCallback action) {
    setState(action);
  }

  Future<void> _showSuccessAlert({
    required String title,
    required String message,
  }) async {
    if (!mounted) {
      debugPrint('[Success Alert] Widget not mounted, skipping dialog: $title');
      return;
    }

    try {
      final scheme = Theme.of(context).colorScheme;

      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(title)),
              ],
            ),
            content: Text(message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      debugPrint('[Success Alert] Dialog dismissed: $title');
    } catch (e) {
      debugPrint('[Success Alert] Error showing alert: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $message'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<bool> _showCategoryBudgetWarning({
    required String category,
    required double budget,
    required double currentSpent,
    required double nextAmount,
    required String monthKey,
  }) async {
    if (!mounted) {
      return false;
    }

    final projected = currentSpent + nextAmount;
    final overBy = projected - budget;

    final decision = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: scheme.error),
              const SizedBox(width: 8),
              const Expanded(child: Text('Category Budget Warning')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This expense exceeds your $category budget for ${_monthLabel(monthKey)}.',
              ),
              const SizedBox(height: 10),
              Text('Budget: ${_money(budget)}'),
              Text('Current spent: ${_money(currentSpent)}'),
              Text('New expense: ${_money(nextAmount)}'),
              const SizedBox(height: 6),
              Text(
                'Projected spent: ${_money(projected)} (${_money(overBy)} over)',
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    return decision ?? false;
  }

  Future<bool> _showCategoryAllowanceWarning({
    required String category,
    required double categoryBudget,
    required double allowance,
    required String allowanceMonthLabel,
  }) async {
    if (!mounted) {
      return false;
    }

    final overBy = categoryBudget - allowance;
    final decision = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: scheme.error),
              const SizedBox(width: 8),
              const Expanded(child: Text('Category Budget Warning')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The $category budget is higher than your remaining allowance for $allowanceMonthLabel.',
              ),
              const SizedBox(height: 10),
              Text('Category budget: ${_money(categoryBudget)}'),
              Text('Remaining allowance: ${_money(allowance)}'),
              const SizedBox(height: 6),
              Text(
                'Over by: ${_money(overBy)}',
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Do you want to continue anyway?'),
              const SizedBox(height: 4),
              Text('Remaining allowance month: $allowanceMonthLabel'),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    return decision ?? false;
  }

  void _openSettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          isDarkMode: widget.isDarkMode,
          onToggleDarkMode: widget.onToggleDarkMode,
          currencyCode: _currencyCode,
          currencySymbols: _currencySymbols,
          onCurrencyChanged: _setCurrencyCode,
          onLogout: _logoutFromSettings,
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return IconButton(
      onPressed: _openSettingsPage,
      icon: const Icon(Icons.settings_outlined),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFE2EFE8),
        foregroundColor: const Color(0xFF1A7A59),
        padding: EdgeInsets.zero,
        minimumSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      tooltip: 'Settings',
    );
  }

  void _openProfilePage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProfilePage(),
      ),
    );
  }

  Widget _buildProfileButton() {
    return IconButton(
      onPressed: _openProfilePage,
      icon: const Icon(Icons.person_outline),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFE2EFE8),
        foregroundColor: const Color(0xFF1A7A59),
        padding: EdgeInsets.zero,
        minimumSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      tooltip: 'Profile',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.10),
              scheme.surface,
              scheme.secondary.withValues(alpha: 0.07),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < AppBreakpoints.compact;
              final wide = constraints.maxWidth >= AppBreakpoints.medium;
              final padding = EdgeInsets.all(
                compact
                    ? AppStyles.pagePaddingCompact
                    : AppStyles.pagePaddingRegular,
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
    final sectionKey = <int, String>{
          0: 'overview',
          1: 'expenses',
          2: 'categories',
          3: 'monthly',
          4: 'history',
          5: 'about',
        }[_selectedNavIndex] ??
        'section';
    Widget section;
    switch (_selectedNavIndex) {
      case 0:
        final scheme = Theme.of(context).colorScheme;
        final today = DateTime.now();
        section = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeading(
              title: 'Overview',
              subtitle:
                  'See your allowance status, spending trends, and quick insights at a glance.',
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.16),
                      scheme.primaryContainer.withValues(alpha: 0.35),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('EEE').format(today).toUpperCase(),
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('d').format(today),
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live today',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(today),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMMM yyyy').format(today),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildSummary(stats),
            const SizedBox(height: 10),
            _buildVisualsSection(),
          ],
        );
        break;
      case 1:
        section = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeading(
              title: 'Expenses',
              subtitle: 'Add and monitor expenses quickly with clear guidance.',
            ),
            const SizedBox(height: 10),
            _buildMainArea(stats, categoryNames),
          ],
        );
        break;
      case 2:
        section = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeading(
              title: 'Categories',
              subtitle:
                  'Set category budgets to make spending limits easier to follow.',
            ),
            const SizedBox(height: 10),
            _buildCategorySection(),
          ],
        );
        break;
      case 3:
        section = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeading(
              title: 'Monthly Summaries Table',
              subtitle: 'Review monthly totals in a clean table view.',
            ),
            const SizedBox(height: 10),
            _buildMonthlySection(),
          ],
        );
        break;
      case 4:
        section = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeading(
              title: 'Transaction History',
              subtitle:
                  'Filter and search your transactions without scrolling through other sections.',
            ),
            const SizedBox(height: 10),
            _buildHistorySection(txRows, categoryNames, monthOptions),
          ],
        );
        break;
      case 5:
        section = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeading(
              title: 'About',
              subtitle: 'About this allowance and budget tracker.',
            ),
            const SizedBox(height: 10),
            _buildAboutCard(),
          ],
        );
        break;
      default:
        section = const SizedBox.shrink();
    }

    if (showProfileButton) {
      section = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Text(
                  'Coinzy',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                _buildSettingsButton(),
                const SizedBox(width: 8),
                _buildProfileButton(),
              ],
            ),
          ),
          const SizedBox(height: 10),
          section,
        ],
      );
    }

    section = SingleChildScrollView(
      key: ValueKey(sectionKey),
      child: section,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: section,
    );
  }

  Widget _buildSectionHeading(
      {required String title, required String subtitle}) {
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

  Widget _buildSummary(DashboardStats stats) {
    final cards = [
      _SummaryCard(
          label: 'Monthly Allowance',
          value: _money(_allowanceForMonthKey(_nowMonthKey())),
          note: 'Current month allocation'),
      _SummaryCard(
          label: 'Expenses',
          value: _money(stats.spent),
          note: '${stats.count} transactions',
          tone: SummaryTone.warn),
      _SummaryCard(
        label: 'Remaining',
        value: _money(stats.remaining),
        note: stats.remaining < 0
            ? '${_money(stats.remaining.abs())} over budget'
            : 'Healthy pace',
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
          children:
              cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
        );
      },
    );
  }

  Widget _buildVisualsSection() {
    final currentYear = DateTime.now().year;
    final months = List<String>.generate(
      12,
      (index) => _monthKey(DateTime(currentYear, index + 1, 1)),
    );
    final barValues = months
        .map((month) => _data.transactions
            .where((tx) => _monthKey(tx.date) == month)
            .fold<double>(0, (sum, tx) => sum + tx.amount))
        .toList();
    final monthLabels =
        months.map((m) => _monthLabel(m).split(' ').first).toList();

    final categories = _data.categories.keys.toList()..sort();
    final effectiveLineCategory =
        categories.contains(_lineChartCategory) ? _lineChartCategory : 'all';
    final monthOptions = List<String>.generate(
      12,
      (index) => _monthKey(DateTime(currentYear, index + 1, 1)),
    );
    final effectiveLineMonth = monthOptions.contains(_lineChartMonth)
        ? _lineChartMonth
        : _nowMonthKey();

    final monthParts = effectiveLineMonth.split('-');
    final lineYear = int.tryParse(monthParts.first) ?? DateTime.now().year;
    final lineMonth = monthParts.length > 1
        ? int.tryParse(monthParts[1]) ?? DateTime.now().month
        : DateTime.now().month;
    final daysInLineMonth = DateTime(lineYear, lineMonth + 1, 0).day;
    final weekCount = ((daysInLineMonth - 1) ~/ 7) + 1;
    final weekRanges = List<_WeekRange>.generate(weekCount, (index) {
      final weekNumber = index + 1;
      final startDay = (index * 7) + 1;
      final endDay = math.min(startDay + 6, daysInLineMonth);
      final startDate = DateTime(lineYear, lineMonth, startDay);
      final endDate = DateTime(lineYear, lineMonth, endDay);
      return _WeekRange(
        weekNumber: weekNumber,
        startDay: startDay,
        endDay: endDay,
        label:
            'Week $weekNumber: ${DateFormat('MMM d').format(startDate)} - ${DateFormat('d').format(endDate)}',
      );
    });
    final isWholeMonthSelected = _lineChartWeek == 0;
    final effectiveLineWeek =
        weekRanges.any((week) => week.weekNumber == _lineChartWeek)
            ? _lineChartWeek
            : 1;
    final selectedWeek =
        weekRanges.firstWhere((week) => week.weekNumber == effectiveLineWeek);
    final selectedPeriodLabel =
        isWholeMonthSelected ? 'Whole Month' : selectedWeek.label;

    final selectedSeriesNames = effectiveLineCategory == 'all'
        ? categories
        : <String>[effectiveLineCategory];
    final monthTx = _data.transactions
        .where((tx) => _monthKey(tx.date) == effectiveLineMonth)
        .toList();
    final weekTx = monthTx
        .where((tx) =>
            tx.date.day >= selectedWeek.startDay &&
            tx.date.day <= selectedWeek.endDay)
        .toList();
    final selectedPeriodTx = isWholeMonthSelected ? monthTx : weekTx;

    final lineSeries = selectedSeriesNames
        .map((name) {
          final categoryTx = selectedPeriodTx
              .where((tx) => tx.category == name)
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          if (categoryTx.isEmpty) {
            return _LineSeries(name: name, values: const <double>[]);
          }

          return _LineSeries(
            name: name,
            values: categoryTx.map((tx) => tx.amount).toList(),
          );
        })
        .where((series) => series.values.isNotEmpty)
        .toList();

    final maxPointCount = lineSeries.fold<int>(
      0,
      (maxCount, series) => math.max(maxCount, series.values.length),
    );
    final lineLabels = List<String>.generate(
      maxPointCount,
      (index) => (index + 1).toString(),
    );
    final lineColors = lineSeries
        .map(
            (s) => _categoryLineColors[s.name] ?? _categoryLineSeedColors.first)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Visual Overview',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
                'All graphs are grouped here for a quick visual summary.'),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final chartA = _ChartCard(
                  title: 'Yearly Spending (Bar)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$currentYear',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Current Year',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: MonthlyBarChart(
                          values: barValues,
                          labels: monthLabels,
                        ),
                      ),
                    ],
                  ),
                );
                final chartB = _ChartCard(
                  title: 'Spending Trend (Line graph)',
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
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Month',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: effectiveLineMonth,
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _lineChartMonth = value;
                                            _lineChartWeek = 1;
                                          });
                                        }
                                      },
                                      items: monthOptions
                                          .map(
                                            (month) => DropdownMenuItem(
                                              value: month,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_month,
                                                    size: 16,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _monthLabel(month),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.pie_chart_outline,
                                        size: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Category',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: effectiveLineCategory,
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(
                                              () => _lineChartCategory = value);
                                        }
                                      },
                                      items: [
                                        DropdownMenuItem(
                                          value: 'all',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.auto_graph,
                                                size: 16,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                              const SizedBox(width: 8),
                                              const Expanded(
                                                child: Text(
                                                  'All Categories',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ...categories.map(
                                          (name) => DropdownMenuItem(
                                            value: name,
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: _categoryLineColors[
                                                            name] ??
                                                        _categoryLineSeedColors
                                                            .first,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(name,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: PopupMenuButton<String>(
                          onSelected: (value) {
                            setState(() {
                              _lineChartWeek =
                                  value == 'all' ? 0 : int.parse(value);
                            });
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'all',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_month_outlined,
                                    size: 16,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Whole Month',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...weekRanges.map(
                              (week) => PopupMenuItem<String>(
                                value: week.weekNumber.toString(),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_view_week_outlined,
                                      size: 16,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(week.label,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .shadow
                                      .withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isWholeMonthSelected
                                      ? Icons.calendar_month_outlined
                                      : Icons.calendar_view_week_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(selectedPeriodLabel),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: MonthlyLineChart(
                            series: lineSeries,
                            labels: lineLabels,
                            lineColors: lineColors,
                          ),
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
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: valueColor)),
            const SizedBox(height: 4),
            Text(note),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.title,
    required this.value,
    this.valueColor,
  });

  final String title;
  final String value;
  final Color? valueColor;

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
          Text(title,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: valueColor ?? scheme.onSurface),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.icon,
    required this.step,
    required this.title,
    required this.body,
  });

  final IconData icon;
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
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  step,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
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
  const _ChartCard({
    required this.title,
    required this.child,
    this.footer,
  });

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
          SizedBox(height: 300, child: child),
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

  @override
  bool operator ==(covariant _LineSeries other) {
    if (identical(this, other)) return true;
    return other.name == name &&
        other.values.length == values.length &&
        _listEquals(other.values, values);
  }

  @override
  int get hashCode => Object.hash(name, Object.hashAll(values));

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _WeekRange {
  const _WeekRange({
    required this.weekNumber,
    required this.startDay,
    required this.endDay,
    required this.label,
  });

  final int weekNumber;
  final int startDay;
  final int endDay;
  final String label;
}

class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart(
      {super.key, required this.values, required this.labels});

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
    const padLeft = 40.0;
    const padRight = 16.0;
    const padTop = 14.0;
    const padBottom = 30.0;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;
    final maxValue = values.fold<double>(1, (m, v) => math.max(m, v));
    const yStep = 1000.0;
    final yMax = math.max(3000.0, (maxValue / yStep).ceil() * yStep);

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

    for (var tick = yStep; tick <= yMax; tick += yStep) {
      final y = padTop + chartH - ((tick / yMax) * chartH);
      canvas.drawLine(
          Offset(padLeft, y), Offset(size.width - padRight, y), gridPaint);
      final valuePainter = TextPainter(
        text: TextSpan(
            text: tick.toInt().toString(),
            style: TextStyle(color: valueColor, fontSize: 10)),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: padLeft - 12);
      valuePainter.paint(
          canvas,
          Offset(
              padLeft - valuePainter.width - 6, y - (valuePainter.height / 2)));
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
      painter.paint(
          canvas, Offset(x - ((painter.width - barW) / 2), size.height - 16));
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
      return const Center(
          child: Text('No spending data for selected category.'));
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

    const padLeft = 40.0;
    const padRight = 16.0;
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
    const yStep = 250.0;
    final yMax = math.max(yStep, (maxValue / yStep).ceil() * yStep);

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

    for (var tick = yStep; tick <= yMax; tick += yStep) {
      final y = padTop + chartH - ((tick / yMax) * chartH);
      canvas.drawLine(
          Offset(padLeft, y), Offset(size.width - padRight, y), gridPaint);
      final valuePainter = TextPainter(
        text: TextSpan(
            text: tick.toInt().toString(),
            style: TextStyle(color: valueColor, fontSize: 10)),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: padLeft - 12);
      valuePainter.paint(
          canvas,
          Offset(
              padLeft - valuePainter.width - 6, y - (valuePainter.height / 2)));
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
      final pointFillPaint = Paint()
        ..color = lineColors[lineIndex % lineColors.length]
        ..style = PaintingStyle.fill;
      final pointStrokePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      final points = <Offset>[];
      final pointCount = line.values.length;
      for (var i = 0; i < pointCount; i++) {
        final value = line.values[i];
        final x = padLeft + (count > 1 ? i * xStep : chartW / 2);
        final h = yMax > 0 ? (value / yMax) * chartH : 0.0;
        final y = padTop + chartH - h;
        points.add(Offset(x, y));
      }

      if (points.isNotEmpty) {
        if (points.length == 1) {
          final only = points.first;
          final stemPath = Path()
            ..moveTo(only.dx, padTop + chartH)
            ..lineTo(only.dx, only.dy);
          canvas.drawPath(stemPath, linePaint);
        } else {
          final path = Path()..moveTo(points.first.dx, points.first.dy);
          for (var i = 1; i < points.length; i++) {
            path.lineTo(points[i].dx, points[i].dy);
          }
          canvas.drawPath(path, linePaint);
        }
      }

      for (final point in points) {
        canvas.drawCircle(point, 3.2, pointFillPaint);
        canvas.drawCircle(point, 3.2, pointStrokePaint);
      }
    }

    for (var i = 0; i < labels.length; i++) {
      final x = padLeft + (count > 1 ? i * xStep : chartW / 2);
      final painter = TextPainter(
        text: TextSpan(
            text: labels[i], style: TextStyle(color: labelColor, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 42);
      painter.paint(canvas, Offset(x - painter.width / 2, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyLinePainter oldDelegate) {
    if (oldDelegate.series.length != series.length ||
        oldDelegate.labels.length != labels.length) {
      return true;
    }
    for (int i = 0; i < series.length; i++) {
      if (oldDelegate.series[i] != series[i]) {
        return true;
      }
    }
    for (int i = 0; i < labels.length; i++) {
      if (oldDelegate.labels[i] != labels[i]) {
        return true;
      }
    }
    return false;
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
    final monthTx = data.transactions
        .where((tx) => DateFormat('yyyy-MM').format(tx.date) == monthKey)
        .toList();
    final monthAllowance = data.allowanceForMonth(now.year, now.month);

    final spent = monthTx.fold<double>(0, (sum, tx) => sum + tx.amount);
    final remaining = monthAllowance - spent;
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
        .where((tx) =>
            tx.date.isAfter(weekStart) || tx.date.isAtSameMomentAs(weekStart))
        .fold<double>(0, (sum, tx) => sum + tx.amount);

    final largest =
        monthTx.fold<double>(0, (max, tx) => math.max(max, tx.amount));

    final percentUsed =
        monthAllowance > 0 ? (spent / monthAllowance) * 100 : 0.0;

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
    required this.monthAllowances,
    required this.categories,
    required this.transactions,
  });

  double monthlyAllowance;
  Map<String, double> monthAllowances;
  Map<String, double> categories;
  List<ExpenseTx> transactions;

  double allowanceForMonth(int year, int month) {
    final key = '$year-${month.toString().padLeft(2, '0')}';
    final fromMap = monthAllowances[key];
    if (fromMap != null && fromMap > 0) {
      return fromMap;
    }

    final now = DateTime.now();
    if (year == now.year && month == now.month && monthlyAllowance > 0) {
      return monthlyAllowance;
    }

    return 0;
  }

  String toJson() {
    final map = {
      'monthlyAllowance': monthlyAllowance,
      'monthAllowances': monthAllowances,
      'categories': categories,
      'transactions': transactions.map((t) => t.toMap()).toList(),
    };
    return jsonEncode(map);
  }

  factory BudgetData.fromJson(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final categoriesRaw = map['categories'] as Map<String, dynamic>? ?? {};
      final monthAllowancesRaw =
          map['monthAllowances'] as Map<String, dynamic>? ?? {};
      final txRaw = map['transactions'] as List<dynamic>? ?? [];
      final categories = <String, double>{};
      final monthAllowances = <String, double>{};
      categoriesRaw.forEach((key, value) {
        final amount = (value as num?)?.toDouble();
        if (amount != null && amount > 0) {
          categories[key] = amount;
        }
      });
      monthAllowancesRaw.forEach((key, value) {
        final amount = (value as num?)?.toDouble();
        if (amount != null && amount > 0) {
          monthAllowances[key] = amount;
        }
      });
      return BudgetData(
        monthlyAllowance: ((map['monthlyAllowance'] as num?)?.toDouble() ?? 0),
        monthAllowances: monthAllowances,
        categories: categories,
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
      monthlyAllowance: 0,
      monthAllowances: {},
      categories: {},
      transactions: [],
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
    required this.isDarkMode,
    required this.onToggleDarkMode,
    required this.currencyCode,
    required this.currencySymbols,
    required this.onCurrencyChanged,
    required this.onLogout,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;
  final String currencyCode;
  final Map<String, String> currencySymbols;
  final ValueChanged<String> onCurrencyChanged;
  final Future<void> Function() onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _selectedCurrency;
  late bool _isDarkMode;
  static const Map<String, String> _currencyNames = {
    'PHP': 'Philippine Peso',
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'JPY': 'Japanese Yen',
    'AUD': 'Australian Dollar',
    'CAD': 'Canadian Dollar',
    'INR': 'Indian Rupee',
    'SGD': 'Singapore Dollar',
  };
  static const Map<String, String> _countryCodes = {
    'PHP': 'PH',
    'USD': 'US',
    'EUR': 'EU',
    'GBP': 'GB',
    'JPY': 'JP',
    'AUD': 'AU',
    'CAD': 'CA',
    'INR': 'IN',
    'SGD': 'SG',
  };

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.currencyCode;
    _isDarkMode = widget.isDarkMode;
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currencyCode != widget.currencyCode) {
      _selectedCurrency = widget.currencyCode;
    }
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _isDarkMode = widget.isDarkMode;
    }
  }

  Future<void> _openCurrencyPicker() async {
    final options = widget.currencySymbols.entries
        .where((entry) =>
            _currencyNames.containsKey(entry.key) &&
            _countryCodes.containsKey(entry.key))
        .map(
          (entry) => _CurrencyOption(
            code: entry.key,
            symbol: entry.value.trim(),
            name: _currencyNames[entry.key] ?? entry.key,
            countryCode: _countryCodes[entry.key] ?? entry.key,
          ),
        )
        .toList();

    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return _CurrencyPickerDialog(
          options: options,
          initialCode: _selectedCurrency,
        );
      },
    );

    if (selected == null || selected == _selectedCurrency) {
      return;
    }

    setState(() => _selectedCurrency = selected);
    widget.onCurrencyChanged(selected);
  }

  Future<void> _openPrivacySettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ChangePasswordPage()),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(ColorScheme scheme, TextTheme textTheme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.68),
              scheme.surfaceContainerHighest.withValues(alpha: 0.9),
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(
                Icons.settings_outlined,
                color: scheme.primary,
                size: 34,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Adjust your app experience, security, and currency in one place.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPillBadge(
                        label: _selectedCurrency,
                        color: scheme.primary,
                        background: scheme.primary.withValues(alpha: 0.1),
                      ),
                      _buildPillBadge(
                        label: _isDarkMode ? 'Dark mode on' : 'Light mode on',
                        color: scheme.onSurface,
                        background: scheme.surface.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillBadge({
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.10),
              scheme.surface,
              scheme.secondary.withValues(alpha: 0.07),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _buildHeroCard(scheme, textTheme),
            const SizedBox(height: 14),
            _buildSectionTitle(
              'Preferences',
              'Tune appearance and currency for the app.',
            ),
            Card(
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.currency_exchange,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                title: const Text('Currency'),
                subtitle: const Text('Select how amounts are displayed'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCurrency,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: _openCurrencyPicker,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile.adaptive(
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() => _isDarkMode = value);
                  widget.onToggleDarkMode(value);
                },
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isDarkMode
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                title: const Text('Dark mode'),
                subtitle: const Text('Switch app appearance'),
              ),
            ),
            const SizedBox(height: 14),
            _buildSectionTitle(
              'Account',
              'Manage security and sign out safely.',
            ),
            Card(
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                title: const Text('Privacy'),
                subtitle:
                    const Text('Change your password and account security'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openPrivacySettings,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(Icons.logout, color: Colors.red.shade700),
                title: const Text('Log Out'),
                subtitle: const Text('Sign out of this account'),
                onTap: () async {
                  await widget.onLogout();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyOption {
  const _CurrencyOption({
    required this.code,
    required this.name,
    required this.symbol,
    required this.countryCode,
  });

  final String code;
  final String name;
  final String symbol;
  final String countryCode;
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isVerifying = false;
  bool _isSaving = false;
  bool _verifiedCurrentPassword = false;

  bool get _hasMinLength => _newPasswordController.text.length >= 8;
  bool get _hasUppercase =>
      RegExp(r'[A-Z]').hasMatch(_newPasswordController.text);
  bool get _hasLowercase =>
      RegExp(r'[a-z]').hasMatch(_newPasswordController.text);
  bool get _hasNumber => RegExp(r'\d').hasMatch(_newPasswordController.text);
  bool get _hasSpecial =>
      RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\\/\[\]+=~`]').hasMatch(
        _newPasswordController.text,
      );
  bool get _passwordsMatch =>
      _confirmPasswordController.text.isNotEmpty &&
      _newPasswordController.text == _confirmPasswordController.text;

  bool get _isPolicySatisfied =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSpecial;

  int get _policyScore {
    var score = 0;
    if (_hasMinLength) score++;
    if (_hasUppercase) score++;
    if (_hasLowercase) score++;
    if (_hasNumber) score++;
    if (_hasSpecial) score++;
    return score;
  }

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onPasswordInputChanged);
    _confirmPasswordController.addListener(_onPasswordInputChanged);
  }

  void _onPasswordInputChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onPasswordInputChanged);
    _confirmPasswordController.removeListener(_onPasswordInputChanged);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _showAlert({
    required String title,
    required String message,
    bool success = false,
  }) async {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final accentColor = success ? scheme.primary : scheme.error;
    final iconData =
        success ? Icons.check_rounded : Icons.warning_amber_rounded;
    final iconBackground = success
        ? scheme.primaryContainer.withValues(alpha: 0.92)
        : scheme.errorContainer.withValues(alpha: 0.92);
    final iconForeground =
        success ? scheme.onPrimaryContainer : scheme.onErrorContainer;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBackground,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.28),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(iconData, color: iconForeground, size: 40),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor:
                        success ? scheme.onPrimary : scheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _didPasswordActuallyChange(String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (email == null || email.isEmpty) {
      return false;
    }
    try {
      await AuthService.signInWithEmail(email: email, password: newPassword);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _verifyCurrentPassword() async {
    final currentPassword = _currentPasswordController.text;
    if (currentPassword.isEmpty) {
      await _showAlert(
          title: 'Missing Password', message: 'Enter your current password.');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await AuthService.verifyCurrentPassword(currentPassword: currentPassword);
      if (!mounted) return;
      setState(() => _verifiedCurrentPassword = true);
      await _showAlert(
          title: 'Verified',
          message: 'Current password verified.',
          success: true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message =
          (e.code == 'wrong-password' || e.code == 'invalid-credential')
              ? 'Password incorrect.'
              : 'Verification failed.';
      await _showAlert(title: 'Verification Failed', message: message);
    } catch (e) {
      if (!mounted) return;
      await _showAlert(
        title: 'Verification Failed',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _saveNewPassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (!_isPolicySatisfied) {
      await _showAlert(
        title: 'Password Requirements',
        message:
            'Use at least 8 characters with uppercase, lowercase, number, and special character.',
      );
      return;
    }

    if (newPassword != confirmPassword) {
      await _showAlert(title: 'Mismatch', message: 'Passwords do not match.');
      return;
    }

    if (currentPassword.isNotEmpty && newPassword == currentPassword) {
      await _showAlert(
        title: 'Use a Different Password',
        message:
            'Your new password must be different from your current password.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await AuthService.updateCurrentUserPassword(newPassword: newPassword);
      if (!mounted) return;
      await _showAlert(
          title: 'Success',
          message: 'Password changed successfully.',
          success: true);
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final isKnownPluginCastIssue = raw.contains('PigeonUserDetails') ||
          raw.contains("List<Object> is not a subtype");
      if (isKnownPluginCastIssue) {
        await _showAlert(
            title: 'Success',
            message: 'Password changed successfully.',
            success: true);
        Navigator.of(context).pop();
        return;
      }

      if (await _didPasswordActuallyChange(newPassword)) {
        if (!mounted) return;
        await _showAlert(
            title: 'Success',
            message: 'Password changed successfully.',
            success: true);
        Navigator.of(context).pop();
        return;
      }

      final message = e.code == 'requires-recent-login'
          ? 'Session expired. Re-verify password.'
          : 'Password change failed.';
      await _showAlert(title: 'Update Failed', message: message);
      if (e.code == 'requires-recent-login') {
        setState(() => _verifiedCurrentPassword = false);
      }
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final isKnownPluginCastIssue = raw.contains('PigeonUserDetails') ||
          raw.contains("List<Object> is not a subtype");
      if (isKnownPluginCastIssue) {
        await _showAlert(
            title: 'Success',
            message: 'Password changed successfully.',
            success: true);
        Navigator.of(context).pop();
        return;
      }

      if (await _didPasswordActuallyChange(newPassword)) {
        if (!mounted) return;
        await _showAlert(
            title: 'Success',
            message: 'Password changed successfully.',
            success: true);
        Navigator.of(context).pop();
        return;
      }

      await _showAlert(
          title: 'Update Failed', message: 'Password change failed.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildPolicyItem(
    BuildContext context, {
    required bool passed,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final activeColor = passed ? const Color(0xFF15803D) : scheme.outline;
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: activeColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: passed ? const Color(0xFF166534) : scheme.onSurface,
                  fontWeight: passed ? FontWeight.w600 : FontWeight.w400,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.95),
            scheme.tertiaryContainer.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_moon_outlined, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Password Update',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _verifiedCurrentPassword
                      ? 'Step 2 of 2: Create a strong new password'
                      : 'Step 1 of 2: Verify your current password first',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyCurrentCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verify current password',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'For your security, enter your existing password before creating a new one.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _currentPasswordController,
            obscureText: !_showCurrentPassword,
            enabled: !_isVerifying,
            decoration: InputDecoration(
              labelText: 'Current password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: _isVerifying
                    ? null
                    : () => setState(
                        () => _showCurrentPassword = !_showCurrentPassword),
                icon: Icon(
                  _showCurrentPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isVerifying ? null : _verifyCurrentPassword,
              icon: _isVerifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: Text(
                _isVerifying ? 'Verifying...' : 'Verify current password',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateNewPasswordCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strengthLabel = _policyScore <= 2
        ? 'Weak'
        : _policyScore == 3
            ? 'Fair'
            : _policyScore == 4
                ? 'Strong'
                : 'Excellent';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create new password',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a password that is different from your current one.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _newPasswordController,
            obscureText: !_showNewPassword,
            enabled: !_isSaving,
            decoration: InputDecoration(
              labelText: 'New password',
              helperText: 'Use 8+ chars with upper, lower, number, and symbol.',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                onPressed: _isSaving
                    ? null
                    : () =>
                        setState(() => _showNewPassword = !_showNewPassword),
                icon: Icon(
                  _showNewPassword ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            enabled: !_isSaving,
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              helperText: _confirmPasswordController.text.isEmpty
                  ? 'Re-enter your new password.'
                  : (_passwordsMatch
                      ? 'Passwords match.'
                      : 'Passwords do not match.'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: _isSaving
                    ? null
                    : () => setState(
                          () => _showConfirmPassword = !_showConfirmPassword,
                        ),
                icon: Icon(
                  _showConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Password strength',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      strengthLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _policyScore / 5,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 12),
                _buildPolicyItem(
                  context,
                  passed: _hasMinLength,
                  label: 'At least 8 characters',
                ),
                const SizedBox(height: 6),
                _buildPolicyItem(
                  context,
                  passed: _hasUppercase,
                  label: 'At least one uppercase letter',
                ),
                const SizedBox(height: 6),
                _buildPolicyItem(
                  context,
                  passed: _hasLowercase,
                  label: 'At least one lowercase letter',
                ),
                const SizedBox(height: 6),
                _buildPolicyItem(
                  context,
                  passed: _hasNumber,
                  label: 'At least one number',
                ),
                const SizedBox(height: 6),
                _buildPolicyItem(
                  context,
                  passed: _hasSpecial,
                  label: 'At least one special character',
                ),
                const SizedBox(height: 6),
                _buildPolicyItem(
                  context,
                  passed: _passwordsMatch,
                  label: 'Confirm password matches',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveNewPassword,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Save new password'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _isSaving
                  ? null
                  : () => setState(() {
                        _verifiedCurrentPassword = false;
                        _newPasswordController.clear();
                        _confirmPasswordController.clear();
                      }),
              child: const Text('Use a different current password'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.surface,
              scheme.surfaceContainerLowest.withValues(alpha: 0.6),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSecurityBanner(context),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _verifiedCurrentPassword
                  ? _buildCreateNewPasswordCard(context)
                  : _buildVerifyCurrentCard(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyPickerDialog extends StatefulWidget {
  const _CurrencyPickerDialog({
    required this.options,
    required this.initialCode,
  });

  final List<_CurrencyOption> options;
  final String initialCode;

  @override
  State<_CurrencyPickerDialog> createState() => _CurrencyPickerDialogState();
}

class _CurrencyPickerDialogState extends State<_CurrencyPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = _query.trim().toLowerCase();
    final filtered = widget.options.where((option) {
      if (normalized.isEmpty) {
        return true;
      }
      return option.code.toLowerCase().contains(normalized) ||
          option.name.toLowerCase().contains(normalized) ||
          option.symbol.toLowerCase().contains(normalized);
    }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(34, 34),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Choose a currency',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search',
                  filled: true,
                  fillColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.5)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No currencies match your search.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          color: scheme.outlineVariant.withValues(alpha: 0.45),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final option = filtered[index];
                          final selected = option.code == widget.initialCode;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: scheme.surfaceContainerHighest,
                              child: ClipOval(
                                child: CountryFlag.fromCountryCode(
                                  option.countryCode,
                                ),
                              ),
                            ),
                            title: Text(
                              option.code,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(option.name),
                            trailing: selected
                                ? const Icon(
                                    Icons.check,
                                    color: Color(0xFF1A7A59),
                                  )
                                : null,
                            onTap: () => Navigator.of(context).pop(option.code),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
