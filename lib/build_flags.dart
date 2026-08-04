/// Build-time flags.
///
/// `SCREENSHOT_DEMO` forces the seeded local demo household (rich sample
/// history) and hides demo badges — used only for capturing App Store
/// marketing screenshots:
///
///   flutter build ios --simulator --dart-define=SCREENSHOT_DEMO=true
///
/// Defaults to false; release builds are unaffected.
const bool kScreenshotMode = bool.fromEnvironment('SCREENSHOT_DEMO');
