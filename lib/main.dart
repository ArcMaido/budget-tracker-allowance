import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:country_flags/country_flags.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_styles.dart';
import 'auth_service.dart';
import 'data_service.dart';
import 'firebase_service.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
  void initState() {
    super.initState();
    _loadDarkMode();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  Future<void> _setDarkMode(bool enabled) async {
    setState(() => _darkMode = enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', enabled);
  }

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
      themeAnimationDuration: const Duration(milliseconds: 280),
      themeAnimationCurve: Curves.easeInOutCubic,
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
      home: _buildAuthFlow(),
    );
  }

  Widget _buildAuthFlow() {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges(),
      initialData: AuthService.currentUser,
      builder: (context, snapshot) {
        final activeUser = snapshot.data ?? AuthService.currentUser;

        if (activeUser == null) {
          return LoginPage(
            isDarkMode: _darkMode,
            onToggleDarkMode: _setDarkMode,
            onSignedIn: () {
              if (mounted) {
                setState(() {});
              }
            },
          );
        }

        return UserAuthWrapper(
          isDarkMode: _darkMode,
          onToggleDarkMode: _setDarkMode,
        );
      },
    );
  }
}

class UserAuthWrapper extends StatefulWidget {
  const UserAuthWrapper({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;

  @override
  State<UserAuthWrapper> createState() => _UserAuthWrapperState();
}

class _UserAuthWrapperState extends State<UserAuthWrapper> {
  bool _showOnboarding = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Add a small delay to ensure Firestore writes are synced
        await Future.delayed(const Duration(milliseconds: 500));
        final isNewUser = await AuthService.isNewUser();
        if (mounted) {
          setState(() {
            _showOnboarding = isNewUser;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _completeOnboarding() {
    AuthService.completeOnboarding();
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showOnboarding) {
      return OnboardingPage(
        onComplete: _completeOnboarding,
      );
    }

    return AllowanceBudgetHome(
      isDarkMode: widget.isDarkMode,
      onToggleDarkMode: widget.onToggleDarkMode,
    );
  }
}

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
  final int _historyRowsPerPage = 10;
  int _historyPage = 0;
  bool _monthlyShowAllowance = true;
  bool _monthlyShowSpent = true;
  bool _monthlyShowSaved = true;
  bool _monthlyShowRate = true;
  int _selectedNavIndex = 0;
  String _currencyCode = 'PHP';
  String? _profilePhotoUrl;

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
    _loadProfilePreview();
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

      // One-time cleanup: remove old shared key so users do not inherit
      // previous account data from older app versions.
      if (prefs.containsKey(_legacyStorageKey)) {
        await prefs.remove(_legacyStorageKey);
      }

      setState(() {
        _data = raw == null ? BudgetData.defaultState() : BudgetData.fromJson(raw);
        _syncCategoryLineColors();
        _allowanceController.text = _data.monthlyAllowance.toStringAsFixed(0);
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

  Future<void> _loadProfilePreview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _profilePhotoUrl = null);
      }
      return;
    }

    try {
      final profile = await FirebaseService.getUserProfile(user.uid)
          .timeout(const Duration(seconds: 20), onTimeout: () => null);
      final fromFirestore = (profile?['photoUrl'] as String?)?.trim();
      final nextPhoto =
          (fromFirestore != null && fromFirestore.isNotEmpty) ? fromFirestore : user.photoURL;
      if (!mounted) return;
      setState(() => _profilePhotoUrl = nextPhoto);
    } catch (_) {
      if (!mounted) return;
      setState(() => _profilePhotoUrl = user.photoURL);
    }
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
    await prefs.setString(_scopedStorageKey(), _data.toJson());

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        for (final tx in _data.transactions) {
          await DataService.saveTransaction(
            category: tx.category,
            amount: tx.amount,
            date: tx.date,
            description: tx.title,
          );
        }
        for (final category in _data.categories.entries) {
          await DataService.saveCategory(
            categoryName: category.key,
            budget: category.value,
          );
        }
        await DataService.setMonthlyAllowance(_data.monthlyAllowance);
      }
    } catch (e) {
      debugPrint('Firebase sync error: $e');
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
    return NumberFormat.currency(symbol: symbol, decimalDigits: 0).format(value);
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

  Future<void> _openProfilePage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProfilePage(),
      ),
    );
    await _loadProfilePreview();
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
      ),
      tooltip: 'Settings',
    );
  }

  Widget _buildProfileButton() {
    final hasPhoto = _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty;
    return IconButton(
      onPressed: _openProfilePage,
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.white.withOpacity(0.2),
        backgroundImage: hasPhoto ? NetworkImage(_profilePhotoUrl!) : null,
        child: hasPhoto
            ? null
            : const Icon(
                Icons.person_outline,
                size: 18,
                color: Colors.white,
              ),
      ),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF1A7A59),
        foregroundColor: Colors.white,
      ),
      tooltip: 'Profile',
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
                'Coinzy',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              _buildSettingsButton(),
              const SizedBox(width: 8),
              _buildProfileButton(),
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
                  child: MonthlyLineChart(series: lineSeries, labels: labels, lineColors: lineColors),
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

      if (points.isNotEmpty) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (var i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        canvas.drawPath(path, linePaint);
      }
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
        monthlyAllowance: ((map['monthlyAllowance'] as num?)?.toDouble() ?? 0),
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
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currencyCode != widget.currencyCode) {
      _selectedCurrency = widget.currencyCode;
    }
  }

  Future<void> _openCurrencyPicker() async {
    final options = widget.currencySymbols.entries
        .where((entry) =>
            _currencyNames.containsKey(entry.key) && _countryCodes.containsKey(entry.key))
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
              value: widget.isDarkMode,
              onChanged: widget.onToggleDarkMode,
              title: const Text('Dark mode'),
              subtitle: const Text('Switch app appearance'),
            ),
          ),
          const SizedBox(height: 8),
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
              subtitle: const Text('Change your password and account security'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openPrivacySettings,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
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

  @override
  void dispose() {
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.info_outline,
              color: success ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
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
      await _showAlert(title: 'Missing Password', message: 'Enter your current password.');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await AuthService.verifyCurrentPassword(currentPassword: currentPassword);
      if (!mounted) return;
      setState(() => _verifiedCurrentPassword = true);
      await _showAlert(title: 'Verified', message: 'Current password verified.', success: true);
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
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < 6) {
      await _showAlert(title: 'Weak Password', message: 'Password must be at least 6 characters.');
      return;
    }

    if (newPassword != confirmPassword) {
      await _showAlert(title: 'Mismatch', message: 'Passwords do not match.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await AuthService.updateCurrentUserPassword(newPassword: newPassword);
      if (!mounted) return;
      await _showAlert(title: 'Success', message: 'Password changed successfully.', success: true);
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final isKnownPluginCastIssue =
          raw.contains('PigeonUserDetails') ||
          raw.contains("List<Object> is not a subtype");
      if (isKnownPluginCastIssue) {
        await _showAlert(title: 'Success', message: 'Password changed successfully.', success: true);
        Navigator.of(context).pop();
        return;
      }

      if (await _didPasswordActuallyChange(newPassword)) {
        if (!mounted) return;
        await _showAlert(title: 'Success', message: 'Password changed successfully.', success: true);
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
      final isKnownPluginCastIssue =
          raw.contains('PigeonUserDetails') ||
          raw.contains("List<Object> is not a subtype");
      if (isKnownPluginCastIssue) {
        await _showAlert(title: 'Success', message: 'Password changed successfully.', success: true);
        Navigator.of(context).pop();
        return;
      }

      if (await _didPasswordActuallyChange(newPassword)) {
        if (!mounted) return;
        await _showAlert(title: 'Success', message: 'Password changed successfully.', success: true);
        Navigator.of(context).pop();
        return;
      }

      await _showAlert(title: 'Update Failed', message: 'Password change failed.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _verifiedCurrentPassword
                        ? 'Step 2: Enter your new password'
                        : 'Step 1: Verify your current password',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_verifiedCurrentPassword) ...[
                    const Text('Enter your old password to continue.'),
                    const SizedBox(height: 12),
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
                                  () => _showCurrentPassword = !_showCurrentPassword,
                                ),
                          icon: Icon(
                            _showCurrentPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _isVerifying ? null : _verifyCurrentPassword,
                      icon: _isVerifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_user_outlined),
                      label: Text(_isVerifying ? 'Verifying...' : 'Verify current password'),
                    ),
                  ] else ...[
                    const Text('Now enter and confirm your new password.'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: !_showNewPassword,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          onPressed: _isSaving
                              ? null
                              : () => setState(() => _showNewPassword = !_showNewPassword),
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
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: _isSaving
                              ? null
                              : () =>
                                  setState(() => _showConfirmPassword = !_showConfirmPassword),
                          icon: Icon(
                            _showConfirmPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
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
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => setState(() {
                                _verifiedCurrentPassword = false;
                                _newPasswordController.clear();
                                _confirmPasswordController.clear();
                              }),
                      child: const Text('Use a different current password'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
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
                    borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
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
                              style: const TextStyle(fontWeight: FontWeight.w700),
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _picker = ImagePicker();

  String? _photoUrl;
  String? _coverPhotoUrl;
  Uint8List? _pendingPhotoBytes;
  Uint8List? _pendingCoverBytes;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _uploadingCover = false;
  bool _isEditing = false;
  bool _profileResolved = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 12), () {
      if (!mounted || _profileResolved) {
        return;
      }
      _applyLocalProfileFallback();
    });
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  void _applyLocalProfileFallback() {
    final user = FirebaseAuth.instance.currentUser;
    final fallbackName =
        ((user?.displayName ?? '').trim().isNotEmpty) ? user!.displayName!.trim() : 'User';
    if (!mounted) return;
    setState(() {
      _nameController.text = fallbackName;
      _roleController.text = 'Student';
      _photoUrl = user?.photoURL;
      _coverPhotoUrl = null;
      _pendingPhotoBytes = null;
      _pendingCoverBytes = null;
      _loading = false;
      _profileResolved = true;
    });
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final profile = await FirebaseService.getUserProfile(user.uid)
          .timeout(const Duration(seconds: 10), onTimeout: () => null)
          .catchError((_) => null);
      final fullName = (profile?['fullName'] as String?)?.trim();
      final role = (profile?['role'] as String?)?.trim();
      final photoUrl = (profile?['photoUrl'] as String?)?.trim();
      final coverPhotoUrl = (profile?['coverPhotoUrl'] as String?)?.trim();

      final resolvedName =
          (fullName != null && fullName.isNotEmpty)
              ? fullName
              : ((user.displayName ?? '').trim().isNotEmpty
                  ? user.displayName!.trim()
              : (((user.email ?? '').trim().isNotEmpty)
                ? user.email!.trim().split('@').first
                : 'User'));
      final resolvedPhotoUrl =
          (photoUrl != null && photoUrl.isNotEmpty) ? photoUrl : user.photoURL;

      if ((fullName == null || fullName.isEmpty) ||
          (photoUrl == null || photoUrl.isEmpty)) {
        final userData = <String, dynamic>{
          'fullName': resolvedName,
          'email': (user.email ?? '').trim().toLowerCase(),
          'emailLower': (user.email ?? '').trim().toLowerCase(),
          'lastUpdated': DateTime.now(),
        };
        if (resolvedPhotoUrl != null && resolvedPhotoUrl.trim().isNotEmpty) {
          userData['photoUrl'] = resolvedPhotoUrl;
        }
        try {
          await FirebaseService.saveUserProfile(
            userId: user.uid,
            userData: userData,
          ).timeout(const Duration(seconds: 8), onTimeout: () => null);
        } catch (_) {
          // Do not block profile rendering on a best-effort profile sync.
        }
      }

      if (!mounted) return;
      setState(() {
        _nameController.text = resolvedName;
        _roleController.text =
            (role != null && role.isNotEmpty) ? role : 'Student';
        _photoUrl = resolvedPhotoUrl;
        _coverPhotoUrl =
            (coverPhotoUrl != null && coverPhotoUrl.isNotEmpty)
                ? coverPhotoUrl
                : null;
        _pendingPhotoBytes = null;
        _pendingCoverBytes = null;
        _loading = false;
        _profileResolved = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nameController.text =
            (user.displayName ?? '').trim().isNotEmpty
                ? user.displayName!.trim()
                : 'User';
        _roleController.text = 'Student';
        _photoUrl = user.photoURL;
        _coverPhotoUrl = null;
        _pendingPhotoBytes = null;
        _pendingCoverBytes = null;
        _loading = false;
        _profileResolved = true;
      });
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final previousPhotoUrl = _photoUrl;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 65,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (picked == null) {
      return;
    }

    final previewBytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      _pendingPhotoBytes = previewBytes;
      _uploadingPhoto = true;
    });
    var uploaded = false;
    try {
      final url = await FirebaseService.uploadProfileImageBytes(
        userId: user.uid,
        bytes: previewBytes,
      );

      if (url == null || url.isEmpty) {
        if (mounted) {
          setState(() {
            _pendingPhotoBytes = null;
            _photoUrl = previousPhotoUrl;
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo upload failed. Try again.')),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _photoUrl = url;
          _pendingPhotoBytes = null;
          _uploadingPhoto = false;
        });
      }
      uploaded = true;
      final resolvedName = _nameController.text.trim().isEmpty
          ? (((user.displayName ?? '').trim().isNotEmpty)
              ? user.displayName!.trim()
            : 'User')
          : _nameController.text.trim();
      final resolvedRole = _roleController.text.trim().isEmpty
          ? 'Student'
          : _roleController.text.trim();
      await AuthService.updateUserProfile(
        fullName: resolvedName,
        photoUrl: url,
      ).timeout(const Duration(seconds: 12), onTimeout: () {});
      final userData = <String, dynamic>{
        'fullName': resolvedName,
        'role': resolvedRole,
        'photoUrl': url,
        'lastUpdated': DateTime.now(),
      };
      if (_coverPhotoUrl != null && _coverPhotoUrl!.trim().isNotEmpty) {
        userData['coverPhotoUrl'] = _coverPhotoUrl;
      }
      await FirebaseService.saveUserProfile(
        userId: user.uid,
        userData: userData,
      ).timeout(const Duration(seconds: 12), onTimeout: () {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (!uploaded) {
        setState(() {
          _pendingPhotoBytes = null;
          _photoUrl = previousPhotoUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo upload failed. Please try again.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo uploaded. Sync in progress.'),
          ),
        );
      }
    } finally {
      if (mounted && _uploadingPhoto) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final fullName = _nameController.text.trim();
    final role = _roleController.text.trim();
    if (fullName.isEmpty || role.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter name and role.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await AuthService.updateUserProfile(
        fullName: fullName,
        photoUrl: _photoUrl,
      );
      final userData = <String, dynamic>{
        'fullName': fullName,
        'role': role,
        'lastUpdated': DateTime.now(),
      };
      if (_photoUrl != null && _photoUrl!.trim().isNotEmpty) {
        userData['photoUrl'] = _photoUrl;
      }
      if (_coverPhotoUrl != null && _coverPhotoUrl!.trim().isNotEmpty) {
        userData['coverPhotoUrl'] = _coverPhotoUrl;
      }
      await FirebaseService.saveUserProfile(
        userId: user.uid,
        userData: userData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
        setState(() => _isEditing = false);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  ImageProvider<Object>? _photoProvider() {
    if (_pendingPhotoBytes != null && _pendingPhotoBytes!.isNotEmpty) {
      return MemoryImage(_pendingPhotoBytes!);
    }
    if (_photoUrl == null || _photoUrl!.isEmpty) {
      return null;
    }
    return NetworkImage(_photoUrl!);
  }

  ImageProvider<Object>? _coverProvider() {
    if (_pendingCoverBytes != null && _pendingCoverBytes!.isNotEmpty) {
      return MemoryImage(_pendingCoverBytes!);
    }
    if (_coverPhotoUrl == null || _coverPhotoUrl!.isEmpty) {
      return null;
    }
    return NetworkImage(_coverPhotoUrl!);
  }

  Future<void> _pickAndUploadCoverPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final previousCoverUrl = _coverPhotoUrl;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1400,
      maxHeight: 1400,
    );
    if (picked == null) return;

    final previewBytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      _pendingCoverBytes = previewBytes;
      _uploadingCover = true;
    });
    var uploaded = false;

    try {
      final url = await FirebaseService.uploadCoverImageBytes(
        userId: user.uid,
        bytes: previewBytes,
      );

      if (url == null || url.isEmpty) {
        setState(() {
          _pendingCoverBytes = null;
          _coverPhotoUrl = previousCoverUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background upload failed.')),
        );
        return;
      }

      setState(() {
        _coverPhotoUrl = url;
        _pendingCoverBytes = null;
        _uploadingCover = false;
      });
      uploaded = true;
      final resolvedName = _nameController.text.trim().isEmpty
          ? (((user.displayName ?? '').trim().isNotEmpty)
              ? user.displayName!.trim()
            : 'User')
          : _nameController.text.trim();
      final resolvedRole = _roleController.text.trim().isEmpty
          ? 'Student'
          : _roleController.text.trim();
      await AuthService.updateUserProfile(
        fullName: resolvedName,
        photoUrl: _photoUrl,
      ).timeout(const Duration(seconds: 12), onTimeout: () {});
      final userData = <String, dynamic>{
        'fullName': resolvedName,
        'role': resolvedRole,
        'coverPhotoUrl': url,
        'lastUpdated': DateTime.now(),
      };
      if (_photoUrl != null && _photoUrl!.trim().isNotEmpty) {
        userData['photoUrl'] = _photoUrl;
      }
      await FirebaseService.saveUserProfile(
        userId: user.uid,
        userData: userData,
      ).timeout(const Duration(seconds: 12), onTimeout: () {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background updated.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (!uploaded) {
        setState(() {
          _pendingCoverBytes = null;
          _coverPhotoUrl = previousCoverUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background upload failed. Please try again.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background uploaded. Sync in progress.'),
          ),
        );
      }
    } finally {
      if (mounted && _uploadingCover) {
        setState(() => _uploadingCover = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: _isEditing ? 'Cancel edit' : 'Edit profile',
            onPressed: (_saving || _uploadingPhoto || _uploadingCover)
                ? null
                : () => setState(() {
                      _isEditing = !_isEditing;
                      if (!_isEditing) {
                        _loadProfile();
                      }
                    }),
            icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isEditing && !_uploadingCover
                        ? _pickAndUploadCoverPhoto
                        : null,
                    child: MouseRegion(
                      cursor: _isEditing && !_uploadingCover
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          image: _coverProvider() != null
                              ? DecorationImage(
                                  image: _coverProvider()!,
                                  fit: BoxFit.cover,
                                )
                              : null,
                          gradient: _coverProvider() == null
                              ? LinearGradient(
                                  colors: [scheme.primary, scheme.primary.withValues(alpha: 0.78)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Stack(
                          children: [
                            if (_coverProvider() != null)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.12),
                                      Colors.black.withValues(alpha: 0.28),
                                    ],
                                  ),
                                ),
                              ),
                            if (_isEditing && !_uploadingCover)
                              const Positioned.fill(
                                child: Center(
                                  child: Icon(
                                    Icons.photo_camera_outlined,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              )
                            else if (_uploadingCover)
                              const Positioned.fill(
                                child: Center(
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -30),
                    child: GestureDetector(
                      onTap: _isEditing && !_uploadingPhoto
                          ? _pickAndUploadPhoto
                          : null,
                      child: MouseRegion(
                        cursor: _isEditing && !_uploadingPhoto
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.basic,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 39,
                                backgroundColor: scheme.primaryContainer,
                                backgroundImage: _photoProvider(),
                                child: _photoProvider() == null
                                    ? Icon(Icons.person, size: 34, color: scheme.primary)
                                    : null,
                              ),
                            ),
                            if (_isEditing && !_uploadingPhoto)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              )
                            else if (_uploadingPhoto)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _nameController.text.trim().isEmpty
                        ? 'User'
                        : _nameController.text.trim(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _roleController.text.trim().isEmpty
                        ? 'Student'
                        : _roleController.text.trim(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  if (_isEditing) const SizedBox(height: 12),
                  if (_isEditing)
                    Text(
                      'Tap your profile photo or background to change them',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _isEditing
                  ? Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _roleController,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          initialValue: user?.email ?? '',
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _saving ? null : _saveProfile,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Saving...' : 'Save profile'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_outline),
                          title: const Text('Full name'),
                          subtitle: Text(
                            _nameController.text.trim().isEmpty
                                ? 'Not set'
                                : _nameController.text.trim(),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.badge_outlined),
                          title: const Text('Role'),
                          subtitle: Text(
                            _roleController.text.trim().isEmpty
                                ? 'Not set'
                                : _roleController.text.trim(),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.email_outlined),
                          title: const Text('Email address'),
                          subtitle: Text(user?.email ?? 'No email'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap the edit icon to update your details.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
