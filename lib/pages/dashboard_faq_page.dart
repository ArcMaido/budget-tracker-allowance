part of '../main.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  // Ticket concern is intentionally commented out until Firebase billing and the Cloud Function are enabled again.
  // Keep this page for FAQs only for now.

  static const List<_FaqEntry> _faqs = [
    _FaqEntry(
      icon: Icons.add_card_outlined,
      question: 'How do I add an expense?',
      answer:
          'Go to the Expenses page, choose a category, pick the date, enter the amount, then tap Add Expense.',
    ),
    _FaqEntry(
      icon: Icons.wallet_outlined,
      question: 'How do I change my monthly budget?',
      answer:
          'Open the allowance section and update the monthly budget for the selected month. The summary cards will refresh after saving.',
    ),
    _FaqEntry(
      icon: Icons.history_outlined,
      question: 'What does the History page show?',
      answer:
          'The History page lists your recorded expenses and lets you filter by category, month, and search text.',
    ),
    _FaqEntry(
      icon: Icons.file_download_outlined,
      question: 'Can I export my data?',
      answer:
          'Yes. You can export your transaction history to Excel or PDF with branded formatting for easier viewing.',
    ),
    _FaqEntry(
      icon: Icons.support_agent_outlined,
      question: 'How do I contact the developers?',
      answer:
          'Use the ticket concern section once Firebase Cloud Functions are enabled again.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('FAQs')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Frequently asked questions and quick answers for using Coinzy.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          ..._faqs.map(
            (faq) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  title: Text(
                    faq.question,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      faq.icon,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faq.answer,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Ticket Concern is intentionally disabled for now.
          // Re-enable this card and the sendConcernTicket Cloud Function after Firebase billing is settled.
        ],
      ),
    );
  }
}

class _FaqEntry {
  const _FaqEntry({
    required this.icon,
    required this.question,
    required this.answer,
  });

  final IconData icon;
  final String question;
  final String answer;
}
