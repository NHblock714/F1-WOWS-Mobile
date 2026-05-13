import '../api/wg_api.dart';
import '../api/wows_numbers.dart';
import '../analysis/personal_rating.dart';
import '../analysis/benchmarks.dart';
import '../analysis/mechanical_accuracy.dart';
import '../models/player.dart';
import '../models/ship_record.dart';
import 'cache.dart';

/// 聚合一个玩家的完整数据 (player + ships + encyclopedia + PR + 战力).
class PlayerData {
  final Player player;
  final List<ShipRecord> ships;
  final double pr;
  final int battlePower;
  final double nDmg, nFrags, nWr;
  final int coveredBattles;
  final int totalBattles;

  PlayerData({
    required this.player,
    required this.ships,
    required this.pr,
    required this.battlePower,
    required this.nDmg,
    required this.nFrags,
    required this.nWr,
    required this.coveredBattles,
    required this.totalBattles,
  });
}

class PlayerDataService {
  final Region region;
  final WgApi _wg;
  final WowsNumbersApi _pr = WowsNumbersApi();
  final Cache _cache = Cache.instance;

  PlayerDataService(this.region) : _wg = WgApi(region);

  /// 拉编码百科 (3 天 TTL).
  Future<Map<String, dynamic>> _getEncyclopedia() async {
    // v3: 加入 dive_bomber/torpedo_bomber 字段 (检测航站/航巡/航驱)
    final key = 'encyclopedia_${region.name}_v3';
    final cached = await _cache.get<Map<String, dynamic>>(key, const Duration(days: 3));
    if (cached != null) return cached;
    final fresh = await _wg.getEncyclopedia();
    final isPartial = fresh.containsKey('__partial__');
    fresh.remove('__partial__');
    if (!isPartial && fresh.isNotEmpty) {
      await _cache.set(key, fresh);  // 完整才缓存; 部分数据下次仍重拉
    }
    return Map<String, dynamic>.from(fresh);
  }

  /// 拉 wows-numbers PR 期望值 (3 天 TTL, 文件缓存).
  Future<Map<String, PrExpected>> _getPrExpected() async {
    const key = 'wows_numbers_expected_v1';
    final cached = await _cache.get<Map>(key, const Duration(days: 3));
    if (cached != null) {
      return cached.map<String, PrExpected>((sid, v) {
        final m = v as Map;
        return MapEntry(sid.toString(), PrExpected(
          expectedDamage: (m['d'] as num?)?.toDouble(),
          expectedFrags: (m['f'] as num?)?.toDouble(),
          expectedWinrate: (m['w'] as num?)?.toDouble(),
        ));
      });
    }
    final fresh = await _pr.fetchExpected();
    // 压缩 key (d/f/w) 减少 JSON 体积
    final serialized = <String, Map<String, dynamic>>{
      for (final e in fresh.entries)
        e.key: {
          'd': e.value.expectedDamage,
          'f': e.value.expectedFrags,
          'w': e.value.expectedWinrate,
        },
    };
    await _cache.set(key, serialized);
    return fresh;
  }

  /// 拉玩家所有船的战绩 (5 分钟 TTL).
  Future<List<Map<String, dynamic>>> _getShipsStats(int accountId) async {
    final key = '${region.name}_${accountId}_ships';
    final cached = await _cache.get<List>(key, const Duration(minutes: 5));
    if (cached != null) {
      return cached.cast<Map<String, dynamic>>();
    }
    final fresh = await _wg.getShipsStats(accountId);
    await _cache.set(key, fresh);
    return fresh;
  }

  /// 拉玩家信息 (1 分钟 TTL).
  Future<Map<String, dynamic>> _getPlayerInfo(int accountId) async {
    final key = '${region.name}_${accountId}_info';
    final cached = await _cache.get<Map<String, dynamic>>(key, const Duration(minutes: 1));
    if (cached != null) return cached;
    final fresh = await _wg.getPlayer(accountId);
    await _cache.set(key, fresh);
    return fresh;
  }

  Future<PlayerData> load(int accountId, void Function(String)? onProgress) async {
    onProgress?.call('获取玩家信息 ...');
    final info = await _getPlayerInfo(accountId);
    final player = Player.fromApi(info);

    if (player.hidden) {
      return PlayerData(player: player, ships: [], pr: 0, battlePower: 0,
          nDmg: 0, nFrags: 0, nWr: 0, coveredBattles: 0, totalBattles: 0);
    }

    onProgress?.call('获取战舰数据 + 全服 PR + 成就 ...');
    final results = await Future.wait([
      _getShipsStats(accountId),
      _getEncyclopedia(),
      _getPrExpected(),
      _wg.getAchievements(accountId).catchError((_) => <String, int>{}),
    ]);
    final shipsStats = results[0] as List<Map<String, dynamic>>;
    final encyclopedia = results[1] as Map<String, dynamic>;
    final expected = results[2] as Map<String, PrExpected>;
    final achievements = results[3] as Map<String, int>;
    if (player.stats != null) player.stats!.achievements = achievements;

    onProgress?.call('合并战舰数据 ...');
    final classMeans = computeClassAccuracyMeans(encyclopedia);
    final records = <ShipRecord>[];
    for (final s in shipsStats) {
      final sid = s['ship_id'].toString();
      final meta = encyclopedia[sid];
      if (meta == null) continue;
      final pvp = s['pvp'] as Map?;
      if (pvp == null || (pvp['battles'] ?? 0) == 0) continue;
      final mb = (pvp['main_battery'] as Map?) ?? {};
      final torp = (pvp['torpedoes'] as Map?) ?? {};
      final exp = expected[sid];
      final images = (meta['images'] as Map?) ?? {};
      // 机械精度修正因子
      final profile = meta['default_profile'] as Map?;
      final art = profile?['artillery'] as Map<String, dynamic>?;
      final shipAcc = mechanicalAccuracy(art);
      final cls = meta['type']?.toString();
      double? hitRateFactor;
      if (shipAcc != null && cls != null && (classMeans[cls] ?? 0) > 0) {
        hitRateFactor = shipAcc / classMeans[cls]!;
      }
      // 航站/航巡/航驱: 非 CV/Sub 但 default_profile 有飞机
      final isHybrid = cls != 'AirCarrier' && cls != 'Submarine'
          && (profile?['dive_bomber'] != null || profile?['torpedo_bomber'] != null);
      records.add(ShipRecord(
        shipId: sid,
        name: meta['name']?.toString() ?? 'ship_$sid',
        tier: (meta['tier'] as num?)?.toInt() ?? 0,
        type: meta['type']?.toString() ?? 'Cruiser',
        nation: meta['nation']?.toString(),
        isPremium: meta['is_premium'] == true,
        imageContour: images['contour']?.toString(),
        imageSmall: images['small']?.toString(),
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
        expectedDamage: exp?.expectedDamage,
        expectedFrags: exp?.expectedFrags,
        expectedWinrate: exp?.expectedWinrate,
        hitRateFactor: hitRateFactor,
        isHybrid: isHybrid,
      ));
    }

    onProgress?.call('计算战力 ...');
    double totalNDmg = 0, totalNFrags = 0, totalNWr = 0, totalB = 0;
    for (final r in records) {
      if (r.nDmg == null) continue;
      final b = r.battles.toDouble();
      totalB += b;
      totalNDmg += r.nDmg! * b;
      totalNFrags += r.nFrags! * b;
      totalNWr += r.nWr! * b;
    }
    double pr = 0;
    if (totalB > 0) {
      pr = computePr(totalNDmg / totalB, totalNFrags / totalB, totalNWr / totalB);
    }
    // 等级难度修正
    double tierDiff = _tierDifficulty(records);
    pr = pr * tierDiff;
    final battlePower = computeBattlePower(pr);

    return PlayerData(
      player: player, ships: records,
      pr: pr, battlePower: battlePower,
      nDmg: totalB > 0 ? totalNDmg / totalB : 0,
      nFrags: totalB > 0 ? totalNFrags / totalB : 0,
      nWr: totalB > 0 ? totalNWr / totalB : 0,
      coveredBattles: totalB.toInt(),
      totalBattles: records.fold(0, (a, r) => a + r.battles),
    );
  }

  /// 按场次加权计算等级难度系数.
  double _tierDifficulty(List<ShipRecord> records) {
    if (records.isEmpty) return 1.0;
    double total = 0, weighted = 0;
    for (final r in records) {
      final d = Benchmarks.tierDifficulty[r.tier] ?? 1.0;
      total += r.battles;
      weighted += r.battles * d;
    }
    return total > 0 ? weighted / total : 1.0;
  }

  /// 找战力最高的船 (本命战舰).
  ShipRecord? ace() {
    // Caller passes records; helper not used here, just for reference
    return null;
  }

  void close() {
    _wg.close();
    _pr.close();
  }
}
