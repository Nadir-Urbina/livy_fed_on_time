import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/demo_seed.dart';
import '../models/models.dart';

/// Swappable recall-feed layer. `OpenFdaRecallDataSource` is the production
/// source (live U.S. FDA enforcement reports); `MockRecallDataSource` remains
/// for tests and as the offline fallback in demo mode.
abstract class RecallDataSource {
  Future<List<RecallNotice>> fetchAll();
}

/// Live infant-formula recalls from the openFDA food-enforcement API.
/// No API key required at this volume (240 requests/minute per IP); each
/// device refreshes once per app session.
/// Docs: https://open.fda.gov/apis/food/enforcement/
class OpenFdaRecallDataSource implements RecallDataSource {
  OpenFdaRecallDataSource({this.fallbackToSamples = false, http.Client? client})
      : _client = client ?? http.Client();

  /// Demo mode only: serve the clearly-labeled sample notices when the
  /// network is unavailable, so the screen stays demonstrable offline.
  final bool fallbackToSamples;
  final http.Client _client;

  static const _endpoint = 'https://api.fda.gov/food/enforcement.json';

  /// Recalls older than this are noise for a current formula shelf.
  static const _maxAge = Duration(days: 730);

  @override
  Future<List<RecallNotice>> fetchAll() async {
    try {
      final uri = Uri.parse(
          '$_endpoint?search=product_description:"infant formula"'
          '&sort=report_date:desc&limit=50');
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw http.ClientException('openFDA HTTP ${res.statusCode}');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (body['results'] as List? ?? const [])
          .cast<Map<String, dynamic>>();

      final cutoff = DateTime.now().subtract(_maxAge);
      return results
          .map(_toNotice)
          .whereType<RecallNotice>()
          .where((n) => n.publishedAt.isAfter(cutoff))
          .toList();
    } catch (_) {
      if (fallbackToSamples) return buildDemoRecalls(DateTime.now());
      rethrow;
    }
  }

  RecallNotice? _toNotice(Map<String, dynamic> r) {
    final id = r['recall_number'] as String? ?? r['event_id'] as String?;
    if (id == null) return null;

    final firm = (r['recalling_firm'] as String? ?? 'Unknown firm').trim();
    final classification = r['classification'] as String? ?? 'Recall';
    final status = r['status'] as String? ?? '';
    final reason = (r['reason_for_recall'] as String? ?? '').trim();
    final description = (r['product_description'] as String? ?? '').trim();

    return RecallNotice(
      id: id,
      brand: firm,
      title:
          '$classification recall${status.isEmpty ? '' : ' · $status'} — $firm',
      summary: [
        if (reason.isNotEmpty) reason,
        if (description.isNotEmpty) 'Products: ${_truncate(description, 320)}',
      ].join('\n\n'),
      publishedAt: _parseFdaDate(r['report_date'] as String?),
      lotCodes: _parseLotCodes(r['code_info'] as String?),
      link: 'https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts',
    );
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  /// FDA dates are yyyyMMdd strings.
  static DateTime _parseFdaDate(String? s) {
    if (s == null || s.length != 8) return DateTime.now();
    return DateTime(
          int.tryParse(s.substring(0, 4)) ?? 2000,
          int.tryParse(s.substring(4, 6)) ?? 1,
          int.tryParse(s.substring(6, 8)) ?? 1,
        );
  }

  /// `code_info` is freeform ("Recalled Lot Codes - 408125075E14F2 - …");
  /// keep the tokens that look like lot codes, capped so the UI stays tidy.
  static List<String> _parseLotCodes(String? raw) {
    if (raw == null) return const [];
    final tokens = raw.split(RegExp(r'[\s,;]+'));
    final codes = <String>[];
    for (final t in tokens) {
      final clean = t.replaceAll(RegExp(r'^[-–—]+|[-–—]+$'), '');
      final hasDigit = clean.contains(RegExp(r'\d'));
      if (clean.length >= 5 && clean.length <= 20 && hasDigit) {
        codes.add(clean);
        if (codes.length >= 8) break;
      }
    }
    return codes;
  }
}

class MockRecallDataSource implements RecallDataSource {
  @override
  Future<List<RecallNotice>> fetchAll() async {
    // Simulated network latency so the refresh UX is honest.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return buildDemoRecalls(DateTime.now());
  }
}

class RecallService {
  RecallService({RecallDataSource? source})
      : _source = source ?? OpenFdaRecallDataSource(fallbackToSamples: true);

  final RecallDataSource _source;

  List<RecallNotice> _all = const [];
  DateTime? _lastChecked;

  List<RecallNotice> get all => _all;
  DateTime? get lastChecked => _lastChecked;

  Future<void> refresh() async {
    // On failure, keep whatever we had; lastChecked only advances on success
    // so the UI's "last checked" line stays honest.
    _all = await _source.fetchAll();
    _lastChecked = DateTime.now();
  }

  /// Notices whose text mentions one of the household's logged formula
  /// brands. Matches on each brand's distinctive leading word ("Similac",
  /// "Kendamil") against the notice's firm name, title, and summary —
  /// generic words like "total" or "care" are ignored to avoid false hits.
  List<RecallNotice> relevantTo(Set<String> loggedBrands) {
    final tokens = <String>{};
    for (final b in loggedBrands) {
      final words = b.toLowerCase().split(RegExp(r'[^a-z]+'));
      for (final w in words) {
        if (w.length >= 4 && !_genericWords.contains(w)) {
          tokens.add(w);
          break; // the first distinctive word is the brand name
        }
      }
    }
    if (tokens.isEmpty) return const [];
    return _all.where((n) {
      final haystack = '${n.brand} ${n.title} ${n.summary}'.toLowerCase();
      return tokens.any(haystack.contains);
    }).toList();
  }

  static const _genericWords = {
    'baby', 'infant', 'formula', 'organic', 'total', 'care', 'milk',
    'powder', 'sensitive', 'gentle', 'stage', 'brand', 'classic',
  };
}
