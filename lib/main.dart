import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'data_service.dart';
import 'firebase_options.dart';
import 'pages/loading_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
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
		_loadDarkModePreference();
	}

	Future<void> _loadDarkModePreference() async {
		final prefs = await SharedPreferences.getInstance();
		setState(() {
			_darkMode = prefs.getBool('darkMode') ?? false;
		});
	}

	void _toggleDarkMode(bool value) {
		setState(() => _darkMode = value);
		AuthService.saveAppPreferences(
			darkMode: value,
			appData: {},
		);
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
			),
			home: StreamBuilder<User?>(
				stream: AuthService.authStateChanges(),
				builder: (context, snapshot) {
					if (snapshot.connectionState == ConnectionState.waiting) {
						return const LoadingPage();
					}

					if (snapshot.hasData && snapshot.data != null) {
						return UserAuthWrapper(
							isDarkMode: _darkMode,
							onToggleDarkMode: _toggleDarkMode,
						);
					}

					return const LoginPage();
				},
			),
			routes: {
				'/login': (context) => const LoginPage(),
				'/signup': (context) => const SignupPage(),
				'/home': (context) => AllowanceBudgetHome(
					isDarkMode: _darkMode,
					onToggleDarkMode: _toggleDarkMode,
				),
			},
		);
	}
}

// Wrapper to check if user needs onboarding
class UserAuthWrapper extends StatefulWidget {
	final bool isDarkMode;
	final Function(bool) onToggleDarkMode;

	const UserAuthWrapper({
		super.key,
		required this.isDarkMode,
		required this.onToggleDarkMode,
	});

	@override
	State<UserAuthWrapper> createState() => _UserAuthWrapperState();
}

class _UserAuthWrapperState extends State<UserAuthWrapper> {
	bool _showOnboarding = true;
	bool _isLoading = true;

	@override
	void initState() {
		super.initState();
		_checkIfNewUser();
	}

	Future<void> _checkIfNewUser() async {
		try {
			final isNew = await AuthService.isNewUser();
			if (mounted) {
				setState(() {
					_showOnboarding = isNew;
					_isLoading = false;
				});
			}
		} catch (e) {
			print('Error checking if new user: $e');
			if (mounted) {
				setState(() => _isLoading = false);
			}
		}
	}

	Future<void> _completeOnboarding() async {
		try {
			await AuthService.completeOnboarding();
			if (mounted) {
				setState(() => _showOnboarding = false);
			}
		} catch (e) {
			print('Error completing onboarding: $e');
		}
	}

	@override
	Widget build(BuildContext context) {
		if (_isLoading) {
			return const LoadingPage();
		}

		// If user is new, show onboarding
		if (_showOnboarding) {
			return OnboardingPage(
				onComplete: _completeOnboarding,
			);
		}

		// Otherwise show dashboard
		return AllowanceBudgetHome(
			isDarkMode: widget.isDarkMode,
			onToggleDarkMode: widget.onToggleDarkMode,
		);
	}
}

class AllowanceBudgetHome extends StatefulWidget {
	final bool isDarkMode;
	final Function(bool) onToggleDarkMode;

	const AllowanceBudgetHome({
		super.key,
		required this.isDarkMode,
		required this.onToggleDarkMode,
	});

	@override
	State<AllowanceBudgetHome> createState() => _AllowanceBudgetHomeState();
}

class _AllowanceBudgetHomeState extends State<AllowanceBudgetHome> {
	int _currentIndex = 0;
	String _profileName = 'User';
	String _profileRole = 'Parent';
	
	double _monthlyAllowance = 500.0;
	double _totalSpent = 0.0;
	List<Map<String, dynamic>> _categories = [];
	List<Map<String, dynamic>> _transactions = [];
	bool _isLoading = true;

	late TextEditingController _categoryNameController;
	late TextEditingController _categoryBudgetController;
	late TextEditingController _transactionAmountController;

	@override
	void initState() {
		super.initState();
		_categoryNameController = TextEditingController();
		_categoryBudgetController = TextEditingController();
		_transactionAmountController = TextEditingController();
		_loadData();
	}

	Future<void> _loadData() async {
		try {
			setState(() => _isLoading = true);
			
			final prefs = await SharedPreferences.getInstance();
			_profileName = prefs.getString('profileName') ?? 'User';
			_profileRole = prefs.getString('profileRole') ?? 'Parent';
			_monthlyAllowance = prefs.getDouble('monthlyAllowance') ?? 500.0;

			// Load from Firebase
			final allowance = await DataService.getMonthlyAllowance();
			if (allowance > 0) {
				_monthlyAllowance = allowance;
			}

			final spent = await DataService.getTotalSpentThisMonth();
			_totalSpent = spent;

			final categories = await DataService.getAllCategories();
			_categories = categories;

			// Fetch recent transactions
			final now = DateTime.now();
			final startOfMonth = DateTime(now.year, now.month, 1);
			final endOfMonth = DateTime(now.year, now.month + 1, 1);
			final transactions =
				await DataService.getTransactionsByDateRange(startOfMonth, endOfMonth);
			_transactions = transactions;

			if (mounted) {
				setState(() => _isLoading = false);
			}
		} catch (e) {
			print('Error loading data: $e');
			if (mounted) {
				setState(() => _isLoading = false);
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Error loading data: $e')),
				);
			}
		}
	}

	Future<void> _save() async {
		try {
			final prefs = await SharedPreferences.getInstance();
			await prefs.setString('profileName', _profileName);
			await prefs.setString('profileRole', _profileRole);
			await prefs.setDouble('monthlyAllowance', _monthlyAllowance);

			// Sync to Firebase
			await DataService.setMonthlyAllowance(_monthlyAllowance);
			await AuthService.saveAppPreferences(
				darkMode: widget.isDarkMode,
				appData: {
					'profileName': _profileName,
					'profileRole': _profileRole,
					'monthlyAllowance': _monthlyAllowance,
				},
			);
		} catch (e) {
			print('Error saving data: $e');
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Error saving: $e')),
				);
			}
		}
	}

	@override
	void dispose() {
		_categoryNameController.dispose();
		_categoryBudgetController.dispose();
		_transactionAmountController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Coinzy'),
				centerTitle: false,
				elevation: 0,
				actions: [
					IconButton(
						icon: Icon(
							widget.isDarkMode
								? Icons.light_mode
								: Icons.dark_mode,
						),
						onPressed: () =>
							widget.onToggleDarkMode(!widget.isDarkMode),
					),
					PopupMenuButton<String>(
						itemBuilder: (BuildContext context) => [
							const PopupMenuItem<String>(
								value: 'profile',
								child: Text('Profile'),
							),
							const PopupMenuItem<String>(
								value: 'settings',
								child: Text('Settings'),
							),
							const PopupMenuDivider(),
							const PopupMenuItem<String>(
								value: 'logout',
								child: Text('Sign Out'),
							),
						],
						onSelected: (String value) {
							if (value == 'profile') {
								_openProfilePage();
							} else if (value == 'logout') {
								_signOut();
							}
						},
					),
				],
			),
			body: _isLoading
				? const Center(child: CircularProgressIndicator())
				: IndexedStack(
					index: _currentIndex,
					children: [
						_buildOverviewTab(),
						_buildHistoryTab(),
						_buildBudgetTab(),
					],
				),
			bottomNavigationBar: BottomNavigationBar(
				currentIndex: _currentIndex,
				onTap: (index) => setState(() => _currentIndex = index),
				items: const [
					BottomNavigationBarItem(
						icon: Icon(Icons.pie_chart),
						label: 'Overview',
					),
					BottomNavigationBarItem(
						icon: Icon(Icons.history),
						label: 'History',
					),
					BottomNavigationBarItem(
						icon: Icon(Icons.wallet),
						label: 'Budget',
					),
				],
			),
			floatingActionButton: _currentIndex == 1
				? FloatingActionButton(
					onPressed: _showAddTransactionDialog,
					child: const Icon(Icons.add),
				)
				: null,
		);
	}

	Widget _buildOverviewTab() {
		final remaining = _monthlyAllowance - _totalSpent;
		final percentageUsed =
			_monthlyAllowance > 0 ? (_totalSpent / _monthlyAllowance) : 0.0;

		return SingleChildScrollView(
			padding: const EdgeInsets.all(16),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					// Monthly Allowance Card
					Card(
						child: Padding(
							padding: const EdgeInsets.all(16),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									const Text(
										'Monthly Allowance',
										style: TextStyle(
											fontSize: 14,
											fontWeight: FontWeight.w500,
										),
									),
									const SizedBox(height: 8),
									Text(
										'\$${_monthlyAllowance.toStringAsFixed(2)}',
										style: const TextStyle(
											fontSize: 28,
											fontWeight: FontWeight.bold,
										),
									),
								],
							),
						),
					),
					const SizedBox(height: 16),

					// Progress Bar
					Card(
						child: Padding(
							padding: const EdgeInsets.all(16),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Row(
										mainAxisAlignment:
											MainAxisAlignment.spaceBetween,
										children: [
											const Text('Spent This Month'),
											Text(
												'\$${_totalSpent.toStringAsFixed(2)}',
												style: const TextStyle(
													fontWeight: FontWeight.bold,
												),
											),
										],
									),
									const SizedBox(height: 8),
									LinearProgressIndicator(
										value: percentageUsed.clamp(0.0, 1.0),
										minHeight: 8,
									),
									const SizedBox(height: 8),
									Row(
										mainAxisAlignment:
											MainAxisAlignment.spaceBetween,
										children: [
											Text(
												'${(percentageUsed * 100).toStringAsFixed(0)}% used',
											),
											Text(
												'Remaining: \$${remaining.toStringAsFixed(2)}',
												style: TextStyle(
													color: remaining >= 0
														? Colors.green
														: Colors.red,
												),
											),
										],
									),
								],
							),
						),
					),
					const SizedBox(height: 16),

					// Quick Actions
					Row(
						children: [
							Expanded(
								child: ElevatedButton.icon(
									onPressed: _showAllowanceDialog,
									icon: const Icon(Icons.edit),
									label: const Text('Edit Allowance'),
								),
							),
							const SizedBox(width: 8),
							Expanded(
								child: ElevatedButton.icon(
									onPressed: _loadData,
									icon: const Icon(Icons.refresh),
									label: const Text('Refresh'),
								),
							),
						],
					),
				],
			),
		);
	}

	Widget _buildHistoryTab() {
		return _transactions.isEmpty
			? Center(
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						const Icon(Icons.receipt, size: 64, color: Colors.grey),
						const SizedBox(height: 16),
						const Text('No transactions yet'),
						const SizedBox(height: 16),
						ElevatedButton.icon(
							onPressed: _showAddTransactionDialog,
							icon: const Icon(Icons.add),
							label: const Text('Add Transaction'),
						),
					],
				),
			)
			: ListView.builder(
				padding: const EdgeInsets.all(16),
				itemCount: _transactions.length,
				itemBuilder: (context, index) {
					final tx = _transactions[index];
					final date = (tx['date'] as DateTime);
					final formattedDate =
						'${date.month}/${date.day}/${date.year}';

					return Card(
						child: ListTile(
							title: Text(tx['category'] ?? 'Unknown'),
							subtitle: Text(formattedDate),
							trailing: Text(
								'\$${(tx['amount'] as num).toStringAsFixed(2)}',
								style: const TextStyle(
									fontWeight: FontWeight.bold,
								),
							),
							onLongPress: () {
								showDialog(
									context: context,
									builder: (context) => AlertDialog(
										title: const Text('Delete Transaction?'),
										content: const Text(
											'Are you sure you want to delete this transaction?',
										),
										actions: [
											TextButton(
												onPressed: () =>
													Navigator.pop(context),
												child: const Text('Cancel'),
											),
											TextButton(
												onPressed: () async {
													await DataService.deleteTransaction(
														tx['id'],
													);
													_loadData();
													if (mounted) {
														Navigator.pop(context);
													}
												},
												child: const Text('Delete'),
											),
										],
									),
								);
							},
						),
					);
				},
			);
	}

	Widget _buildBudgetTab() {
		return SingleChildScrollView(
			padding: const EdgeInsets.all(16),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					const Text(
						'Categories',
						style: TextStyle(
							fontSize: 18,
							fontWeight: FontWeight.bold,
						),
					),
					const SizedBox(height: 12),
					_categories.isEmpty
						? Card(
							child: Padding(
								padding: const EdgeInsets.all(32),
								child: Center(
									child: Column(
										children: [
											const Icon(Icons.category,
												size: 48, color: Colors.grey),
											const SizedBox(height: 16),
											const Text(
												'No categories yet',
												textAlign: TextAlign.center,
											),
										],
									),
								),
							),
						)
						: ListView.builder(
							shrinkWrap: true,
							physics: const NeverScrollableScrollPhysics(),
							itemCount: _categories.length,
							itemBuilder: (context, index) {
								final cat = _categories[index];
								return Card(
									child: ListTile(
										title: Text(cat['name'] ?? 'Unknown'),
										subtitle: Text(
											'Budget: \$${(cat['budget'] as num).toStringAsFixed(2)}',
										),
										trailing: IconButton(
											icon: const Icon(Icons.delete),
											onPressed: () async {
												await DataService.deleteCategory(
													cat['name'],
												);
												_loadData();
											},
										),
									),
								);
							},
						),
					const SizedBox(height: 16),
					ElevatedButton.icon(
						onPressed: _showAddCategoryDialog,
						icon: const Icon(Icons.add),
						label: const Text('Add Category'),
					),
				],
			),
		);
	}

	void _showAllowanceDialog() {
		final tempController = TextEditingController(
			text: _monthlyAllowance.toString(),
		);

		showDialog(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Edit Monthly Allowance'),
				content: TextField(
					controller: tempController,
					keyboardType:
						const TextInputType.numberWithOptions(decimal: true),
					decoration: const InputDecoration(hintText: 'Enter amount'),
				),
				actions: [
					TextButton(
						onPressed: () {
							tempController.dispose();
							Navigator.pop(context);
						},
						child: const Text('Cancel'),
					),
					TextButton(
						onPressed: () async {
							final value = double.tryParse(tempController.text);
							if (value != null && value >= 0) {
								setState(() => _monthlyAllowance = value);
								await _save();
								tempController.dispose();
								if (mounted) {
									Navigator.pop(context);
								}
							}
						},
						child: const Text('Save'),
					),
				],
			),
		);
	}

	void _showAddTransactionDialog() {
		final amountController = TextEditingController();
		final descriptionController = TextEditingController();
		String? selectedCategory;

		showDialog(
			context: context,
			builder: (context) => StatefulBuilder(
				builder: (context, setDialogState) => AlertDialog(
					title: const Text('Add Transaction'),
					content: SingleChildScrollView(
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								DropdownButton<String>(
									value: selectedCategory,
									hint: const Text('Select Category'),
									isExpanded: true,
									items: _categories
										.map((cat) =>
											DropdownMenuItem<String>(
												value: cat['name'],
												child: Text(cat['name']),
											))
										.toList(),
									onChanged: (value) {
										setDialogState(() => selectedCategory = value);
									},
								),
								const SizedBox(height: 12),
								TextField(
									controller: amountController,
									keyboardType:
										const TextInputType.numberWithOptions(
											decimal: true),
									decoration: const InputDecoration(
										labelText: 'Amount',
										hintText: '0.00',
									),
								),
								const SizedBox(height: 12),
								TextField(
									controller: descriptionController,
									decoration: const InputDecoration(
										labelText: 'Description (optional)',
									),
								),
							],
						),
					),
					actions: [
						TextButton(
							onPressed: () {
								amountController.dispose();
								descriptionController.dispose();
								Navigator.pop(context);
							},
							child: const Text('Cancel'),
						),
						TextButton(
							onPressed: () async {
								final amount =
									double.tryParse(amountController.text);
								if (selectedCategory != null && amount != null) {
									await DataService.saveTransaction(
										category: selectedCategory!,
										amount: amount,
										date: DateTime.now(),
										description: descriptionController.text,
									);
									_loadData();
									amountController.dispose();
									descriptionController.dispose();
									if (mounted) {
										Navigator.pop(context);
									}
								}
							},
							child: const Text('Add'),
						),
					],
				),
			),
		);
	}

	void _showAddCategoryDialog() {
		_categoryNameController.clear();
		_categoryBudgetController.clear();

		showDialog(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Add Category'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						TextField(
							controller: _categoryNameController,
							decoration: const InputDecoration(
								labelText: 'Category Name',
							),
						),
						const SizedBox(height: 12),
						TextField(
							controller: _categoryBudgetController,
							keyboardType:
								const TextInputType.numberWithOptions(decimal: true),
							decoration: const InputDecoration(
								labelText: 'Budget Amount',
							),
						),
					],
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(context),
						child: const Text('Cancel'),
					),
					TextButton(
						onPressed: () async {
							final name = _categoryNameController.text.trim();
							final budget =
								double.tryParse(_categoryBudgetController.text);

							if (name.isNotEmpty && budget != null && budget > 0) {
								await DataService.saveCategory(
									categoryName: name,
									budget: budget,
								);
								_loadData();
								if (mounted) {
									Navigator.pop(context);
								}
							}
						},
						child: const Text('Add'),
					),
				],
			),
		);
	}

	void _openProfilePage() {
		// TODO: Implement profile page or dialog
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text('Profile page coming soon')),
		);
	}

	Future<void> _signOut() async {
		await AuthService.signOut();
		if (mounted) {
			Navigator.of(context).pushNamedAndRemoveUntil(
				'/login',
				(route) => false,
			);
		}
	}
}
