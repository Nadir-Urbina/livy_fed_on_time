import 'package:url_launcher/url_launcher.dart';

/// Legal documents, hosted on the project's Firebase Hosting site. The same
/// URLs go into App Store Connect (privacy policy URL + EULA/Terms link on the
/// product page) — keep them in sync with `public/`.
abstract final class LegalLinks {
  static const privacyPolicy =
      'https://livy-fed-on-time.web.app/privacy.html';
  static const termsOfUse = 'https://livy-fed-on-time.web.app/terms.html';

  /// Opens [url], returning whether a browser actually took it.
  ///
  /// Citations are only citations if the link works, so this doesn't settle
  /// for one attempt: an external browser is the nicest outcome, but a device
  /// that refuses it still gets the in-app browser rather than a dead tap.
  /// Callers that can show UI use the returned value to surface the URL when
  /// every mode fails.
  static Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    const modes = [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
      LaunchMode.inAppBrowserView,
    ];
    for (final mode in modes) {
      try {
        if (await launchUrl(uri, mode: mode)) return true;
      } catch (_) {
        // Try the next mode; a dead link should never crash a tap.
      }
    }
    return false;
  }
}
