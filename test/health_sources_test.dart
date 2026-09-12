import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:livy_fed_on_time/data/health_sources.dart';
import 'package:livy_fed_on_time/screens/guide/sources_screen.dart';

/// App Store guideline 1.4.1 requires the general health information Livy
/// shows to carry findable citations. These guard the catalog behind that:
/// a dead-looking entry here is a rejection, not a lint.
void main() {
  final all = HealthSources.groups.expand((g) => g.citations).toList();

  group('health citation catalog', () {
    test('every group has sources, and every source is complete', () {
      expect(HealthSources.groups, isNotEmpty);
      for (final group in HealthSources.groups) {
        expect(group.citations, isNotEmpty, reason: '${group.topic} has none');
        expect(group.blurb, isNotEmpty);
      }
      for (final c in all) {
        expect(c.publisher, isNotEmpty);
        expect(c.title, isNotEmpty);
        expect(c.covers, isNotEmpty);
      }
    });

    test('every URL is an absolute https link to a named publisher', () {
      for (final c in all) {
        final uri = Uri.tryParse(c.url);
        expect(uri, isNotNull, reason: '${c.title} has an unparseable URL');
        expect(uri!.scheme, 'https', reason: '${c.title} is not https');
        expect(uri.host, isNotEmpty);
        expect(uri.host, isNot(contains(' ')),
            reason: '${c.title} URL was wrapped mid-host across string lines');
        expect(c.host, isNot(startsWith('www.')));
      }
    });

    test('no duplicate links across groups', () {
      final urls = all.map((c) => c.url).toList();
      expect(urls.toSet().length, urls.length);
    });

    test('the sources the solids flow cites are the CDC and the AAP', () {
      final publishers =
          HealthSources.startingSolids.map((c) => c.publisher).toSet();
      expect(publishers, containsAll(<String>['CDC', 'AAP']));
    });
  });

  testWidgets('the sources screen lists every citation with its link',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SourcesScreen()));
    await tester.pumpAndSettle();

    // The list builds lazily, so scroll the whole page and collect what
    // renders on the way down.
    final seenUrls = <String>{};
    final seenTopics = <String>{};
    for (var i = 0; i < 20; i++) {
      for (final c in all) {
        if (find.text(c.url).evaluate().isNotEmpty) seenUrls.add(c.url);
      }
      for (final g in HealthSources.groups) {
        if (find.text(g.topic).evaluate().isNotEmpty) seenTopics.add(g.topic);
      }
      if (seenUrls.length == all.length &&
          seenTopics.length == HealthSources.groups.length) {
        break;
      }
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(seenTopics.length, HealthSources.groups.length,
        reason: 'a topic heading never rendered');
    expect(seenUrls.length, all.length,
        reason: 'not every citation URL is visible on the sources screen');
  });
}
