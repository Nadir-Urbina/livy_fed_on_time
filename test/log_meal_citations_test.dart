import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livy_fed_on_time/data/app_state.dart';
import 'package:livy_fed_on_time/data/health_sources.dart';
import 'package:livy_fed_on_time/data/local_repository.dart';
import 'package:livy_fed_on_time/models/models.dart';
import 'package:livy_fed_on_time/screens/home/log_meal_sheet.dart';
import 'package:livy_fed_on_time/widgets/citations.dart';

/// App Store guideline 1.4.1, twice over: 1.0.0 (3) was rejected because the
/// solids dialog named the CDC and the AAP without linking to them, and
/// 1.0.0 (4) was rejected again because "Log a meal" still read as uncited —
/// the links were there, but only in a once-per-caregiver dialog and in a
/// footer below the save button, where nobody scrolls.
///
/// These tests hold the citations where a reviewer, and a parent, will
/// actually meet them: on the sheet itself, above the button that dismisses
/// it. Position is the assertion that matters; a passing text lookup alone is
/// what shipped last time.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final solidsSources = HealthSources.startingSolids;

  Future<AppState> seededApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // init() starts a 30s dial ticker, so every test disposes the state before
    // it ends — the binding fails a test that leaves a timer pending.
    final app =
        AppState(repository: LocalRepository(isDemo: true, seedDemoData: true));
    await app.init();
    return app;
  }

  /// Pumps a host screen whose only job is to open the meal sheet.
  Future<void> pumpSheetHost(WidgetTester tester, AppState app) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLogMealSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the one-time solids dialog links every source it names',
      (tester) async {
    final app = await seededApp(tester);
    await pumpSheetHost(tester, app);

    // The dialog makes a general health claim ("around 6 months"), so the
    // documents behind it are named, written out, and linked right there.
    expect(find.textContaining('6 months'), findsWidgets);
    for (final c in solidsSources) {
      expect(find.text(c.url), findsWidgets,
          reason: '${c.publisher} — ${c.title} is not linked in the dialog');
    }
    expect(find.text('Read the sources'), findsOneWidget);
    app.dispose();
  });

  testWidgets('the meal sheet cites its sources above the save button',
      (tester) async {
    final app = await seededApp(tester);
    // Skip the one-time dialog: a caregiver who has already seen it must still
    // find the citations, which is precisely what the rejected build got wrong.
    await app.acknowledgeDisclaimer(DisclaimerKind.solidsIntro);
    await pumpSheetHost(tester, app);

    expect(find.text('Log a meal'), findsOneWidget);

    final panel = find.byType(SourcesPanel);
    expect(panel, findsOneWidget,
        reason: 'the meal sheet must carry its citations in full');

    for (final c in solidsSources) {
      expect(find.text(c.url), findsWidgets,
          reason: '${c.publisher} — ${c.title} is not linked on the sheet');
    }

    // The heart of it: citations sit above the primary action, not below it.
    final panelY = tester.getTopLeft(panel).dy;
    final buttonY = tester.getTopLeft(find.text('Log meal')).dy;
    expect(panelY, lessThan(buttonY),
        reason: 'citations below the save button are citations nobody finds');

    // And a standing route into the full list, visible without scrolling.
    expect(find.text('Sources'), findsWidgets);
    app.dispose();
  });

  testWidgets('every source on the sheet is a real, tappable https link',
      (tester) async {
    final app = await seededApp(tester);
    await app.acknowledgeDisclaimer(DisclaimerKind.solidsIntro);
    await pumpSheetHost(tester, app);

    final refs = tester.widgetList<CitationReference>(
        find.byType(CitationReference, skipOffstage: false));
    expect(refs, hasLength(solidsSources.length));
    for (final ref in refs) {
      expect(ref.citation.url, startsWith('https://'));
      expect(ref.citation.title, isNotEmpty);
      expect(ref.citation.publisher, isNotEmpty);
    }
    app.dispose();
  });
}
