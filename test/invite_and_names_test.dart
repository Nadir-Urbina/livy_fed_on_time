import 'package:flutter_test/flutter_test.dart';
import 'package:livy_fed_on_time/data/app_state.dart';
import 'package:livy_fed_on_time/data/local_repository.dart';
import 'package:livy_fed_on_time/data/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('invite codes', () {
    test('are one unbroken token so a double-tap can select them', () {
      final code = makeInviteCode();
      expect(code, matches(RegExp(r'^LIVY[A-Z0-9]{6}$')));
      expect(code.contains('-'), isFalse,
          reason: 'a hyphen splits the word for iOS text selection');
      expect(code.length, 10);
    });

    test('carry no ambiguous characters', () {
      for (var i = 0; i < 200; i++) {
        final body = makeInviteCode().substring(4);
        expect(body.contains(RegExp(r'[IO01]')), isFalse,
            reason: 'I/O/0/1 are unreadable when someone reads a code aloud');
      }
    });

    test('do not embed the baby name, and differ each time', () {
      final codes = {for (var i = 0; i < 200; i++) makeInviteCode()};
      // 32^6 keyspace — 200 draws colliding would mean the RNG is broken.
      expect(codes.length, 200);
      expect(codes.any((c) => c.contains('OLIVIA')), isFalse);
    });
  });

  group('editing names after onboarding', () {
    Future<AppState> seededApp() async {
      SharedPreferences.setMockInitialValues({});
      final app = AppState(repository: LocalRepository(isDemo: true, seedDemoData: true));
      await app.init();
      return app;
    }

    test('the baby can be renamed without disturbing the invite code', () async {
      final app = await seededApp();
      final codeBefore = app.bundle!.household.inviteCode;

      await app.updateBaby(name: 'Olivia Rose');

      expect(app.bundle!.household.baby.name, 'Olivia Rose');
      expect(app.bundle!.household.inviteCode, codeBefore,
          reason: 'invites already sent out must keep working');
    });

    test('renaming the baby keeps the birth date', () async {
      final app = await seededApp();
      final born = app.bundle!.household.baby.birthDate;
      await app.updateBaby(name: 'Liv');
      expect(app.bundle!.household.baby.birthDate, born);
    });

    test('a caregiver can fix their own name', () async {
      final app = await seededApp();
      await app.renameCurrentCaregiver('Nadir');
      expect(app.caregiverName, 'Nadir');
      final me = app.bundle!.household.caregivers
          .firstWhere((c) => c.id == app.caregiverId);
      expect(me.name, 'Nadir', reason: 'the household copy must update too');
    });
  });
}
