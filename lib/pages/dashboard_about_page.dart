part of '../main.dart';

extension _DashboardAboutSection on _AllowanceBudgetHomeState {
  Widget _buildAboutCard() {
    const developers = [
      (
        name: 'Jim Agustin Maido',
        role: 'Project Lead',
      ),
      (
        name: 'Joshua Tordecilla',
        role: 'Frontend Developer',
      ),
      (
        name: 'John Reb Alonzo',
        role: 'Feature Developer',
      ),
      (
        name: 'Rein Irish Santos',
        role: 'UX Contributor',
      ),
      (
        name: 'Justin Simangan',
        role: 'Data & Logic Developer',
      ),
    ];

    const specialGuest = (
      name: 'Piolo Labios',
      role: 'Special Guest',
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
                        step: 'Step 1',
                        title: 'Set your monthly allowance',
                        body:
                            'Use the Allowance card to save your budget in PHP.'),
                    _GuideCard(
                        step: 'Step 2',
                        title: 'Add expenses as they happen',
                        body:
                            'Each entry updates your totals, progress bar, and insights automatically.'),
                    _GuideCard(
                        step: 'Step 3',
                        title: 'Review trends monthly',
                        body:
                            'Check categories, monthly summaries, and filter transaction history.'),
                  ].map((g) => SizedBox(width: cardWidth, child: g)).toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            const Text('Developers',
                style: TextStyle(fontWeight: FontWeight.w700)),
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
                    Text(
                      dev.role,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Special Thanks',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.star_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${specialGuest.name} (${specialGuest.role})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
