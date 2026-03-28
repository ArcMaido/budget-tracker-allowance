import 'package:flutter/material.dart';

class GetStartedPage extends StatelessWidget {
  const GetStartedPage({
    super.key,
    required this.onGetStarted,
  });

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.12),
              scheme.surface,
              scheme.secondary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 46,
                            color: scheme.primary,
                          ),
                        ),
                        Text(
                          'Coinzy',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We track smart, spend wiser.',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Plan your allowance, monitor daily expenses, and stay in control with a clear budget view that is easy to follow.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                height: 1.4,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: onGetStarted,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Get Started'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
