import 'package:url_launcher/url_launcher.dart';

/// Legal documents, hosted on the project's Firebase Hosting site. The same
/// URLs go into App Store Connect (privacy policy URL + EULA/Terms link on the
/// product page) — keep them in sync with `public/`.
abstract final class LegalLinks {
  static const privacyPolicy =
      'https://livy-fed-on-time.web.app/privacy.html';
  static const termsOfUse = 'https://livy-fed-on-time.web.app/terms.html';

  static Future<void> open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // A dead link should never crash a settings tap.
    }
  }
}
