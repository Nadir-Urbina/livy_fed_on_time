import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:livy_fed_on_time/data/app_state.dart';
import 'package:livy_fed_on_time/data/demo_seed.dart';
import 'package:livy_fed_on_time/data/local_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The onboarding paywall moved to the end of the flow, which finally makes
/// the invite-code path reachable. `_Root` grants entry on
/// `hasHouseholdAccess || isDemo || isInvitedMember`, so `isInvitedMember` is
/// now load-bearing in both directions: too strict locks out the caregivers a
/// subscriber invited, too loose hands out the app for free.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Seeds the demo household with `demo-you` given [role], the way the
  /// repository would have persisted it.
  Future<AppState> stateWithSelfRole(String role) async {
    final json = buildDemoBundle().toJson();
    final household = json['household'] as Map<String, dynamic>;
    final caregivers = (household['caregivers'] as List).cast<Map<String, dynamic>>();
    for (final c in caregivers) {
      if (c['id'] == 'demo-you') c['role'] = role;
    }
    SharedPreferences.setMockInitialValues({
      'livy.bundle.v1': jsonEncode(json),
      'livy.caregiverId': 'demo-you',
      'livy.caregiverName': 'You',
    });
    final app = AppState(repository: LocalRepository(isDemo: true));
    await app.init();
    return app;
  }

  test('the account holder is not treated as an invited member', () async {
    final app = await stateWithSelfRole('accountHolder');
    expect(app.hasHousehold, isTrue);
    expect(app.isAccountHolder, isTrue);
    // Would otherwise be a free pass around the paywall for the buyer's own
    // device — harmless here, but it must come from the entitlement instead.
    expect(app.isInvitedMember, isFalse);
  });

  test('a caregiver invited into the household needs no entitlement', () async {
    final app = await stateWithSelfRole('caregiver');
    expect(app.hasHousehold, isTrue);
    expect(app.isAccountHolder, isFalse);
    expect(app.isInvitedMember, isTrue);
  });

  test('a household with no record of this device grants nothing', () async {
    // The bypass risk: an absent caregiver record must not read as "invited".
    final json = buildDemoBundle().toJson();
    final household = json['household'] as Map<String, dynamic>;
    (household['caregivers'] as List).removeWhere(
        (c) => (c as Map<String, dynamic>)['id'] == 'demo-you');
    SharedPreferences.setMockInitialValues({
      'livy.bundle.v1': jsonEncode(json),
      'livy.caregiverId': 'demo-you',
      'livy.caregiverName': 'You',
    });
    final app = AppState(repository: LocalRepository(isDemo: true));
    await app.init();

    expect(app.hasHousehold, isTrue);
    expect(app.isInvitedMember, isFalse);
  });
}
