import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../services/haptics.dart';
import '../../services/sound_service.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Logging a solid meal — purée, mashed veg, finger food.
///
/// Sibling of the feed sheet, deliberately lighter: no amount, no units, no
/// schedule maths. Nothing logged here moves the bottle countdown.
Future<bool?> showLogMealSheet(BuildContext context) async {
  final app = context.read<AppState>();

  // Shown once per caregiver, before their first meal log. Cover the basics,
  // get out of the way, never ask again.
  if (!app.hasAcknowledged(DisclaimerKind.solidsIntro)) {
    final proceed = await _showSolidsIntro(context, app);
    if (proceed != true) return null;
    await app.acknowledgeDisclaimer(DisclaimerKind.solidsIntro);
  }

  if (!context.mounted) return null;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _LogMealSheet(),
  );
}

/// One-time orientation on solids. Deliberately describes general guidance and
/// points at the pediatrician — it never tells this parent what to do with
/// this baby.
Future<bool?> _showSolidsIntro(BuildContext context, AppState app) {
  final baby = app.bundle?.household.baby;
  final months = baby?.ageInMonths;
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: LivyColors.surfaceRaised,
      title: Text('Before you log a meal', style: LivyType.display(size: 20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'US guidance from the CDC and the American Academy of Pediatrics '
              'suggests starting solid foods at around 6 months — once a baby '
              'can sit up with support, hold their head steady, and shows '
              'interest in food. Breast milk or formula usually stays the main '
              'source of nutrition through the first year.',
              style: LivyType.body(size: 14, color: LivyColors.mist),
            ),
            if (months != null && months < 6) ...[
              const SizedBox(height: LivySpace.md),
              Text(
                '${baby!.name} is ${baby.ageLabel}. Starting solids earlier is '
                'something to talk through with your pediatrician first.',
                style: LivyType.body(size: 14, color: LivyColors.butter),
              ),
            ],
            const SizedBox(height: LivySpace.md),
            Text(
              'Livy keeps a record — she doesn\'t give medical advice. Your '
              'pediatrician knows your baby; this is just the notebook.',
              style: LivyType.body(size: 12, color: LivyColors.faint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Not now', style: LivyType.body(color: LivyColors.mist)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

/// The foods most households reach for first. Tapping a chip is the fast
/// path; the text field covers everything else.
const _commonFirstFoods = [
  'Banana',
  'Avocado',
  'Sweet potato',
  'Mashed potato',
  'Carrot',
  'Apple',
  'Pear',
  'Oatmeal',
  'Yogurt',
  'Egg',
  'Squash',
  'Peas',
];

class _LogMealSheet extends StatefulWidget {
  const _LogMealSheet();

  @override
  State<_LogMealSheet> createState() => _LogMealSheetState();
}

class _LogMealSheetState extends State<_LogMealSheet> {
  final Set<String> _foods = {};
  MealReaction _reaction = MealReaction.ateSome;
  DateTime _time = DateTime.now();
  final _otherController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Chips plus anything typed in "something else", comma-separated.
  List<String> get _allFoods => [
        ..._foods,
        ..._otherController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      ];

  Future<void> _save() async {
    final app = context.read<AppState>();
    final navigator = Navigator.of(context);
    Haptics.logFeed();
    SoundService.instance.feedLogged();
    await app.logMeal(
      foods: _allFoods,
      reaction: _reaction,
      time: _time,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );
    navigator.pop(true);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
    );
    if (picked == null) return;
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    // A time later than now means they meant yesterday evening.
    if (when.isAfter(now)) when = when.subtract(const Duration(days: 1));
    setState(() => _time = when);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final baby = app.bundle?.household.baby.name ?? 'baby';

    return Padding(
      padding: EdgeInsets.only(
        left: LivySpace.lg,
        right: LivySpace.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + LivySpace.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: LivySpace.md),
            Text('Log a meal', style: LivyType.display(size: 24)),
            const SizedBox(height: LivySpace.xs),
            Text(
              'for $baby · logged by ${app.caregiverName}',
              style: LivyType.body(size: 13, color: LivyColors.mist),
            ),
            const SizedBox(height: LivySpace.xs),
            Text(
              'Solids sit alongside bottles — this won\'t change the feed countdown.',
              style: LivyType.body(size: 12, color: LivyColors.faint),
            ),
            const SizedBox(height: LivySpace.lg),

            Text('What did $baby have?', style: LivyType.label(size: 11)),
            const SizedBox(height: LivySpace.sm),
            Wrap(
              spacing: LivySpace.sm,
              runSpacing: LivySpace.xs,
              children: [
                for (final food in _commonFirstFoods)
                  FilterChip(
                    label: Text(food),
                    selected: _foods.contains(food),
                    onSelected: (on) {
                      Haptics.tap();
                      setState(() => on ? _foods.add(food) : _foods.remove(food));
                    },
                  ),
              ],
            ),
            const SizedBox(height: LivySpace.md),
            TextField(
              controller: _otherController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Something else (comma-separated)',
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: LivySpace.lg),
            Text('How did it go?', style: LivyType.label(size: 11)),
            const SizedBox(height: LivySpace.sm),
            Row(
              children: [
                for (final r in MealReaction.values) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Haptics.tap();
                        setState(() => _reaction = r);
                      },
                      child: VoxelCard(
                        padding: const EdgeInsets.symmetric(vertical: LivySpace.sm),
                        borderColor:
                            _reaction == r ? LivyColors.amber : LivyColors.outline,
                        color: _reaction == r
                            ? LivyColors.amber.withValues(alpha: 0.08)
                            : LivyColors.surface,
                        child: Column(
                          children: [
                            Icon(
                              switch (r) {
                                MealReaction.loved => Icons.sentiment_very_satisfied_rounded,
                                MealReaction.ateSome => Icons.sentiment_satisfied_rounded,
                                MealReaction.refused => Icons.sentiment_neutral_rounded,
                              },
                              size: 22,
                              color: _reaction == r ? LivyColors.amber : LivyColors.faint,
                            ),
                            const SizedBox(height: 4),
                            Text(r.label,
                                textAlign: TextAlign.center,
                                style: LivyType.body(size: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (r != MealReaction.values.last)
                    const SizedBox(width: LivySpace.sm),
                ],
              ],
            ),

            const SizedBox(height: LivySpace.md),
            GestureDetector(
              onTap: _pickTime,
              child: VoxelCard(
                child: Row(children: [
                  Icon(Icons.schedule_rounded, size: 18, color: LivyColors.faint),
                  const SizedBox(width: LivySpace.sm),
                  Text(TimeOfDay.fromDateTime(_time).format(context),
                      style: LivyType.body(size: 15)),
                  const Spacer(),
                  Text('tap to change',
                      style: LivyType.body(size: 12, color: LivyColors.faint)),
                ]),
              ),
            ),

            const SizedBox(height: LivySpace.md),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),

            const SizedBox(height: LivySpace.lg),
            VoxelButton(
              label: 'Log meal',
              icon: Icons.restaurant_rounded,
              onPressed: _save,
            ),
            const SizedBox(height: LivySpace.sm),
          ],
        ),
      ),
    );
  }
}
