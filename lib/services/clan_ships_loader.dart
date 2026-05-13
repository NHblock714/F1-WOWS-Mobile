import 'dart:async';
import '../api/wg_api.dart';
import '../analysis/mechanical_accuracy.dart';
import '../models/ship_record.dart';
import 'cache.dart';

/// 按需拉取工会所有成员的船仓 (用于工会维度/等级筛选).
/// 内存缓存 + 与 PlayerDataService 共享百科文件缓存.
class ClanShipsLoader {
  final Region region;
  final WgApi _wg;
  final Cache _cache = Cache.instance;
  Map<String, dynamic>? _encyclopedia;
  Map<String, double>? _classMeans;
  final Map<int, List<ShipRecord>> _memoryCache = {};

  ClanShipsLoader(this.region) : _wg = WgApi(region);

  Future<Map<String, dynamic>> _getEncyclopedia() async {
    if (_encyclopedia != null) return _encyclopedia!;
    final key = 'encyclopedia_${region.name}_v3';
    final cached = await _cache.get<Map<String, dynamic>>(key, const Duration(days: 3));
    if (cached != null) {
      _encyclopedia = cached;
    } else {
      final fresh = await _wg.getEncyclopedia();
      fresh.remove('__partial__');
      if (fresh.isNotEmpty) await _cache.set(key, fresh);
      _encyclopedia = Map<String, dynamic>.from(fresh);
    }
    _classMeans = computeClassAccuracyMeans(_encyclopedia!);
    return _encyclopedia!;
  }

  /// 拉所有 account_id 的船仓 (并行批量 10 个一组). 返回 {account_id: ShipRecords}.
  Future<Map<int, List<ShipRecord>>> loadAll(
    List<int> accountIds, {
    void Function(int loaded, int total)? onProgress,
  }) async {
    await _getEncyclopedia();
    final result = <int, List<ShipRecord>>{};
    int loaded = 0;
    const concurrency = 10;
    for (int i = 0; i < accountIds.length; i += concurrency) {
      final batch = accountIds.sublist(i, i + concurrency > accountIds.length
          ? accountIds.length : i + concurrency);
      final futures = batch.map((aid) => _loadOne(aid));
      final results = await Future.wait(futures);
      for (int j = 0; j < batch.length; j++) {
        result[batch[j]] = results[j];
      }
      loaded += batch.length;
      onProgress?.call(loaded, accountIds.length);
    }
    return result;
  }

  Future<List<ShipRecord>> _loadOne(int accountId) async {
    if (_memoryCache.containsKey(accountId)) return _memoryCache[accountId]!;
    // 复用 player 的 ships 文件缓存
    final key = '${region.name}_${accountId}_ships';
    List<Map<String, dynamic>>? shipsStats;
    final cached = await _cache.get<List>(key, const Duration(minutes: 5));
    if (cached != null) {
      shipsStats = cached.cast<Map<String, dynamic>>();
    } else {
      try {
        shipsStats = await _wg.getShipsStats(accountId);
        await _cache.set(key, shipsStats);
      } catch (_) {
        shipsStats = [];
      }
    }
    final records = _buildRecords(shipsStats);
    _memoryCache[accountId] = records;
    return records;
  }

  List<ShipRecord> _buildRecords(List<Map<String, dynamic>> shipsStats) {
    final records = <ShipRecord>[];
    final encyclopedia = _encyclopedia ?? const {};
    final classMeans = _classMeans ?? const {};
    for (final s in shipsStats) {
      final sid = s['ship_id'].toString();
      final meta = encyclopedia[sid];
      if (meta is! Map) continue;
      final pvp = s['pvp'] as Map?;
      if (pvp == null || (pvp['battles'] ?? 0) == 0) continue;
      final mb = (pvp['main_battery'] as Map?) ?? const {};
      final torp = (pvp['torpedoes'] as Map?) ?? const {};
      final cls = meta['type']?.toString();
      final profile = meta['default_profile'] as Map?;
      final art = profile?['artillery'] as Map<String, dynamic>?;
      final shipAcc = mechanicalAccuracy(art);
      double? hitRateFactor;
      if (shipAcc != null && cls != null && (classMeans[cls] ?? 0) > 0) {
        hitRateFactor = shipAcc / classMeans[cls]!;
      }
      final isHybrid = cls != 'AirCarrier' && cls != 'Submarine' &&
          (profile?['dive_bomber'] != null || profile?['torpedo_bomber'] != null);
      records.add(ShipRecord(
        shipId: sid,
        name: meta['name']?.toString() ?? 'ship_$sid',
        tier: (meta['tier'] as num?)?.toInt() ?? 0,
        type: cls ?? 'Cruiser',
        nation: meta['nation']?.toString(),
        battles: pvp['battles'] ?? 0,
        wins: pvp['wins'] ?? 0,
        damageDealt: pvp['damage_dealt'] ?? 0,
        xp: pvp['xp'] ?? 0,
        frags: pvp['frags'] ?? 0,
        survivedBattles: pvp['survived_battles'] ?? 0,
        mainBatteryHits: mb['hits'] ?? 0,
        mainBatteryShots: mb['shots'] ?? 0,
        torpedoesHits: torp['hits'] ?? 0,
        torpedoesShots: torp['shots'] ?? 0,
        planesKilled: pvp['planes_killed'] ?? 0,
        damageScouting: pvp['damage_scouting'] ?? 0,
        shipsSpotted: pvp['ships_spotted'] ?? 0,
        artAgro: pvp['art_agro'] ?? 0,
        torpedoAgro: pvp['torpedo_agro'] ?? 0,
        maxDamageScouting: pvp['max_damage_scouting'] ?? 0,
        hitRateFactor: hitRateFactor,
        isHybrid: isHybrid,
      ));
    }
    return records;
  }

  void close() => _wg.close();
}
