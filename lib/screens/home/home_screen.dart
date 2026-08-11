import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../build_flags.dart';
import '../../data/app_state.dart';
import '../../models/mascots.dart';
import '../../models/models.dart';
import '../../services/haptics.dart';
import '../../services/sound_service.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/celebration_overlay.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot_view.dart';
import '../schedule/schedule_screen.dart';
import 'log_feed_sheet.dart';
import 'log_meal_sheet.dart';
import 'nightlight_dial.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<LivyEvent>? _events;
  MascotPose? _reaction;
  Timer? _reactionTimer;
  int _confettiTrigger = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _events = context.read<AppState>().events.listen(_onEvent);
    });
  }

  void _onEvent(LivyEvent event) {
    if (!mounted) return;
    switch (event) {
      case FeedLoggedEvent(:final onTime):
        _react(onTime ? MascotPose.proud : MascotPose.idle);
        if (onTime) setState(() => _confettiTrigger++);
      case TagTeamEvent():
        _react(MascotPose.delighted);
        setState(() => _confettiTrigger++);
      case BadgeUnlockedEvent(:final badge):
        final app = context.read<AppState>();
        showBadgeCelebration(context,
            badge: badge, mascot: app.mascot, mascotName: app.mascotName);
    }
  }

  void _react(MascotPose pose) {
    _reactionTimer?.cancel();
    setState(() => _reaction = pose);
    _reactionTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _reaction = null);
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _reactionTimer?.cancel();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Quiet hours';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    if (h < 22) return 'Good evening';
    return 'Quiet hours';
  }

  String _fmt(Duration d) {
    final dd = d.isNegative ? -d : d;
    final h = dd.inHours, m = dd.inMinutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bundle = app.bundle;
    if (bundle == null) return const SizedBox.shrink();

    final overdue = app.feedOverdue;
    final until = app.untilNextFeed;
    final pose = _reaction ?? app.currentPose;
    final pending = bundle.household.schedule.pendingChange;

    return Stack(
      children: [
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: LivySpace.lg),
            children: [
              const SizedBox(height: LivySpace.md),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(_greeting(), style: LivyType.label()),
                          if (app.isDemo && !kScreenshotMode) ...[
                            const SizedBox(width: LivySpace.sm),
                            const DemoBadge(),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Text(bundle.household.baby.name, style: LivyType.display(size: 30)),
                        Text(bundle.household.baby.ageLabel,
                            style: LivyType.body(size: 13, color: LivyColors.mist)),
                      ],
                    ),
                  ),
                  MascotReaction(mascot: app.mascot, pose: pose, size: 92),
                ],
              ),

              // Pending schedule-change approval (account holder only).
              if (pending != null && pending.state == ScheduleChangeState.pending)
                Padding(
                  padding: const EdgeInsets.only(top: LivySpace.md),
                  child: _ApprovalBanner(pending: pending),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.15),

              const SizedBox(height: LivySpace.md),

              // ── The nightlight dial ────────────────────────────────────────
              Center(
                child: NightlightDial(
                  progress: app.dialProgress,
                  overdue: overdue,
                  size: MediaQuery.of(context).size.width - 96,
                  centerTop: overdue ? 'FEED DUE' : 'NEXT FEED IN',
                  centerBig: overdue ? '+${_fmt(until)}' : _fmt(until),
                  centerBottom: app.lastFeed == null
                      ? 'No feeds logged yet'
                      : 'last fed ${_fmt(app.sinceLastFeed)} ago · '
                          '${app.formatAmount(app.lastFeed!.amountMl)}',
                ),
              ),
              // Solids read directly under the dial: bottles above, meals
              // below, so one glance answers "what happened last?" — without
              // a meal ever touching the countdown.
              const SizedBox(height: LivySpace.sm),
              Center(child: _LastMealLine(app: app)),

              const SizedBox(height: LivySpace.xs),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScheduleScreen())),
                  icon: const Icon(Icons.timelapse_rounded, size: 18),
                  label: Text('Schedule: ${bundle.household.schedule.intervalLabel}',
                      style: LivyType.body(size: 14, color: LivyColors.periwinkle)),
                ),
              ),
              const SizedBox(height: LivySpace.md),

              VoxelButton(
                label: 'Log a feed',
                icon: Icons.water_drop_rounded,
                onPressed: () => showLogFeedSheet(context),
              ),
              const SizedBox(height: LivySpace.sm),
              // Secondary by design: the bottle is still the primary act.
              VoxelButton(
                label: 'Log a solid meal',
                icon: Icons.restaurant_rounded,
                color: LivyColors.surfaceRaised,
                textColor: LivyColors.cream,
                onPressed: () => showLogMealSheet(context),
              ),

              const SizedBox(height: LivySpace.lg),

              // Streak flames.
              Row(
                children: [
                  Expanded(
                      child: _StreakFlame(
                          label: 'On time',
                          days: bundle.streaks.onTimeStreakDays,
                          color: LivyColors.amber)),
                  const SizedBox(width: LivySpace.sm),
                  Expanded(
                      child: _StreakFlame(
                          label: 'Logged',
                          days: bundle.streaks.loggingStreakDays,
                          color: LivyColors.mint)),
                  const SizedBox(width: LivySpace.sm),
                  Expanded(
                      child: _StreakFlame(
                          label: 'Tag-team',
                          days: bundle.streaks.tagTeamStreakDays,
                          color: LivyColors.coral)),
                ],
              ),

              // Livy's latest recommendation.
              ..._recommendation(app, bundle),

              const SizedBox(height: LivySpace.xxl),
            ],
          ),
        ),
        MiniConfetti(trigger: _confettiTrigger),
      ],
    );
  }

  List<Widget> _recommendation(AppState app, bundle) {
    final rec = (app.bundle?.recommendations ?? const <LivyRecommendation>[])
        .where((r) => !r.dismissed)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (rec.isEmpty) return const [];
    final r = rec.first;
    return [
      const SizedBox(height: LivySpace.lg),
      RecommendationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              MascotView(mascot: app.mascot, pose: MascotPose.thoughtful, size: 44, glow: false),
              const SizedBox(width: LivySpace.sm),
              Expanded(
                child: Text('${app.mascotName} noticed something',
                    style: LivyType.label(color: LivyColors.amber)),
              ),
            ]),
            const SizedBox(height: LivySpace.sm),
            Text(r.text, style: LivyType.body(size: 14)),
            const SizedBox(height: LivySpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    SoundService.instance.dismiss();
                    app.dismissRecommendation(r);
                  },
                  child: Text('Not now',
                      style: LivyType.body(size: 14, color: LivyColors.mist)),
                ),
                if (r.kind == RecommendationKind.intervalDrift)
                  TextButton(
                    onPressed: () {
                      app.actOnRecommendation(r);
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ScheduleScreen()));
                    },
                    child: const Text('Review schedule'),
                  ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
    ];
  }
}

/// "Last meal 2h ago · pear · oatmeal", tucked directly under the dial.
///
/// Sits outside the ring on purpose. Bottles own the countdown; solids are
/// context for reading it — the gap stretching to five hours makes sense once
/// you can see there was sweet potato in between. Stays hidden until the
/// household actually starts solids, so newborn homes never see it.
class _LastMealLine extends StatelessWidget {
  const _LastMealLine({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final meal = app.lastMeal;
    if (meal == null) return const SizedBox.shrink();

    final since = app.sinceLastMeal;
    final label = since.inMinutes < 1
        ? 'just now'
        : since.inMinutes < 60
            ? '${since.inMinutes}m ago'
            : since.inHours < 24
                ? '${since.inHours}h ${since.inMinutes % 60}m ago'
                : '${since.inDays}d ago';

    return GestureDetector(
      onTap: () => showLogMealSheet(context),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant_rounded, size: 14, color: LivyColors.mint),
          const SizedBox(width: LivySpace.xs),
          Flexible(
            child: Text(
              'Last meal $label · ${meal.foodLabel}',
              overflow: TextOverflow.ellipsis,
              style: LivyType.body(size: 13, color: LivyColors.mist),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _StreakFlame extends StatelessWidget {
  const _StreakFlame({required this.label, required this.days, required this.color});

  final String label;
  final int days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return VoxelCard(
      padding: const EdgeInsets.symmetric(vertical: LivySpace.sm),
      child: Column(
        children: [
          Icon(Icons.local_fire_department_rounded,
                  color: days > 0 ? color : LivyColors.faint, size: 22)
              .animate(onPlay: (c) => days > 0 ? c.repeat(reverse: true) : null)
              .scaleXY(begin: 1, end: 1.12, duration: 1200.ms, curve: Curves.easeInOut),
          const SizedBox(height: 2),
          NumberRollup(
              value: days,
              style: LivyType.data(size: 18, weight: FontWeight.w700,
                  color: days > 0 ? LivyColors.cream : LivyColors.faint)),
          Text(label, style: LivyType.label(size: 9)),
        ],
      ),
    );
  }
}

class _ApprovalBanner extends StatelessWidget {
  const _ApprovalBanner({required this.pending});

  final ScheduleChangeRequest pending;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final proposed =
        FeedingSchedule(intervalMinutes: pending.proposedIntervalMinutes).intervalLabel;
    if (!app.isAccountHolder) {
      return VoxelCard(
        color: LivyColors.periwinkle.withValues(alpha: 0.08),
        borderColor: LivyColors.periwinkle.withValues(alpha: 0.35),
        child: Text(
          '${pending.proposedByName} proposed feeding $proposed — waiting for the account '
          'holder to approve.',
          style: LivyType.body(size: 13, color: LivyColors.mist),
        ),
      );
    }
    return VoxelCard(
      color: LivyColors.periwinkle.withValues(alpha: 0.08),
      borderColor: LivyColors.periwinkle.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${pending.proposedByName} wants to change the schedule to $proposed',
              style: LivyType.body(size: 14, weight: FontWeight.w700)),
          const SizedBox(height: LivySpace.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Haptics.warn();
                  SoundService.instance.dismiss();
                  app.resolveScheduleChange(approve: false);
                },
                child: Text('Decline', style: LivyType.body(size: 14, color: LivyColors.mist)),
              ),
              TextButton(
                onPressed: () {
                  Haptics.success();
                  SoundService.instance.feedLogged();
                  app.resolveScheduleChange(approve: true);
                },
                child: const Text('Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
