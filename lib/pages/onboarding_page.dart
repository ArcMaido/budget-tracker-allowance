import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingPage({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<OnboardingScreen> screens = [
    OnboardingScreen(
      icon: Icons.wallet,
      title: 'Welcome to Coinzy',
      description: 'Your personal budget tracker to manage your allowance wisely',
      color: const Color(0xFF1A7A59),
    ),
    OnboardingScreen(
      icon: Icons.category,
      title: 'Create Categories',
      description:
          'Start by adding spending categories like Food, Entertainment, Transport, etc. Set a monthly budget for each category.',
      color: const Color(0xFF4F6358),
    ),
    OnboardingScreen(
      icon: Icons.shopping_cart,
      title: 'Track Spending',
      description:
          'Add transactions whenever you spend money. Select the category and amount to keep track of your expenses.',
      color: const Color(0xFF2D6A4F),
    ),
    OnboardingScreen(
      icon: Icons.pie_chart,
      title: 'View Statistics',
      description:
          'Check your Overview tab to see your total spending, remaining balance, and progress bar for each category.',
      color: const Color(0xFF1B4332),
    ),
    OnboardingScreen(
      icon: Icons.trending_up,
      title: 'Stay in Budget',
      description:
          'The progress bar shows how much of your allowance you\'ve used. Try to stay within your category budgets!',
      color: const Color(0xFF0B6E3F),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    try {
      widget.onComplete();
    } catch (e) {
      print('Error completing onboarding: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: screens.length,
            itemBuilder: (context, index) {
              return OnboardingScreenWidget(screen: screens[index]);
            },
          ),
          // Dots indicator
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                screens.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentPage == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? screens[_currentPage].color
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          // Bottom buttons
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Skip button (only show if not on last page)
                _currentPage < screens.length - 1
                    ? TextButton(
                        onPressed: _completeOnboarding,
                        child: const Text('Skip'),
                      )
                    : const SizedBox(width: 60),
                // Next/Finish button
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage == screens.length - 1) {
                      _completeOnboarding();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: screens[_currentPage].color,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    _currentPage == screens.length - 1 ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingScreen {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingScreen({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class OnboardingScreenWidget extends StatelessWidget {
  final OnboardingScreen screen;

  const OnboardingScreenWidget({
    super.key,
    required this.screen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            screen.color.withOpacity(0.1),
            screen.color.withOpacity(0.05),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: screen.color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                screen.icon,
                size: 60,
                color: screen.color,
              ),
            ),
            const SizedBox(height: 40),
            // Title
            Text(
              screen.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Description
            Text(
              screen.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
