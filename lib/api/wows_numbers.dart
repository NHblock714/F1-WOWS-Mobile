import 'dart:convert';
import 'package:http/http.dart' as http;

class PrExpected {
  final double? expectedDamage;
  final double? expectedFrags;
  final double? expectedWinrate; // 0-1

  const PrExpected({this.expectedDamage, this.expectedFrags, this.expectedWinrate});
}

class WowsNumbersApi {
  static const _url = 'https://api.wows-numbers.com/personal/rating/expected/json/';
  static const _headers = {'User-Agent': 'Mozilla/5.0 (f1-wows-mobile)'};

  final http.Client _client;
  Map<String, PrExpected>? _cache;

  WowsNumbersApi({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, PrExpected>> fetchExpected({bool force = false}) async {
    if (!force && _cache != null) return _cache!;
    final resp = await _client.get(Uri.parse(_url), headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw Exception('wows-numbers fetch failed: HTTP ${resp.statusCode}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final section = body['data'] is Map ? body['data'] as Map : body;
    final out = <String, PrExpected>{};
    section.forEach((sid, vals) {
      if (vals is! Map) return;
      out[sid.toString()] = PrExpected(
        expectedDamage: (vals['average_damage_dealt'] as num?)?.toDouble(),
        expectedFrags: (vals['average_frags'] as num?)?.toDouble(),
        expectedWinrate: ((vals['win_rate'] as num?)?.toDouble() ?? 0) / 100.0,
      );
    });
    _cache = out;
    return out;
  }

  void close() => _client.close();
}
