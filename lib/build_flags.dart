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

/// Which shell tab to open on, and an optional screen to push over it, so a
/// capture script can reach any surface without a human tapping through.
/// Both are ignored unless [kScreenshotMode] is on.
///
///   flutter run --dart-define=SCREENSHOT_DEMO=true --dart-define=SCREENSHOT_TAB=3
///   flutter run --dart-define=SCREENSHOT_DEMO=true --dart-define=SCREENSHOT_ROUTE=recalls
///
/// Compiled out entirely when unset — these are const, so the branches are
/// tree-shaken from release builds.
const int kScreenshotTab = int.fromEnvironment('SCREENSHOT_TAB');
const String kScreenshotRoute = String.fromEnvironment('SCREENSHOT_ROUTE');
