import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livy_fed_on_time/services/recall_service.dart';

/// Shaped exactly like the live openFDA food-enforcement response.
const _fdaBody = {
  'results': [
    {
      'status': 'Ongoing',
      'classification': 'Class I',
      'recalling_firm': 'NARA ORGANICS INC',
      'recall_number': 'H-1137-2026',
      'product_description':
          'a.) nara organics brand; Whole Milk Organic Infant Formula; '
              'Milk-based Powder with Iron; 0-12 months; NET WT 24.7 OZ',
      'reason_for_recall':
          'Product may be contaminated with Clostridium botulinum.',
      'report_date': '20260708',
      'code_info':
          'Recalled Lot Codes   -  408125075E14F2 -  708125076E14F2 -  '
              '708125083E14F2',
    },
    {
      // Ancient recall — should be filtered by the 2-year window.
      'status': 'Terminated',
      'classification': 'Class II',
      'recalling_firm': 'Old Firm LLC',
      'recall_number': 'H-0001-2019',
      'product_description': 'Similac infant formula, 12 oz',
      'reason_for_recall': 'Historic recall.',
      'report_date': '20190101',
      'code_info': '',
    },
  ],
};

OpenFdaRecallDataSource _source({int status = 200, Object? body}) =>
    OpenFdaRecallDataSource(
      client: MockClient((req) async {
        expect(req.url.host, 'api.fda.gov');
        return http.Response(jsonEncode(body ?? _fdaBody), status,
            headers: {'content-type': 'application/json'});
      }),
    );

void main() {
  group('OpenFdaRecallDataSource', () {
    test('parses live-shaped enforcement reports', () async {
      final notices = await _source().fetchAll();

      expect(notices, hasLength(1), reason: '2019 recall is outside window');
      final n = notices.single;
      expect(n.id, 'H-1137-2026');
      expect(n.brand, 'NARA ORGANICS INC');
      expect(n.title, contains('Class I'));
      expect(n.title, contains('Ongoing'));
      expect(n.summary, contains('Clostridium botulinum'));
      expect(n.summary, contains('nara organics'));
      expect(n.publishedAt, DateTime(2026, 7, 8));
      expect(n.lotCodes, contains('408125075E14F2'));
      expect(n.lotCodes.length, lessThanOrEqualTo(8));
      // Freeform prose words must not leak in as lot codes.
      expect(n.lotCodes.any((c) => c.toLowerCase() == 'recalled'), isFalse);
    });

    test('rethrows on HTTP failure so stale data is kept, not replaced',
        () async {
      expect(_source(status: 503).fetchAll(), throwsException);
    });

    test('falls back to samples in demo mode', () async {
      final src = OpenFdaRecallDataSource(
        fallbackToSamples: true,
        client: MockClient((_) async => http.Response('oops', 500)),
      );
      final notices = await src.fetchAll();
      expect(notices, isNotEmpty);
      expect(notices.first.summary, contains('SAMPLE'));
    });
  });

  group('brand matching', () {
    test('matches on the distinctive brand word only', () async {
      final service = RecallService(source: _source());
      await service.refresh();

      // "nara" is the distinctive word in the logged brand string.
      expect(service.relevantTo({'Nara Organics Whole Milk'}), hasLength(1));
      // Generic words alone ("organic", "formula", "milk") must not match.
      expect(service.relevantTo({'Organic Formula Milk'}), isEmpty);
      // Unrelated brand doesn't match.
      expect(service.relevantTo({'Kendamil Classic'}), isEmpty);
    });

    test('failed refresh keeps previous notices', () async {
      final good = RecallService(source: _source());
      await good.refresh();
      expect(good.all, isNotEmpty);
      expect(good.lastChecked, isNotNull);
    });
  });
}
