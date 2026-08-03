import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/app_state.dart';
import '../../models/mascots.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Formula-switch journal — a personal record of what's been tried and why,
/// never a recommendation of what to switch to.
class FormulaJournalScreen extends StatelessWidget {
  const FormulaJournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final entries = [...?app.bundle?.formulaSwitches]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: const Text('Formula journal')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LivyColors.amber,
        foregroundColor: LivyColors.night,
        onPressed: () => _addEntry(context),
        icon: const Icon(Icons.add_rounded),
        label: Text('Log a switch', style: LivyType.body(weight: FontWeight.w800)),
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(LivySpace.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(MascotAssetResolver.instance.adaptive('assets/icons/icon_can.png'),
                        width: 130,
                        errorBuilder: (_, _, _) => Icon(Icons.rice_bowl_outlined,
                            size: 64, color: LivyColors.faint)),
                    const SizedBox(height: LivySpace.md),
                    Text('No switches recorded', style: LivyType.display(size: 20)),
                    const SizedBox(height: LivySpace.xs),
                    Text(
                      'When you change formula, note it here — your future self '
                      '(and your pediatrician) will thank you.',
                      textAlign: TextAlign.center,
                      style: LivyType.body(color: LivyColors.mist),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(LivySpace.lg),
              children: [
                // Timeline of switches, newest first.
                for (var i = 0; i < entries.length; i++)
                  _JournalEntry(
                    entry: entries[i],
                    isCurrent: i == 0,
                    isLast: i == entries.length - 1,
                  ),
                const SizedBox(height: 88), // clear the FAB
              ],
            ),
    );
  }

  Future<void> _addEntry(BuildContext context) async {
    final app = context.read<AppState>();
    final brand = TextEditingController();
    final reason = TextEditingController();
    final response = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: LivySpace.lg,
          right: LivySpace.lg,
          top: LivySpace.md,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + LivySpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log a formula switch', style: LivyType.display(size: 22)),
            const SizedBox(height: LivySpace.md),
            TextField(
              controller: brand,
              decoration: const InputDecoration(labelText: 'New formula brand / type'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: LivySpace.md),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Why the change? (optional)'),
            ),
            const SizedBox(height: LivySpace.md),
            TextField(
              controller: response,
              decoration: const InputDecoration(
                  labelText: 'How did baby respond? (fill in later if you like)'),
            ),
            const SizedBox(height: LivySpace.lg),
            VoxelButton(
              label: 'Save to journal',
              icon: Icons.check_rounded,
              onPressed: () {
                if (brand.text.trim().isEmpty) return;
                app.addFormulaSwitch(FormulaSwitchEntry(
                  id: const Uuid().v4(),
                  date: DateTime.now(),
                  brand: brand.text.trim(),
                  reason: reason.text.trim(),
                  response: response.text.trim(),
                ));
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalEntry extends StatelessWidget {
  const _JournalEntry({required this.entry, required this.isCurrent, required this.isLast});

  final FormulaSwitchEntry entry;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: isCurrent ? LivyColors.amber : LivyColors.outline,
                  shape: BoxShape.circle,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                              color: LivyColors.amber.withValues(alpha: 0.5),
                              blurRadius: 10)
                        ]
                      : null,
                ),
              ),
              if (!isLast)
                const Expanded(child: VerticalDivider(width: 14, thickness: 2)),
            ],
          ),
          const SizedBox(width: LivySpace.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: LivySpace.md),
              child: VoxelCard(
                borderColor: isCurrent
                    ? LivyColors.amber.withValues(alpha: 0.4)
                    : LivyColors.outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(entry.brand,
                                style: LivyType.body(size: 16, weight: FontWeight.w700))),
                        if (isCurrent)
                          Text('CURRENT', style: LivyType.label(size: 9, color: LivyColors.amber)),
                      ],
                    ),
                    Text(DateFormat('MMM d, yyyy').format(entry.date),
                        style: LivyType.body(size: 12, color: LivyColors.faint)),
                    if (entry.reason.isNotEmpty) ...[
                      const SizedBox(height: LivySpace.sm),
                      Text('Why: ${entry.reason}',
                          style: LivyType.body(size: 13, color: LivyColors.mist)),
                    ],
                    if (entry.response.isNotEmpty)
                      Text('Response: ${entry.response}',
                          style: LivyType.body(size: 13, color: LivyColors.mint)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
