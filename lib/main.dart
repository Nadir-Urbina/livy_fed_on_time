import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'build_flags.dart';
import 'data/app_state.dart';
import 'data/firestore_repository.dart';
import 'data/local_repository.dart';
import 'data/repository.dart';
import 'firebase_options.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/shell.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'theme/theme.dart';
import 'theme/theme_controller.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Time-adaptive theme: sunny day → golden dusk → indigo night.
  final themeController = await ThemeController.create();

  // ── Backend detection ──────────────────────────────────────────────────────
  // Firebase configured → real multi-caregiver sync. Anything missing → the
  // clearly-labeled demo mode with seeded sample data. Never hang, never blank.
  var firebaseAvailable = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseAvailable = true;
  } catch (_) {
    firebaseAvailable = false;
  }
  // Marketing-screenshot builds run the seeded demo household regardless.
  if (kScreenshotMode) firebaseAvailable = false;

  LivyRepository repository;
  if (firebaseAvailable && FirebaseAuth.instance.currentUser != null) {
    final user = FirebaseAuth.instance.currentUser!;
    repository = FirestoreRepository(
      uid: user.uid,
      displayName: user.displayName ?? 'You',
    );
  } else {
    // Demo/local mode (also the pre-auth state when Firebase exists but no one
    // is signed in yet; onboarding upgrades to Firestore after sign-in).
    repository = LocalRepository(isDemo: !firebaseAvailable, seedDemoData: !firebaseAvailable);
  }

  final appState = AppState(repository: repository);
  await appState.init();

  final purchases = PurchaseService(demoMode: !firebaseAvailable);
  await purchases.init();
  // Already signed in from a previous launch — re-attach the RevenueCat
  // customer to the Firebase uid before the gate is evaluated.
  if (firebaseAvailable && FirebaseAuth.instance.currentUser != null) {
    await purchases.identify(FirebaseAuth.instance.currentUser!.uid);
  }

  await NotificationService.instance.init();

  runApp(LivyApp(
    appState: appState,
    purchases: purchases,
    themeController: themeController,
  ));
}

class LivyApp extends StatelessWidget {
  const LivyApp({
    super.key,
    required this.appState,
    required this.purchases,
    required this.themeController,
  });

  final AppState appState;
  final PurchaseService purchases;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: purchases),
        ChangeNotifierProvider.value(value: themeController),
      ],
      // Rebuild the whole tree when the phase flips (a few times a day).
      child: AnimatedBuilder(
        animation: themeController,
        builder: (context, _) {
          final dark = LivyColors.brightness == Brightness.dark;
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          ));
          return MaterialApp(
            title: 'Livy — Fed On Time',
            debugShowCheckedModeBanner: false,
            theme: buildLivyTheme(),
            color: LivyColors.night,
            home: KeyedSubtree(
              key: ValueKey(LivyColors.phase),
              child: const _Root(),
            ),
          );
        },
      ),
    );
  }
}

/// Routes between the hard paywall + onboarding and the main app.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final purchases = context.watch<PurchaseService>();

    // The seeded demo household ships "unlocked" so the app is instantly
    // demonstrable; a fresh household walks the full onboarding + paywall.
    // Invited caregivers are covered by the account holder's plan, so they
    // need a household but never an entitlement of their own.
    final ready = app.hasHousehold &&
        (purchases.hasHouseholdAccess || app.isDemo || app.isInvitedMember);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      child: ready
          ? const MainShell(key: ValueKey('shell'))
          : const OnboardingFlow(key: ValueKey('onboarding')),
    );
  }
}
