import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth_service.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Simulate loading time
    await Future.delayed(const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return StreamBuilder<User?>(
              stream: AuthService.authStateChanges(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingScreen();
                }
                // This will be redirected by main.dart based on auth state
                return _buildLoadingScreen();
              },
            );
          }
          return _buildLoadingScreen();
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: const Color(0xFFF7FAF8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      size: 40,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Allowance Budget Tracker',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Preparing your dashboard...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
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
