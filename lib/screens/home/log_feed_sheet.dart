import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../services/haptics.dart';
import '../../services/sound_service.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// One-tap logging, expandable detail. Amount defaults to the household's
/// recent average so the fastest path really is a single tap on "Log feed".
Future<bool?> showLogFeedSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _LogFeedSheet(),
  );
}

class _LogFeedSheet extends StatefulWidget {
  const _LogFeedSheet();

  @override
  State<_LogFeedSheet> createState() => _LogFeedSheetState();
}

class _LogFeedSheetState extends State<_LogFeedSheet> {
  late double _amountMl;
  DateTime _time = DateTime.now();
  bool _detailsOpen = false;
  String? _brand;
  final _noteController = TextEditingController();
  final Set<SymptomKind> _symptoms = {};

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final feeds = app.bundle?.feeds ?? const [];
    _amountMl = feeds.isEmpty
        ? 120
        : (feeds.take(6).map((f) => f.amountMl).reduce((a, b) => a + b) /
                      feeds.take(6).length /
                      5)
                  .round() *
              5.0;
    _brand = feeds.isEmpty ? null : feeds.first.formulaBrand;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _bump(double deltaMl) {
    Haptics.tap();
    setState(() => _amountMl = (_amountMl + deltaMl).clamp(10, 400));
  }

  Future<void> _save() async {
    final app = context.read<AppState>();
    final navigator = Navigator.of(context);
    Haptics.logFeed();
    SoundService.instance.feedLogged();
    await app.logFeed(
      amountMl: _amountMl,
      time: _time,
      formulaBrand: _brand,
      symptoms: _symptoms
          .map((k) => SymptomNote(kind: k, note: _noteController.text.trim()))
          .toList(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final metric = app.useMetric;
    final display = metric
        ? '${_amountMl.round()}'
        : (_amountMl / 29.5735).toStringAsFixed(1);
    final unit = metric ? 'mL' : 'oz';
    final smallStep = metric ? 10.0 : 29.5735 / 2;
    final bigStep = metric ? 30.0 : 29.5735;

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
            Text('Log a feed', style: LivyType.display(size: 24)),
            const SizedBox(height: LivySpace.xs),
            Text(
              'for ${app.bundle?.household.baby.name ?? 'baby'} · logged by ${app.caregiverName}',
              style: LivyType.body(size: 13, color: LivyColors.mist),
            ),
            const SizedBox(height: LivySpace.lg),

            // Amount stepper — the hero control.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepButton(
                  label: '−$bigStepLabel',
                  onTap: () => _bump(-bigStep),
                ),
                _StepButton(label: '−', onTap: () => _bump(-smallStep)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: LivySpace.md),
                  child: GestureDetector(
                    onTap: () {
                      Haptics.tap();
                      app.toggleUnits();
                    },
                    child: Column(
                      children: [
                        Text(
                          display,
                          style: LivyType.data(
                            size: 52,
                            weight: FontWeight.w700,
                            color: LivyColors.amber,
                          ),
                        ),
                        Text(
                          '$unit · tap to switch',
                          style: LivyType.label(
                            size: 10,
                            color: LivyColors.faint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _StepButton(label: '+', onTap: () => _bump(smallStep)),
                _StepButton(
                  label: '+$bigStepLabel',
                  onTap: () => _bump(bigStep),
                ),
              ],
            ),
            const SizedBox(height: LivySpace.lg),

            // Time chip row (scrolls on narrow screens).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _timeChip('Now', DateTime.now()),
                  _timeChip(
                    '−15m',
                    DateTime.now().subtract(const Duration(minutes: 15)),
                  ),
                  _timeChip(
                    '−30m',
                    DateTime.now().subtract(const Duration(minutes: 30)),
                  ),
                  _timeChip(
                    '−1h',
                    DateTime.now().subtract(const Duration(hours: 1)),
                  ),
                  IconButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_time),
                      );
                      if (picked != null) {
                        final now = DateTime.now();
                        var t = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          picked.hour,
                          picked.minute,
                        );
                        if (t.isAfter(now)) {
                          t = t.subtract(const Duration(days: 1));
                        }
                        setState(() => _time = t);
                      }
                    },
                    icon: Icon(
                      Icons.schedule_rounded,
                      color: LivyColors.mist,
                    ),
                  ),
                ],
              ),
            ),

            // Expandable details for the dedicated parents.
            const SizedBox(height: LivySpace.sm),
            InkWell(
              borderRadius: BorderRadius.circular(LivyRadius.sm),
              onTap: () => setState(() => _detailsOpen = !_detailsOpen),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: LivySpace.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Brand & symptoms',
                      style: LivyType.body(
                        size: 14,
                        color: LivyColors.periwinkle,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _detailsOpen ? 0.5 : 0,
                      duration: LivyMotion.fast,
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: LivyColors.periwinkle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: LivyMotion.medium,
              sizeCurve: LivyMotion.settle,
              crossFadeState: _detailsOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: LivySpace.sm),
                  TextFormField(
                    initialValue: _brand,
                    decoration: const InputDecoration(
                      labelText: 'Formula brand / type',
                    ),
                    onChanged: (v) =>
                        _brand = v.trim().isEmpty ? null : v.trim(),
                  ),
                  const SizedBox(height: LivySpace.md),
                  Wrap(
                    spacing: LivySpace.sm,
                    runSpacing: LivySpace.sm,
                    children: SymptomKind.values
                        .where((k) => k != SymptomKind.other)
                        .map(
                          (k) => FilterChip(
                            label: Text(k.label),
                            selected: _symptoms.contains(k),
                            onSelected: (sel) {
                              Haptics.tap();
                              setState(
                                () => sel
                                    ? _symptoms.add(k)
                                    : _symptoms.remove(k),
                              );
                            },
                            selectedColor: LivyColors.coral.withValues(
                              alpha: 0.25,
                            ),
                            checkmarkColor: LivyColors.coral,
                            backgroundColor: LivyColors.surfaceSunken,
                            labelStyle: LivyType.body(size: 13),
                            side: BorderSide(color: LivyColors.outline),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: LivySpace.md),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),

            const SizedBox(height: LivySpace.lg),
            VoxelButton(
              label: 'Log feed',
              icon: Icons.check_rounded,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  String get bigStepLabel => context.read<AppState>().useMetric ? '30' : '1';

  Widget _timeChip(String label, DateTime value) {
    final selected =
        (_time.difference(value)).abs() < const Duration(minutes: 2);
    return Padding(
      padding: const EdgeInsets.only(right: LivySpace.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          Haptics.tap();
          setState(() => _time = value);
        },
        selectedColor: LivyColors.amber.withValues(alpha: 0.22),
        backgroundColor: LivyColors.surfaceSunken,
        labelStyle: LivyType.body(
          size: 13,
          color: selected ? LivyColors.amber : LivyColors.mist,
        ),
        side: BorderSide(color: LivyColors.outline),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: LivyColors.surfaceSunken,
        borderRadius: BorderRadius.circular(LivyRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(LivyRadius.sm),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Text(
              label,
              style: LivyType.data(
                size: 15,
                color: LivyColors.cream,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
