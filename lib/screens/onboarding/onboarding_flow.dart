import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../data/app_state.dart';
import '../../data/firestore_repository.dart';
import '../../legal_links.dart';
import '../../models/mascots.dart';
import '../../models/models.dart';
import '../../services/haptics.dart';
import '../../services/notification_service.dart';
import '../../services/purchase_service.dart';
import '../../services/sound_service.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot_view.dart';

/// First-run flow: welcome → the 3am problem → the one-tap promise →
/// sign in → baby profile → choose Livy's identity → feeding schedule →
/// hard paywall → notifications → done.
///
/// Order is deliberate. The value screens name the problem and show the fix
/// before anything is asked for, and the paywall comes last — after the user
/// has signed in, named their baby, cast a companion and set a rhythm. By
/// then the plan is protecting something that already feels like theirs.
///
/// Note the invite-code path on the baby screen sits ahead of the paywall:
/// invited caregivers are covered by the account holder's plan and must be
/// able to reach it without ever meeting a price.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _page = PageController();

  // Collected along the way.
  final _nameController = TextEditingController(text: '');
  final _babyController = TextEditingController();
  DateTime _birthDate = DateTime.now().subtract(const Duration(days: 30));
  String _mascotId = 'granny';
  String? _mascotName;
  int _intervalMinutes = 180;
  bool _busy = false;

  @override
  void dispose() {
    _page.dispose();
    _nameController.dispose();
    _babyController.dispose();
    super.dispose();
  }

  void _next() {
    Haptics.tap();
    _page.nextPage(duration: LivyMotion.medium, curve: LivyMotion.settle);
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    final app = context.read<AppState>();
    try {
      await app.createHousehold(
        caregiverName:
            _nameController.text.trim().isEmpty ? 'You' : _nameController.text.trim(),
        baby: BabyProfile(
          name: _babyController.text.trim().isEmpty
              ? 'Little one'
              : _babyController.text.trim(),
          birthDate: _birthDate,
        ),
        intervalMinutes: _intervalMinutes,
        mascot: MascotState(mascotId: _mascotId, customName: _mascotName),
      );
      SoundService.instance.celebration();
      Haptics.celebrate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _page,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _WelcomePage(onNext: _next),
          _ProblemPage(onNext: _next),
          _PromisePage(onNext: _next),
          _SignInPage(onNext: _next, nameController: _nameController),
          _BabyPage(
            controller: _babyController,
            birthDate: _birthDate,
            onBirthDate: (d) => setState(() => _birthDate = d),
            onNext: _next,
          ),
          _MascotPage(
            selectedId: _mascotId,
            onSelect: (id) => setState(() => _mascotId = id),
            onRename: (n) => setState(() => _mascotName = n),
            mascotName: _mascotName,
            onNext: _next,
          ),
          _SchedulePage(
            minutes: _intervalMinutes,
            onChanged: (m) => setState(() => _intervalMinutes = m),
            onNext: _next,
          ),
          // Last: by now the user has named their baby, cast their companion
          // and set a rhythm — the plan is protecting something of theirs.
          _PaywallPage(onUnlocked: _next, babyNameController: _babyController),
          _NotificationsPage(onFinish: _finish, busy: _busy),
        ],
      ),
    );
  }
}

class _OnboardingScaffold extends StatelessWidget {
  const _OnboardingScaffold({
    required this.children,
    this.hero,
    this.scrollable = false,
  });

  final List<Widget> children;
  final Widget? hero;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hero != null) Center(child: hero!),
        ...children,
      ],
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(LivySpace.lg),
        child: scrollable
            ? SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 140),
                  child: column,
                ),
              )
            : column,
      ),
    );
  }
}

// ── 1 · Welcome ──────────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      hero: ClipRRect(
        borderRadius: BorderRadius.circular(LivyRadius.lg),
        child: Image.asset(
          MascotAssetResolver.instance.adaptive('assets/art/onboarding_hero.png'),
          height: 230,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const MascotView(mascot: MascotCatalog.granny, size: 200),
        ),
      ).animate().fadeIn(duration: 600.ms).scaleXY(begin: 0.95, curve: Curves.easeOut),
      children: [
        const SizedBox(height: LivySpace.lg),
        Text('Livy — Fed On Time',
                textAlign: TextAlign.center, style: LivyType.display(size: 32))
            .animate()
            .fadeIn(delay: 150.ms),
        const SizedBox(height: LivySpace.sm),
        Text(
          'One shared record of every feed, for every caregiver — wrapped in a warm '
          'little nightlight. No more "when was the last bottle?"',
          textAlign: TextAlign.center,
          style: LivyType.body(size: 15, color: LivyColors.mist),
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: LivySpace.xl),
        VoxelButton(label: 'Meet Livy', icon: Icons.arrow_forward_rounded, onPressed: onNext)
            .animate()
            .fadeIn(delay: 450.ms)
            .slideY(begin: 0.2),
      ],
    );
  }
}

// ── 2 · The problem ─────────────────────────────────────────────────────────

/// Names the pain before anything is asked for. The paywall lands better when
/// the user has already agreed, silently, that they have this problem.
class _ProblemPage extends StatelessWidget {
  const _ProblemPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      hero: ClipRRect(
        borderRadius: BorderRadius.circular(LivyRadius.lg),
        child: Image.asset(
          MascotAssetResolver.instance.adaptive('assets/icons/icon_moon.png'),
          height: 140,
          errorBuilder: (_, _, _) =>
              Icon(Icons.bedtime_outlined, size: 90, color: LivyColors.periwinkle),
        ),
      ).animate().fadeIn(duration: 600.ms).scaleXY(begin: 0.95, curve: Curves.easeOut),
      children: [
        const SizedBox(height: LivySpace.lg),
        Text('It\'s 3am. When was the last bottle?',
                textAlign: TextAlign.center, style: LivyType.display(size: 26))
            .animate()
            .fadeIn(delay: 150.ms),
        const SizedBox(height: LivySpace.sm),
        Text(
          'Someone fed her. Probably. The other caregiver is asleep, the notes '
          'app has two different times in it, and you\'re doing arithmetic you '
          'should not be doing at 3am.',
          textAlign: TextAlign.center,
          style: LivyType.body(size: 15, color: LivyColors.mist),
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: LivySpace.xl),
        VoxelButton(
                label: 'I know that feeling',
                icon: Icons.arrow_forward_rounded,
                onPressed: onNext)
            .animate()
            .fadeIn(delay: 450.ms)
            .slideY(begin: 0.2),
      ],
    );
  }
}

// ── 3 · The quick win ───────────────────────────────────────────────────────

/// The aha moment, before the price: one tap, and the whole household is in
/// sync. Everything on the paywall is a variation on this promise.
class _PromisePage extends StatelessWidget {
  const _PromisePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      hero: const MascotView(
          mascot: MascotCatalog.granny, pose: MascotPose.delighted, size: 150),
      children: [
        const SizedBox(height: LivySpace.lg),
        Text('One tap. The whole house knows.',
                textAlign: TextAlign.center, style: LivyType.display(size: 26))
            .animate()
            .fadeIn(delay: 150.ms),
        const SizedBox(height: LivySpace.sm),
        Text(
          'Log a feed in a single tap and the dial fills on every caregiver\'s '
          'phone at once — same last feed, same countdown, no group text '
          'required.',
          textAlign: TextAlign.center,
          style: LivyType.body(size: 15, color: LivyColors.mist),
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: LivySpace.xl),
        VoxelButton(
                label: 'Show me',
                icon: Icons.arrow_forward_rounded,
                onPressed: onNext)
            .animate()
            .fadeIn(delay: 450.ms)
            .slideY(begin: 0.2),
      ],
    );
  }
}

// ── 4 · Sign in ─────────────────────────────────────────────────────────────

class _SignInPage extends StatefulWidget {
  const _SignInPage({required this.onNext, required this.nameController});

  final VoidCallback onNext;
  final TextEditingController nameController;

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  bool _busy = false;

  Future<void> _apple() async {
    final app = context.read<AppState>();
    if (app.isDemo) {
      // No Firebase in demo mode — Apple sign-in is simulated.
      widget.onNext();
      return;
    }
    // Already signed in from a previous session — no need to re-authenticate.
    final existing = FirebaseAuth.instance.currentUser;
    if (existing != null) {
      await _completeAuth(existing);
      return;
    }
    setState(() => _busy = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ]);
      final oauth = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(oauth);
      final given = credential.givenName;
      if (given != null && given.isNotEmpty) widget.nameController.text = given;
      await _completeAuth(userCred.user);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sign-in didn\'t complete: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Upgrades from the pre-auth local repository to real Firestore sync so
  /// the household created next lands in the cloud.
  /// A caregiver's name is shown to *other people* — beside every feed they
  /// log, and in the household list. 'You' reads fine on your own device and
  /// absurd on anyone else's, so it is never used as a stored name.
  static String _resolveName(User user, String typed) {
    final t = typed.trim();
    if (t.isNotEmpty) return t;
    final display = user.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final email = user.email;
    if (email != null && email.contains('@')) {
      final local = email.split('@').first.trim();
      if (local.isNotEmpty) {
        return local[0].toUpperCase() + local.substring(1);
      }
    }
    return 'Caregiver';
  }

  Future<void> _completeAuth(User? user) async {
    if (user == null || !mounted) return;
    final app = context.read<AppState>();
    final purchases = context.read<PurchaseService>();
    await app.swapRepository(FirestoreRepository(
      uid: user.uid,
      displayName: _resolveName(user, widget.nameController.text),
    ));
    // Identify before the paywall two screens later, so an existing subscriber
    // arrives already entitled instead of being asked to buy a second time.
    await purchases.identify(user.uid);
    if (!mounted) return;
    widget.onNext();
  }

  /// Email/password fallback (Apple platform policy requires Apple sign-in to
  /// be offered, but email remains available). Signs in, creating the account
  /// on first use.
  Future<void> _email() async {
    final emailController = TextEditingController();
    final passController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final submitted = await showModalBottomSheet<bool>(
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
            Text('Sign in with email', style: LivyType.display(size: 22)),
            const SizedBox(height: LivySpace.md),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: LivySpace.md),
            TextField(
              controller: passController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Password (6+ characters)'),
            ),
            const SizedBox(height: LivySpace.lg),
            VoxelButton(
              label: 'Continue',
              icon: Icons.mail_outline_rounded,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || !mounted) return;

    final email = emailController.text.trim();
    final password = passController.text;
    if (email.isEmpty || password.length < 6) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Please enter an email and a password of 6+ characters.')));
      return;
    }
    setState(() => _busy = true);
    final auth = FirebaseAuth.instance;
    try {
      UserCredential cred;
      try {
        cred = await auth.signInWithEmailAndPassword(email: email, password: password);
      } on FirebaseAuthException catch (e) {
        // First time with this email → create the account.
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
        } else {
          rethrow;
        }
      }
      await _completeAuth(cred.user);
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(e.message ?? 'Sign-in didn\'t complete.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return _OnboardingScaffold(
      hero: const MascotView(mascot: MascotCatalog.granny, size: 140),
      children: [
        const SizedBox(height: LivySpace.md),
        Text('Who\'s holding the bottle?',
            textAlign: TextAlign.center, style: LivyType.display(size: 26)),
        const SizedBox(height: LivySpace.sm),
        Text(
          'Your name shows next to every feed you log, so the household always knows '
          'who fed last.',
          textAlign: TextAlign.center,
          style: LivyType.body(size: 14, color: LivyColors.mist),
        ),
        const SizedBox(height: LivySpace.lg),
        TextField(
          controller: widget.nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your first name'),
        ),
        const SizedBox(height: LivySpace.lg),
        VoxelButton(
          label: _busy
              ? 'Signing in…'
              : app.isDemo
                  ? 'Sign in with Apple (simulated in demo)'
                  : 'Sign in with Apple',
          icon: Icons.apple_rounded,
          // cream/night flip roles per phase, so this reads as the classic
          // light-on-dark Apple button at night and dark-on-light by day.
          color: LivyColors.cream,
          textColor: LivyColors.night,
          onPressed: _busy ? null : _apple,
        ),
        if (!app.isDemo)
          TextButton(
            onPressed: _busy ? null : _email,
            child: const Text('Use email instead'),
          ),
      ],
    );
  }
}

// ── 5 · Baby profile ────────────────────────────────────────────────────────

class _BabyPage extends StatelessWidget {
  const _BabyPage({
    required this.controller,
    required this.birthDate,
    required this.onBirthDate,
    required this.onNext,
  });

  final TextEditingController controller;
  final DateTime birthDate;
  final ValueChanged<DateTime> onBirthDate;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      hero: ClipRRect(
        borderRadius: BorderRadius.circular(LivyRadius.lg),
        child: Image.asset(MascotAssetResolver.instance.adaptive('assets/icons/icon_bottle.png'),
            height: 140,
            errorBuilder: (_, _, _) =>
                Icon(Icons.child_care_rounded, size: 90, color: LivyColors.amber)),
      ),
      children: [
        const SizedBox(height: LivySpace.md),
        Text('Tell Livy about your baby',
            textAlign: TextAlign.center, style: LivyType.display(size: 26)),
        const SizedBox(height: LivySpace.lg),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Baby\'s name'),
        ),
        const SizedBox(height: LivySpace.md),
        VoxelCard(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: birthDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
              lastDate: DateTime.now(),
            );
            if (picked != null) onBirthDate(picked);
          },
          child: Row(children: [
            Icon(Icons.cake_outlined, color: LivyColors.coral),
            const SizedBox(width: LivySpace.md),
            Text(
              'Born ${birthDate.month}/${birthDate.day}/${birthDate.year}',
              style: LivyType.body(size: 15),
            ),
            const Spacer(),
            Icon(Icons.edit_calendar_outlined, color: LivyColors.faint, size: 20),
          ]),
        ),
        const SizedBox(height: LivySpace.xl),
        VoxelButton(label: 'Continue', icon: Icons.arrow_forward_rounded, onPressed: onNext),
        TextButton(
          onPressed: () => _joinWithCode(context),
          child: const Text('Have an invite code? Join a household instead'),
        ),
      ],
    );
  }

  /// Invited caregivers skip setup entirely: enter the code, land in the
  /// household. No subscription needed on their end.
  Future<void> _joinWithCode(BuildContext context) async {
    final app = context.read<AppState>();
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: LivyColors.surfaceRaised,
        title: Text('Join a household', style: LivyType.display(size: 20)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'LIVYAB12CD'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: LivyType.body(color: LivyColors.mist))),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Join')),
        ],
      ),
    );
    if (code == null || code.isEmpty || !context.mounted) return;
    final repo = app.repository;
    final messenger = ScaffoldMessenger.of(context);
    if (repo is FirestoreRepository) {
      // Joining is three round trips after the dialog has already closed.
      // Without a visible wait, a slow connection looks exactly like the code
      // being silently swallowed.
      final navigator = Navigator.of(context, rootNavigator: true);
      var spinnerUp = true;
      void dismissSpinner() {
        if (spinnerUp) {
          spinnerUp = false;
          navigator.pop();
        }
      }

      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ));

      try {
        final ok = await repo.joinHousehold(
          inviteCode: code,
          name: app.caregiverName,
        );
        dismissSpinner();
        if (ok) {
          // _Root swaps to the main app on the next bundle, which is silent on
          // its own — mark the moment the way logging a feed is marked.
          Haptics.celebrate();
          SoundService.instance.celebration();
          messenger.showSnackBar(const SnackBar(
              content: Text('You\'re in — welcome to the household.')));
        } else {
          messenger.showSnackBar(const SnackBar(
              content:
                  Text('That code didn\'t match a household with open seats.')));
        }
      } catch (e) {
        // Anything unexpected must surface. This used to throw past an
        // unguarded await, which read to the user as the code being swallowed.
        dismissSpinner();
        messenger.showSnackBar(
            SnackBar(content: Text('Couldn\'t join that household: $e')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Joining by code needs a configured Firebase project — in demo mode, '
              'simulate caregivers from Care → Caregivers instead.')));
    }
  }
}

// ── 6 · Choose Livy's identity ──────────────────────────────────────────────

class _MascotPage extends StatelessWidget {
  const _MascotPage({
    required this.selectedId,
    required this.onSelect,
    required this.onRename,
    required this.mascotName,
    required this.onNext,
  });

  final String selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String?> onRename;
  final String? mascotName;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final selected = MascotCatalog.byId(selectedId);
    return _OnboardingScaffold(
      scrollable: true,
      children: [
        Text('Choose your everyday companion',
            textAlign: TextAlign.center, style: LivyType.display(size: 26)),
        const SizedBox(height: LivySpace.sm),
        Text(
          'Livy the granny is always here — but who keeps you company through '
          'the days and nights is yours to cast.',
          textAlign: TextAlign.center,
          style: LivyType.body(size: 14, color: LivyColors.mist),
        ),
        const SizedBox(height: LivySpace.lg),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: LivySpace.sm,
          crossAxisSpacing: LivySpace.sm,
          childAspectRatio: 0.85,
          children: [
            for (final m in MascotCatalog.all)
              VoxelCard(
                padding: const EdgeInsets.all(LivySpace.sm),
                borderColor: m.id == selectedId ? LivyColors.amber : LivyColors.outline,
                onTap: () {
                  Haptics.tap();
                  onSelect(m.id);
                },
                child: Column(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(LivyRadius.sm),
                      child: Image.asset(MascotAssetResolver.instance.resolvePose(m, MascotPose.idle),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(Icons.auto_awesome,
                              color: LivyColors.amber, size: 40)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(m.defaultName,
                      style: LivyType.body(size: 14, weight: FontWeight.w700)),
                ]),
              ),
          ],
        ),
        const SizedBox(height: LivySpace.md),
        TextField(
          decoration: InputDecoration(
              labelText: 'Give ${selected.defaultName} a nickname (optional)'),
          onChanged: (v) => onRename(v.trim().isEmpty ? null : v.trim()),
        ),
        const SizedBox(height: LivySpace.lg),
        VoxelButton(
            label: 'Adopt ${mascotName ?? selected.defaultName}',
            icon: Icons.favorite_rounded,
            onPressed: onNext),
        const SizedBox(height: LivySpace.md),
      ],
    );
  }
}

// ── 7 · Schedule ────────────────────────────────────────────────────────────

class _SchedulePage extends StatelessWidget {
  const _SchedulePage({required this.minutes, required this.onChanged, required this.onNext});

  final int minutes;
  final ValueChanged<int> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final label = FeedingSchedule(intervalMinutes: minutes).intervalLabel;
    return _OnboardingScaffold(
      children: [
        Text('How often are feeds right now?',
            textAlign: TextAlign.center, style: LivyType.display(size: 26)),
        const SizedBox(height: LivySpace.sm),
        Text(
          'You set the rhythm — caregivers can propose changes, but only you approve '
          'them. Livy will notice when the real pattern drifts.',
          textAlign: TextAlign.center,
          style: LivyType.body(size: 14, color: LivyColors.mist),
        ),
        const SizedBox(height: LivySpace.xl),
        Text(label,
            textAlign: TextAlign.center,
            style:
                LivyType.data(size: 44, weight: FontWeight.w700, color: LivyColors.amber)),
        Slider(
          value: minutes.toDouble(),
          min: 90,
          max: 360,
          divisions: (360 - 90) ~/ 15,
          activeColor: LivyColors.amber,
          inactiveColor: LivyColors.surfaceSunken,
          onChanged: (v) => onChanged((v / 15).round() * 15),
        ),
        const SizedBox(height: LivySpace.xl),
        VoxelButton(label: 'Set schedule', icon: Icons.check_rounded, onPressed: onNext),
      ],
    );
  }
}

// ── 8 · Hard paywall ────────────────────────────────────────────────────────

class _PaywallPage extends StatefulWidget {
  const _PaywallPage({required this.onUnlocked, required this.babyNameController});

  final VoidCallback onUnlocked;

  /// Read at build time rather than passed as a string: the name is typed a
  /// few screens earlier, and the page widget is constructed before that.
  final TextEditingController babyNameController;

  @override
  State<_PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<_PaywallPage> {
  bool _annual = true;
  bool _busy = false;

  Future<void> _buy() async {
    setState(() => _busy = true);
    final ok = await context.read<PurchaseService>().purchase(annual: _annual);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Haptics.celebrate();
      SoundService.instance.celebration();
      widget.onUnlocked();
    } else {
      final err = context.read<PurchaseService>().lastError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err == null ? 'Purchase didn\'t complete' : 'Purchase failed: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchases = context.watch<PurchaseService>();
    final baby = widget.babyNameController.text.trim();
    return _OnboardingScaffold(
      scrollable: true,
      hero: const MascotView(mascot: MascotCatalog.granny, size: 150),
      children: [
        const SizedBox(height: LivySpace.md),
        Text(baby.isEmpty ? 'One plan, the whole household' : 'Keep $baby fed on time',
            textAlign: TextAlign.center, style: LivyType.display(size: 26)),
        const SizedBox(height: LivySpace.sm),
        Text(
          'Livy is a paid app — that\'s how she stays calm, private, and ad-free.',
          textAlign: TextAlign.center,
          style: LivyType.body(size: 14, color: LivyColors.mist),
        ),
        const SizedBox(height: LivySpace.lg),
        for (final f in const [
          'Live shared history for up to 5 caregivers',
          'The nightlight dial, streaks & badge celebrations',
          'Livy\'s gentle recommendations',
          'Formula recall alerts & pediatrician visit guides',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: LivySpace.sm),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: LivyColors.mint, size: 20),
              const SizedBox(width: LivySpace.sm),
              Expanded(child: Text(f, style: LivyType.body(size: 14))),
            ]),
          ),
        const SizedBox(height: LivySpace.md),
        Row(children: [
          Expanded(
            child: _PlanChip(
              title: 'Yearly',
              price: purchases.annualPriceLabel,
              note: 'save about 33%',
              selected: _annual,
              onTap: () => setState(() => _annual = true),
            ),
          ),
          const SizedBox(width: LivySpace.sm),
          Expanded(
            child: _PlanChip(
              title: 'Monthly',
              price: purchases.monthlyPriceLabel,
              note: 'cancel anytime',
              selected: !_annual,
              onTap: () => setState(() => _annual = false),
            ),
          ),
        ]),
        const SizedBox(height: LivySpace.lg),
        VoxelButton(
          label: _busy
              ? 'One moment…'
              : purchases.demoMode
                  ? 'Unlock (demo purchase)'
                  : purchases.hasIntroTrial
                      ? 'Start 7-day free trial'
                      : 'Unlock Livy',
          icon: Icons.lock_open_rounded,
          onPressed: _busy ? null : _buy,
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  final ok = await context.read<PurchaseService>().restore();
                  if (ok) widget.onUnlocked();
                },
          child: const Text('Restore purchase'),
        ),
        Text(
          'Caregivers you invite don\'t pay — one subscription covers the household, '
          'and joining via an invite code needs no plan at all. New subscribers get '
          '7 days free; the plan then renews automatically at the selected price '
          'until cancelled in iOS Settings.',
          textAlign: TextAlign.center,
          style: LivyType.body(size: 11, color: LivyColors.faint),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => LegalLinks.open(LegalLinks.privacyPolicy),
              child: Text('Privacy Policy',
                  style: LivyType.body(size: 12, color: LivyColors.faint)),
            ),
            Text('·', style: LivyType.body(size: 12, color: LivyColors.faint)),
            TextButton(
              onPressed: () => LegalLinks.open(LegalLinks.termsOfUse),
              child: Text('Terms of Use',
                  style: LivyType.body(size: 12, color: LivyColors.faint)),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({
    required this.title,
    required this.price,
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String price;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VoxelCard(
      onTap: onTap,
      borderColor: selected ? LivyColors.amber : LivyColors.outline,
      color: selected ? LivyColors.amber.withValues(alpha: 0.08) : LivyColors.surface,
      child: Column(children: [
        Text(title, style: LivyType.label(size: 11)),
        const SizedBox(height: 4),
        Text(price,
            style: LivyType.data(
                size: 20,
                weight: FontWeight.w700,
                color: selected ? LivyColors.amber : LivyColors.cream)),
        Text(note, style: LivyType.body(size: 11, color: LivyColors.faint)),
      ]),
    );
  }
}

// ── 9 · Notifications & finish ──────────────────────────────────────────────

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage({required this.onFinish, required this.busy});

  final VoidCallback onFinish;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return _OnboardingScaffold(
      hero: const MascotView(mascot: MascotCatalog.granny, pose: MascotPose.sleepy, size: 150),
      children: [
        const SizedBox(height: LivySpace.md),
        Text('A gentle tap when it\'s time',
            textAlign: TextAlign.center, style: LivyType.display(size: 26)),
        const SizedBox(height: LivySpace.sm),
        Text(
          'Livy lets you know when a feed comes due — quietly, and only when '
          'it matters.',
          textAlign: TextAlign.center,
          style: LivyType.body(size: 14, color: LivyColors.mist),
        ),
        const SizedBox(height: LivySpace.xl),
        VoxelButton(
          label: busy ? 'Setting up…' : 'Enable reminders & begin',
          icon: Icons.notifications_active_outlined,
          onPressed: busy
              ? null
              : () async {
                  await NotificationService.instance.requestPermission();
                  onFinish();
                },
        ),
        TextButton(
          onPressed: busy ? null : onFinish,
          child: const Text('Maybe later'),
        ),
      ],
    );
  }
}
