// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:allowance_budget_dashboard/pages/login_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Login page widget can be constructed', () {
    const page = LoginPage(
      isDarkMode: false,
      onToggleDarkMode: _noopToggle,
    );
    expect(page, isA<StatefulWidget>());
  });

  testWidgets('Login page shows welcome title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(
          isDarkMode: false,
          onToggleDarkMode: _noopToggle,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('Login page shows sign in action', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(
          isDarkMode: false,
          onToggleDarkMode: _noopToggle,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
  });
}

void _noopToggle(bool _) {}
