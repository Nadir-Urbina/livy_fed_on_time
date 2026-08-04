import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// RevenueCat entitlement gating. Hard paywall, no free trial, one
/// subscription tier that unlocks the whole household (up to 5 caregiver
/// seats — only the account holder needs a plan).
///
/// Pricing/products are a one-line config change: edit [entitlementId] /
/// [iosApiKey] and the offering in the RevenueCat dashboard.
class PurchaseService extends ChangeNotifier {
  PurchaseService({required this.demoMode});

  /// In demo mode (no Firebase/RevenueCat config) the paywall renders fully
  /// but purchases are simulated so every flow is demonstrable.
  final bool demoMode;

  // ── Configuration (swap before ship) ──────────────────────────────────────
  static const entitlementId = 'livy_household';
  static const iosApiKey = 'appl_wvipHeGCzaUTqEYbBEFWaNyqbQo';
  static const androidApiKey = 'REVENUECAT_ANDROID_API_KEY_PLACEHOLDER';
  // ──────────────────────────────────────────────────────────────────────────

  static const _unlockPrefKey = 'livy.simulatedUnlock';

  bool _configured = false;
  bool _hasEntitlement = false;
  bool _demoUnlocked = false;
  SharedPreferences? _prefs;
  Offerings? _offerings;
  String? _lastError;

  bool get hasHouseholdAccess => demoMode
      ? _demoUnlocked
      // kDebugMode: honors the debug-only unlock used while RevenueCat is
      // unconfigured; release builds require the real entitlement.
      : (_hasEntitlement || (kDebugMode && _demoUnlocked));
  Offerings? get offerings => _offerings;
  String? get lastError => _lastError;

  Future<void> init() async {
    // Simulated unlocks (demo mode + debug builds without RevenueCat) persist
    // across restarts so testing isn't re-gated on every launch. Release
    // builds ignore this entirely.
    _prefs = await SharedPreferences.getInstance();
    _demoUnlocked = _prefs?.getBool(_unlockPrefKey) ?? false;
    if (demoMode) return;
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
      final key = defaultTargetPlatform == TargetPlatform.iOS ? iosApiKey : androidApiKey;
      await Purchases.configure(PurchasesConfiguration(key));
      _configured = true;
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
      _onCustomerInfo(await Purchases.getCustomerInfo());
      _offerings = await Purchases.getOfferings();
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  void _onCustomerInfo(CustomerInfo info) {
    _hasEntitlement = info.entitlements.active.containsKey(entitlementId);
    notifyListeners();
  }

  /// Purchases the household plan. In demo mode this simulates success so the
  /// full flow (paywall → celebration → onboarding) is demonstrable.
  Future<bool> purchase({bool annual = false}) async {
    if (demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await _setSimulatedUnlock();
      return true;
    }
    if (!_configured) {
      // Debug builds only: RevenueCat isn't configured yet (placeholder API
      // key), so simulate the unlock to keep the Firebase integration path
      // testable. Release builds keep the hard paywall — no bypass.
      if (kDebugMode) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await _setSimulatedUnlock();
        return true;
      }
      return false;
    }
    try {
      final offering = _offerings?.current;
      final package = annual
          ? (offering?.annual ?? offering?.availablePackages.firstOrNull)
          : (offering?.monthly ?? offering?.availablePackages.firstOrNull);
      if (package == null) {
        // Debug builds: RevenueCat has no offering yet (placeholder key or
        // products not configured) — simulate the unlock so the rest of the
        // app stays testable. Release builds keep the hard paywall.
        if (kDebugMode) {
          await _setSimulatedUnlock();
          return true;
        }
        _lastError = 'No packages available — check the RevenueCat offering.';
        notifyListeners();
        return false;
      }
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _onCustomerInfo(result.customerInfo);
      return _hasEntitlement;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _setSimulatedUnlock() async {
    _demoUnlocked = true;
    await _prefs?.setBool(_unlockPrefKey, true);
    notifyListeners();
  }

  Future<bool> restore() async {
    if (demoMode) {
      await _setSimulatedUnlock();
      return true;
    }
    if (!_configured) return false;
    try {
      _onCustomerInfo(await Purchases.restorePurchases());
      return _hasEntitlement;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Display prices for the paywall; live values come from the store when
  /// configured, warm defaults otherwise.
  String get monthlyPriceLabel =>
      _offerings?.current?.monthly?.storeProduct.priceString ?? r'$4.99';
  String get annualPriceLabel =>
      _offerings?.current?.annual?.storeProduct.priceString ?? r'$39.99';

  /// Whether the storefront products carry a free-trial introductory offer
  /// (the launch config includes 7 days free). When offerings haven't loaded
  /// yet (debug / RevenueCat unreachable) we assume the launch config so the
  /// paywall copy matches what App Store Connect actually sells.
  bool get hasIntroTrial {
    final o = _offerings?.current;
    final intro = o?.annual?.storeProduct.introductoryPrice ??
        o?.monthly?.storeProduct.introductoryPrice;
    if (intro == null) return o == null;
    return intro.price == 0;
  }
}
