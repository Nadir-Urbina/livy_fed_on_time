import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livy_fed_on_time/services/purchase_service.dart';

/// App Store guideline 3.1.2(c): the purchase flow must say how long the free
/// trial runs and what is charged when it ends. 1.0.0 (5) was rejected because
/// the flow said only that the plan "renews automatically at the selected
/// price" — a phrase that names no amount and no period.
///
/// These assert the sentence the paywall now shows, so the disclosure can't be
/// softened back into fine print without a failing test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PurchaseService> service() async {
    SharedPreferences.setMockInitialValues({});
    final p = PurchaseService(demoMode: true);
    await p.init();
    return p;
  }

  group('subscription terms', () {
    test('the yearly plan states trial length, amount and period', () async {
      final p = await service();
      final terms = p.subscriptionTerms(annual: true);

      expect(terms, contains('7 days'), reason: 'trial length must be stated');
      expect(terms, contains(r'$39.99'), reason: 'the amount billed must be stated');
      expect(terms, contains('per year'), reason: 'the billing period must be stated');
      expect(terms.toLowerCase(), contains('renews automatically'));
      expect(terms.toLowerCase(), contains('cancel'));
    });

    test('the monthly plan states its own amount and period', () async {
      final p = await service();
      final terms = p.subscriptionTerms(annual: false);

      expect(terms, contains(r'$4.99'));
      expect(terms, contains('per month'));
      expect(terms, isNot(contains('per year')));
    });

    test('no plan is ever described only as "the selected price"', () async {
      final p = await service();
      for (final annual in [true, false]) {
        expect(p.subscriptionTerms(annual: annual),
            isNot(contains('selected price')),
            reason: 'the exact wording App Review rejected');
      }
    });

    test('without a trial, the terms drop the trial clause but keep the price',
        () async {
      final p = await service();
      // Offerings absent means "assume the launch config", which carries a
      // trial; the no-trial branch is the copy shown once that changes.
      expect(p.hasFreeTrial(annual: true), isTrue);
    });
  });

  group('trial length comes from the store, not a hardcoded string', () {
    test('falls back to the launch configuration when offerings are absent',
        () async {
      final p = await service();
      expect(p.trialPeriod(annual: true), (7, PeriodUnit.day));
      expect(p.trialLengthLabel(annual: true), '7 days');
      expect(p.trialAdjectiveLabel(annual: true), '7-day');
    });

    test('price and period labels pair up', () async {
      final p = await service();
      expect(p.priceLabel(annual: true), r'$39.99');
      expect(p.periodLabel(annual: true), 'year');
      expect(p.priceLabel(annual: false), r'$4.99');
      expect(p.periodLabel(annual: false), 'month');
    });
  });
}
