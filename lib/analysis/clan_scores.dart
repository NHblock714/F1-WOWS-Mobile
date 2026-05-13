import '../models/clan.dart';
import '../models/ship_record.dart';
import 'benchmarks.dart';
import 'scoring.dart';

/// 工会战力雷达 9 轴 (与玩家 8 轴一致 + 隐藏🐴比例).
///
/// 工会成员舰种构成混杂, 用 base 阈值绝对评分 (不做 class/tier 修正).
Map<String, (double raw, double score)> computeClanRadarScores(ClanData clan) {
  if (clan.totalBattles == 0) return {};
  final scores = <String, (double, double)>{};

  void add(String label, String metricKey, double value) {
    final base = Benchmarks.base[metricKey];
    if (base == null) return;
    scores[label] = (value, scoreValue(value, base));
  }

  // 与玩家总览雷达保持一致的 8 轴
  add('胜率', 'win_rate', clan.avgWinRate);
  add('场均伤害', 'avg_damage', clan.avgDamage);
  add('场均经验', 'avg_xp', clan.avgXp);
  add('击杀效率', 'kd_ratio', clan.kdRatio);
  add('主炮命中', 'main_battery_hit_rate', clan.mainBatteryHitRate);
  add('场均抗伤', 'avg_potential_damage', clan.avgPotentialDamage);
  add('场均侦查', 'avg_scouting_damage', clan.avgScoutingDamage);

  // 平均场次: 活跃度指标 (S 阈值 = 10000 场/人)
  final avgB = clan.avgBattlesPerMember;
  final avgBScore = scoreValue(avgB, [1000, 3000, 5000, 7500, 10000]);
  scores['平均场次'] = (avgB, avgBScore);

  // 隐藏🐴比例
  // 显示值 = 隐藏比例 (越高越差); 评分用 (1 - 隐藏比例) 走 score_value
  final hiddenRatio = clan.hiddenHorseRatio;
  final visible = 1 - hiddenRatio;
  final hiddenScore = scoreValue(visible, [0.60, 0.75, 0.85, 0.92, 0.97]);
  scores['隐藏🐴'] = (hiddenRatio, hiddenScore);

  return scores;
}

/// 工会综合 PR-like 值 (0-2500 区间), 平均雷达分映射.
double computeClanFleetPower(ClanData clan) {
  final s = computeClanRadarScores(clan);
  if (s.isEmpty) return 0;
  final avg = s.values.fold<double>(0, (a, v) => a + v.$2) / s.length;
  return avg / 130.0 * 2500.0;
}

/// 按维度(class)/等级(tier)筛选后, 重算工会雷达 (成员等权重平均).
/// memberShips: {account_id: 该成员所有船的 ShipRecord 列表}
Map<String, (double, double)> computeClanRadarScoresFiltered(
  ClanData clan,
  Map<int, List<ShipRecord>> memberShips,
  String? filterClass,
  int? filterTier,
) {
  // 对每个活跃成员, 用其筛选后的船仓聚合出该成员的"筛选战绩"
  // 然后再做成员等权重平均
  final perMember = <Map<String, double>>[];
  for (final m in clan.activeMembers) {
    final ships = memberShips[m.accountId];
    if (ships == null || ships.isEmpty) continue;
    var filtered = ships;
    if (filterClass != null) filtered = filtered.where((s) => s.type == filterClass).toList();
    if (filterTier != null) filtered = filtered.where((s) => s.tier == filterTier).toList();
    if (filtered.isEmpty) continue;
    final b = filtered.fold<int>(0, (a, s) => a + s.battles);
    if (b == 0) continue;
    final w = filtered.fold<int>(0, (a, s) => a + s.wins);
    final d = filtered.fold<int>(0, (a, s) => a + s.damageDealt);
    final x = filtered.fold<int>(0, (a, s) => a + s.xp);
    final f = filtered.fold<int>(0, (a, s) => a + s.frags);
    final sv = filtered.fold<int>(0, (a, s) => a + s.survivedBattles);
    final mbH = filtered.fold<int>(0, (a, s) => a + s.mainBatteryHits);
    final mbS = filtered.fold<int>(0, (a, s) => a + s.mainBatteryShots);
    final pot = filtered.fold<int>(0, (a, s) => a + s.artAgro + s.torpedoAgro);
    final sc = filtered.fold<int>(0, (a, s) => a + s.damageScouting);
    final deaths = b - sv;
    perMember.add({
      'battles': b.toDouble(),
      'win_rate': w / b,
      'avg_damage': d / b,
      'avg_xp': x / b,
      'avg_frags': f / b,
      'kd_ratio': deaths <= 0 ? f.toDouble() : f / deaths,
      'main_battery_hit_rate': mbS > 0 ? mbH / mbS : 0,
      'avg_potential_damage': pot / b,
      'avg_scouting_damage': sc / b,
    });
  }

  if (perMember.isEmpty) return {};
  double mean(String k) =>
      perMember.fold<double>(0, (a, m) => a + (m[k] ?? 0)) / perMember.length;

  // 阈值修正: thresholds = base × class_factor × tier_factor.
  // filterClass 为 null 时 cf=1.0; filterTier 为 null 时 tf=1.0.
  // class_factor = null 表示该舰种不适用该指标 (例: CV/Sub 不算主炮命中), 跳过.
  final scores = <String, (double, double)>{};
  void add(String label, String metricKey, double value) {
    final base = Benchmarks.base[metricKey];
    if (base == null) return;
    double cf = 1.0;
    if (filterClass != null) {
      final v = Benchmarks.classFactor(filterClass, metricKey);
      if (v == null) return; // 该舰种该指标不适用
      cf = v;
    }
    final tf = filterTier != null ? Benchmarks.tierFactor(metricKey, filterTier) : 1.0;
    final thresholds = base.map((b) => b * cf * tf).toList();
    scores[label] = (value, scoreValue(value, thresholds));
  }
  add('胜率', 'win_rate', mean('win_rate'));
  add('场均伤害', 'avg_damage', mean('avg_damage'));
  add('场均经验', 'avg_xp', mean('avg_xp'));
  add('击杀效率', 'kd_ratio', mean('kd_ratio'));
  add('主炮命中', 'main_battery_hit_rate', mean('main_battery_hit_rate'));
  add('场均抗伤', 'avg_potential_damage', mean('avg_potential_damage'));
  add('场均侦查', 'avg_scouting_damage', mean('avg_scouting_damage'));

  // 平均场次阈值按筛选范围缩放: 选了类/级后场次自然变少, 不缩放会全员 D.
  // 经验值: T10 占总约 30-35%, 驱逐占约 25%, T10 驱逐约 6-10%.
  final double bScale;
  if (filterClass != null && filterTier != null) {
    bScale = 1 / 15.0;
  } else if (filterClass != null) {
    bScale = 1 / 4.0;
  } else if (filterTier != null) {
    bScale = 1 / 3.0;
  } else {
    bScale = 1.0;
  }
  final bBase = [1000.0, 3000.0, 5000.0, 7500.0, 10000.0];
  final bThresholds = bBase.map((v) => v * bScale).toList();
  final avgB = mean('battles');
  scores['平均场次'] = (avgB, scoreValue(avgB, bThresholds));

  // 隐藏🐴 是工会整体指标, 跟筛选范围无关, 筛选时不显示.
  return scores;
}

double computeClanFleetPowerFromScores(Map<String, (double, double)> scores) {
  if (scores.isEmpty) return 0;
  final avg = scores.values.fold<double>(0, (a, v) => a + v.$2) / scores.length;
  return avg / 130.0 * 2500.0;
}

/// 单成员在筛选范围内的综合分 (与工会雷达同套阈值/算法).
/// 返回 null 表示该成员在此范围内 0 场.
({int battles, double winRate, double score})? computeMemberFilteredScore(
  List<ShipRecord>? ships,
  String? filterClass,
  int? filterTier,
) {
  if (ships == null || ships.isEmpty) return null;
  var filtered = ships;
  if (filterClass != null) filtered = filtered.where((s) => s.type == filterClass).toList();
  if (filterTier != null) filtered = filtered.where((s) => s.tier == filterTier).toList();
  if (filtered.isEmpty) return null;
  final b = filtered.fold<int>(0, (a, s) => a + s.battles);
  if (b == 0) return null;
  final w = filtered.fold<int>(0, (a, s) => a + s.wins);
  final d = filtered.fold<int>(0, (a, s) => a + s.damageDealt);
  final x = filtered.fold<int>(0, (a, s) => a + s.xp);
  final f = filtered.fold<int>(0, (a, s) => a + s.frags);
  final sv = filtered.fold<int>(0, (a, s) => a + s.survivedBattles);
  final mbH = filtered.fold<int>(0, (a, s) => a + s.mainBatteryHits);
  final mbS = filtered.fold<int>(0, (a, s) => a + s.mainBatteryShots);
  final pot = filtered.fold<int>(0, (a, s) => a + s.artAgro + s.torpedoAgro);
  final sc = filtered.fold<int>(0, (a, s) => a + s.damageScouting);
  final deaths = b - sv;

  final metrics = <String, double>{
    'win_rate': w / b,
    'avg_damage': d / b,
    'avg_xp': x / b,
    'kd_ratio': deaths <= 0 ? f.toDouble() : f / deaths,
    'main_battery_hit_rate': mbS > 0 ? mbH / mbS : 0,
    'avg_potential_damage': pot / b,
    'avg_scouting_damage': sc / b,
  };

  final scoreList = <double>[];
  for (final entry in metrics.entries) {
    final base = Benchmarks.base[entry.key];
    if (base == null) continue;
    double cf = 1.0;
    if (filterClass != null) {
      final v = Benchmarks.classFactor(filterClass, entry.key);
      if (v == null) continue;
      cf = v;
    }
    final tf = filterTier != null ? Benchmarks.tierFactor(entry.key, filterTier) : 1.0;
    final thresholds = base.map((v) => v * cf * tf).toList();
    scoreList.add(scoreValue(entry.value, thresholds));
  }

  final avgScore = scoreList.isEmpty ? 0.0 : scoreList.fold<double>(0, (a, v) => a + v) / scoreList.length;
  return (battles: b, winRate: w / b, score: avgScore);
}
