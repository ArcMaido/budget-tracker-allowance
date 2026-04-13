part of '../main.dart';

extension _DashboardAboutSection on _AllowanceBudgetHomeState {
  Widget _buildAboutCard() {
    IconData roleIconFor(String role) {
      final normalized = role.toLowerCase();
      if (normalized.contains('backend')) {
        return Icons.storage_outlined;
      }
      if (normalized.contains('frontend')) {
        return Icons.language_outlined;
      }
      if (normalized.contains('leader') || normalized.contains('lead')) {
        return Icons.emoji_events_outlined;
      }
      if (normalized.contains('design')) {
        return Icons.palette_outlined;
      }
      if (normalized.contains('qa')) {
        return Icons.fact_check_outlined;
      }
      return Icons.badge_outlined;
    }

    Widget buildRoleBadge(String role) {
      final colors = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              roleIconFor(role),
              size: 14,
              color: colors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              role,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: colors.primary,
              ),
            ),
          ],
        ),
      );
    }

    const developers = [
      (
        name: 'Jim Agustin Maido',
        role: 'Backend Developer',
      ),
      (
        name: 'Joshua Tordecilla',
        role: 'Frontend Developer',
      ),
      (
        name: 'Jonreb Alonzo',
        role: 'Project Leader',
      ),
      (
        name: 'Rein Irish Santos',
        role: 'UI/UX Designer',
      ),
      (
        name: 'Justin Simangan',
        role: 'UI/UX Designer',
      ),
    ];

    const specialGuest = (
      name: 'Piolo Labios',
      role: 'QA and Frontend Designing',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Coinzy', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
                'This app helps students track monthly allowance, categorize expenses, and review spending trends with simple and clear sections.'),
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
                    _GuideCard(
                      icon: Icons.looks_one_outlined,
                      step: 'Step 1',
                      title: 'Set your starting budget',
                      body:
                          'Enter the amount you want to manage so the app can track it for you.'),
                    _GuideCard(
                        icon: Icons.looks_two_outlined,
                        step: 'Step 2',
                        title: 'Record your spending',
                        body:
                            'Add each expense so your totals, progress, and category breakdown stay updated.'),
                    _GuideCard(
                        icon: Icons.looks_3_outlined,
                        step: 'Step 3',
                        title: 'Review your progress',
                        body:
                            'Check your categories, summaries, and history to see where your money goes.'),
                  ].map((g) => SizedBox(width: cardWidth, child: g)).toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Developers',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            const SizedBox(height: 6),
            ...developers.map(
              (dev) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dev.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    buildRoleBadge(dev.role),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Special Thanks',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    specialGuest.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                buildRoleBadge(specialGuest.role),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
