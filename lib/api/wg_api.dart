import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

enum Region {
  asia('https://api.worldofwarships.asia'),
  eu('https://api.worldofwarships.eu'),
  com('https://api.worldofwarships.com');

  final String baseUrl;
  const Region(this.baseUrl);

  String get displayName => switch (this) {
        Region.asia => '亚服',
        Region.eu => '欧服',
        Region.com => '美服',
      };
}

class WgApiException implements Exception {
  final String message;
  WgApiException(this.message);
  @override
  String toString() => 'WgApiException: $message';
}

class WgApi {
  final Region region;
  final String applicationId;
  final http.Client _client;

  WgApi(this.region, {http.Client? client})
      : applicationId = dotenv.env['APPLICATION_ID'] ?? '',
        _client = client ?? http.Client() {
    if (applicationId.isEmpty) {
      throw WgApiException('APPLICATION_ID 未在 .env 中设置');
    }
  }

  Future<Map<String, dynamic>> _getBody(String path, Map<String, String> params) async {
    final url = Uri.parse('${region.baseUrl}$path').replace(queryParameters: {
      'application_id': applicationId,
      ...params,
    });
    final resp = await _client.get(url).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw WgApiException('HTTP ${resp.statusCode}: ${resp.reasonPhrase}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['status'] != 'ok') {
      throw WgApiException('API error: ${body['error']}');
    }
    return body;
  }

  Future<List<Map<String, dynamic>>> searchPlayers(String nickname) async {
    final body = await _getBody('/wows/account/list/', {'search': nickname});
    final list = body['data'] as List?;
    return list?.cast<Map<String, dynamic>>() ?? [];
  }

  /// 搜索工会 (按 tag 或 name 模糊).
  Future<List<Map<String, dynamic>>> searchClans(String query) async {
    final body = await _getBody('/wows/clans/list/', {'search': query});
    final list = body['data'] as List?;
    return list?.cast<Map<String, dynamic>>() ?? [];
  }

  /// 工会详细信息 (含成员 account_id 列表).
  Future<Map<String, dynamic>?> getClanInfo(int clanId) async {
    final url = Uri.parse('${region.baseUrl}/wows/clans/info/').replace(queryParameters: {
      'application_id': applicationId,
      'clan_id': '$clanId',
      'extra': 'members',
    });
    final resp = await _client.get(url).timeout(const Duration(seconds: 15));
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['status'] != 'ok') return null;
    final data = body['data'] as Map<String, dynamic>?;
    return data?['$clanId'] as Map<String, dynamic>?;
  }

  /// 批量拉多个玩家信息 (一次最多 100 个 account_id).
  /// 返回 {account_id_str: player_info_map}.
  Future<Map<String, dynamic>> getPlayersInfoBatch(List<int> accountIds) async {
    final result = <String, dynamic>{};
    for (int i = 0; i < accountIds.length; i += 100) {
      final chunk = accountIds.sublist(i, math.min(i + 100, accountIds.length));
      final url = Uri.parse('${region.baseUrl}/wows/account/info/').replace(queryParameters: {
        'application_id': applicationId,
        'account_id': chunk.map((id) => '$id').join(','),
      });
      try {
        final resp = await _client.get(url).timeout(const Duration(seconds: 30));
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body['status'] == 'ok') {
          final data = body['data'] as Map<String, dynamic>?;
          if (data != null) result.addAll(data);
        }
      } catch (_) {
        // 单批失败跳过, 继续下一批
      }
    }
    return result;
  }

  /// 获取玩家成就 {achievement_id: count} (battle 类).
  Future<Map<String, int>> getAchievements(int accountId) async {
    final url = Uri.parse('${region.baseUrl}/wows/account/achievements/').replace(queryParameters: {
      'application_id': applicationId,
      'account_id': '$accountId',
    });
    final resp = await _client.get(url).timeout(const Duration(seconds: 15));
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['status'] != 'ok') return {};
    final data = body['data'] as Map<String, dynamic>?;
    final info = data?['$accountId'] as Map?;
    final battle = info?['battle'] as Map?;
    if (battle == null) return {};
    return battle.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  Future<Map<String, dynamic>> getPlayer(int accountId) async {
    final url = Uri.parse('${region.baseUrl}/wows/account/info/').replace(queryParameters: {
      'application_id': applicationId,
      'account_id': '$accountId',
      'extra': 'statistics.pve,statistics.rank_solo,statistics.club,statistics.oper_solo,statistics.oper_div',
    });
    final resp = await _client.get(url).timeout(const Duration(seconds: 15));
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['status'] != 'ok') {
      throw WgApiException('玩家信息获取失败: ${body['error']}');
    }
    final data = body['data'] as Map<String, dynamic>?;
    final info = data?['$accountId'];
    if (info == null) throw WgApiException('玩家 ID $accountId 不存在');
    return info as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getShipsStats(int accountId) async {
    final url = Uri.parse('${region.baseUrl}/wows/ships/stats/').replace(queryParameters: {
      'application_id': applicationId,
      'account_id': '$accountId',
    });
    final resp = await _client.get(url).timeout(const Duration(seconds: 30));
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['status'] != 'ok') {
      throw WgApiException('战舰数据获取失败: ${body['error']}');
    }
    final data = body['data'] as Map<String, dynamic>?;
    final list = data?['$accountId'] as List?;
    return list?.cast<Map<String, dynamic>>() ?? [];
  }

  /// 单次请求带指数退避重试 (3 次, 0.4s/1.2s/3.6s).
  Future<http.Response> _getWithRetry(Uri url, {int retries = 3, Duration timeout = const Duration(seconds: 20)}) async {
    Object? lastErr;
    for (int i = 0; i < retries; i++) {
      try {
        return await _client.get(url).timeout(timeout);
      } catch (e) {
        lastErr = e;
        if (i < retries - 1) {
          await Future.delayed(Duration(milliseconds: (400 * math.pow(3, i)).toInt()));
        }
      }
    }
    throw WgApiException('网络请求 $retries 次失败: $lastErr');
  }

  Future<Map<String, Map<String, dynamic>>> getEncyclopedia({String language = 'en'}) async {
    final result = <String, Map<String, dynamic>>{};
    final failedPages = <int>[];
    int page = 1;
    while (true) {
      final url = Uri.parse('${region.baseUrl}/wows/encyclopedia/ships/').replace(queryParameters: {
        'application_id': applicationId,
        'language': language,
        'page_no': '$page',
        'fields': 'name,nation,tier,type,is_premium,'
            'images.contour,images.small,'
            'default_profile.artillery,'
            'default_profile.dive_bomber,'
            'default_profile.torpedo_bomber',
      });
      try {
        final resp = await _getWithRetry(url);
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body['status'] != 'ok') break;
        final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? {};
        if (data.isEmpty) break;
        data.forEach((k, v) {
          result[k] = (v as Map).cast<String, dynamic>();
        });
        if (data.length < 100) break;
      } catch (_) {
        // 单页持续失败 → 跳过, 拿到部分百科总比全挂强
        failedPages.add(page);
      }
      page++;
      if (page > 20) break;
    }
    if (failedPages.isNotEmpty) {
      // ignore: avoid_print
      print('[encyclopedia] 跳过 ${failedPages.length} 页: $failedPages');
    }
    // 标记是否完整, 上层决定是否缓存
    if (failedPages.isNotEmpty) {
      result['__partial__'] = const {};
    }
    return result;
  }

  void close() => _client.close();
}
