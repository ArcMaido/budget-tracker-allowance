import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onComplete,
  });

  final Future<void> Function() onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  bool _finishing = false;
  int _pageIndex = 0;

  static const List<_OnboardingStep> _steps = [
    _OnboardingStep(
      icon: Icons.savings_outlined,
      title: 'Plan Your Month Clearly',
      description:
          'Set your allowance once and track where every peso goes with clear, simple summaries.',
      hint: 'Start by setting a monthly allowance that matches your real budget.',
      accent: Color(0xFF166534),
    ),
    _OnboardingStep(
      icon: Icons.receipt_long_outlined,
      title: 'Log Expenses in Seconds',
      description:
          'Add spending by category and date so your totals and trends stay accurate day by day.',
      hint: 'Use short descriptions to make transaction history easier to scan later.',
      accent: Color(0xFF0C4A6E),
    ),
    _OnboardingStep(
      icon: Icons.bar_chart_outlined,
      title: 'Stay in Control',
      description:
          'See your remaining balance, category usage, and monthly progress in one dashboard.',
      hint: 'Check your History tab weekly to catch overspending early.',
      accent: Color(0xFF7C2D12),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextOrFinish() async {
    if (_finishing) {
      return;
    }

    if (_pageIndex < _steps.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    if (_finishing) {
      return;
    }

    setState(() => _finishing = true);

    try {
      await widget.onComplete();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to finish onboarding right now.')),
      );
      debugPrint('Error completing onboarding: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentStep = _steps[_pageIndex];
    final isLastPage = _pageIndex == _steps.length - 1;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.16),
              scheme.tertiary.withValues(alpha: 0.06),
              scheme.surface,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -80,
              child: _BackgroundOrb(
                diameter: 240,
                color: currentStep.accent.withValues(alpha: 0.15),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -90,
              child: _BackgroundOrb(
                diameter: 280,
                color: scheme.primary.withValues(alpha: 0.10),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Coinzy Setup',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: _finishing ? null : _completeOnboarding,
                                  child: const Text('Skip'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: List.generate(
                                _steps.length,
                                (index) => Expanded(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    margin: EdgeInsets.only(
                                      right: index == _steps.length - 1 ? 0 : 6,
                                    ),
                                    height: 6,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: index <= _pageIndex
                                          ? currentStep.accent
                                          : scheme.surfaceContainerHighest,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: _steps.length,
                                onPageChanged: (value) {
                                  setState(() => _pageIndex = value);
                                },
                                itemBuilder: (context, index) {
                                  final step = _steps[index];
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOut,
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            color: step.accent.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: step.accent.withValues(alpha: 0.28),
                                            ),
                                          ),
                                          child: Icon(
                                            step.icon,
                                            size: 34,
                                            color: step.accent,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                          step.title,
                                          style: textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          step.description,
                                          style: textTheme.bodyLarge?.copyWith(
                                            height: 1.5,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: step.accent.withValues(alpha: 0.10),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: step.accent.withValues(alpha: 0.22),
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.lightbulb_outline_rounded,
                                                color: step.accent,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  step.hint,
                                                  style: textTheme.bodyMedium?.copyWith(
                                                    color: scheme.onSurface,
                                                    height: 1.45,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Step ${index + 1} of ${_steps.length}',
                                          style: textTheme.labelLarge?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _finishing ? null : _nextOrFinish,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  backgroundColor: currentStep.accent,
                                ),
                                icon: _finishing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Icon(
                                        isLastPage
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.arrow_forward_rounded,
                                      ),
                                label: Text(
                                  _finishing
                                      ? 'Opening app...'
                                      : (isLastPage ? 'Start Using Coinzy' : 'Next'),
                                ),
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
          ],
        ),
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  const _BackgroundOrb({
    required this.diameter,
    required this.color,
  });

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.hint,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final String hint;
  final Color accent;
}
