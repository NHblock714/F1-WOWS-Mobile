import '../models/player.dart';
import '../models/ship_record.dart';
import 'benchmarks.dart';
import 'personal_rating.dart';
import 'scoring.dart';

/// 总览雷达 8 个轴 (与 PC overview_tab 一致).
const overviewAxes = [
  '胜率', '场均伤害', '🐴含量', '场均经验',
  '击杀效率', '主炮命中', '场均抗伤', '场均侦查',
];

/// metric 显示名 → PlayerStats 属性键 + 阈值/系数 metric 键.
const _metricKeys = <String, String>{
  '胜率': 'win_rate',
  '场均伤害': 'avg_damage',
  '场均经验': 'avg_xp',
  '场均击杀': 'avg_frags',
  '生存率': 'survival_rate',
  '主炮命中': 'main_battery_hit_rate',
  '场均抗伤': 'avg_potential_damage',
  '场均侦查': 'avg_scouting_damage',
  '击杀效率': 'kd_ratio',
};

/// PR-base 三轴 (用 PR 公式代替阈值法).
const _prMetrics = {'胜率', '场均伤害', '场均击杀'};

double _getStatRaw(PlayerStats s, String key) {
  return switch (key) {
    'win_rate' => s.winRate,
    'avg_damage' => s.avgDamage,
    'avg_xp' => s.avgXp,
    'avg_frags' => s.avgFrags,
    'survival_rate' => s.survivalRate,
    'main_battery_hit_rate' => s.mainBatteryHitRate,
    'avg_potential_damage' => s.avgPotentialDamage,
    'avg_scouting_damage' => s.avgScoutingDamage,
    'kd_ratio' => s.kdRatio,
    _ => 0,
  };
}

/// 计算雷达图 8 个轴的 (raw, score). 与 PC compute_scores 等价.
Map<String, (double raw, double score)> computeOverviewScores(
  PlayerStats stats,
  List<ShipRecord> ships,
  double prNDmg,
  double prNFrags,
  double prNWr,
) {
  final result = <String, (double, double)>{};

  // 各 axis 走对应公式
  for (final display in overviewAxes) {
    if (display == '🐴含量') {
      // 单舰种筛选 → 第 3 轴变成 'X场次'
      final types = ships.map((r) => r.type).toSet();
      if (types.length == 1 && ships.isNotEmpty) {
        final cls = types.first;
        final battles = ships.fold<int>(0, (a, r) => a + r.battles);
        if (battles > 0) {
          final sc = scoreValue(battles.toDouble(), const [100, 500, 1500, 3000, 5000]);
          const abbrev = {
            'Battleship': '战列', 'Cruiser': '巡洋', 'Destroyer': '驱逐',
            'AirCarrier': '航母', 'Submarine': '潜艇',
          };
          result['${abbrev[cls] ?? cls}场次'] = (battles.toDouble(), sc);
        }
        continue;
      }
      final res = _horseRatio(ships);
      if (res != null) result[display] = res;
      continue;
    }

    final metric = _metricKeys[display];
    if (metric == null) continue;
    final raw = _getStatRaw(stats, metric);

    if (_prMetrics.contains(display)) {
      // PR 公式
      final nVal = switch (display) {
        '胜率' => prNWr,
        '场均伤害' => prNDmg,
        '场均击杀' => prNFrags,
        _ => 0.0,
      };
      double sc;
      if (display == '胜率') {
        sc = (90.0 * nVal - 50.0).clamp(0.0, scorePoints.last * 1.15);
      } else {
        sc = (60.0 * nVal - 20.0).clamp(0.0, scorePoints.last * 1.15);
      }
      // 小样本置信度
      final totalB = ships.fold<int>(0, (a, r) => a + r.battles);
      if (totalB < 40) {
        sc *= 0.5 + 0.5 * ((totalB - 1).clamp(0, 39)) / 39;
      }
      result[display] = (raw, sc);
      continue;
    }

    // 等级加权评分 (避免平均的平均陷阱)
    final sc = _tierWeightedScore(metric, ships);
    if (sc != null) {
      result[display] = (raw, sc);
    } else {
      result[display] = (raw, scoreValue(raw, _classMixThresholds(metric, ships)));
    }
  }
  return result;
}

(double, double)? _horseRatio(List<ShipRecord> ships) {
  final total = ships.fold<int>(0, (a, r) => a + r.battles);
  if (total <= 0) return null;
  final cv = ships.where((r) => r.type == 'AirCarrier').fold<int>(0, (a, r) => a + r.battles);
  final sub = ships.where((r) => r.type == 'Submarine').fold<int>(0, (a, r) => a + r.battles);
  final hybrid = ships.where((r) => r.isHybrid).fold<int>(0, (a, r) => a + r.battles);
  // 显示: 纯水面舰占比 (排除 CV/Sub/航 X)
  final surfaceRatio = (total - cv - sub - hybrid) / total;
  // 加权: CV ×1, Sub ×2, 航 X ×0.5
  final purity = 1 - (cv + sub * 2 + hybrid * 0.5) / total;
  final sc = scoreValue(purity, [0.40, 0.65, 0.85, 0.95, 1.00]);
  return (surfaceRatio, sc);
}

/// 每个等级单独评分, 按 场次×等级难度 加权.
double? _tierWeightedScore(String metric, List<ShipRecord> ships) {
  if (ships.isEmpty) return null;
  final applicable = ships.where((r) {
    final cf = Benchmarks.classFactor(r.type, metric);
    return cf != null;
  }).toList();
  if (applicable.isEmpty) return null;

  final byTier = <int, List<ShipRecord>>{};
  for (final r in applicable) {
    byTier.putIfAbsent(r.tier, () => []).add(r);
  }

  double weightedSum = 0, weightTotal = 0;
  bool any = false;
  for (final entry in byTier.entries) {
    final tier = entry.key;
    final group = entry.value;
    final bT = group.fold<int>(0, (a, r) => a + r.battles);
    if (bT <= 0) continue;
    final actual = _aggregatedMetric(metric, group);
    if (actual == null) continue;
    final thresholds = _classMixThresholdsForTier(metric, group, tier);
    if (thresholds == null) continue;
    any = true;
    final scoreT = scoreValue(actual, thresholds);
    final diff = Benchmarks.tierDifficulty[tier] ?? 1.0;
    final weight = bT * diff;
    weightedSum += weight * scoreT;
    weightTotal += weight;
  }
  if (!any || weightTotal <= 0) return null;
  return weightedSum / weightTotal;
}

double? _aggregatedMetric(String metric, List<ShipRecord> ships) {
  final total = ships.fold<int>(0, (a, r) => a + r.battles);
  if (total <= 0) return null;
  return switch (metric) {
    'win_rate' => ships.fold<int>(0, (a, r) => a + r.wins) / total,
    'avg_damage' => ships.fold<int>(0, (a, r) => a + r.damageDealt) / total,
    'avg_xp' => ships.fold<int>(0, (a, r) => a + r.xp) / total,
    'avg_frags' => ships.fold<int>(0, (a, r) => a + r.frags) / total,
    'survival_rate' => ships.fold<int>(0, (a, r) => a + r.survivedBattles) / total,
    'main_battery_hit_rate' => () {
        final shots = ships.fold<int>(0, (a, r) => a + r.mainBatteryShots);
        if (shots == 0) return null;
        final hits = ships.fold<int>(0, (a, r) => a + r.mainBatteryHits);
        return hits / shots;
      }(),
    'avg_potential_damage' => ships.fold<int>(0, (a, r) => a + r.artAgro + r.torpedoAgro) / total,
    'avg_scouting_damage' => ships.fold<int>(0, (a, r) => a + r.damageScouting) / total,
    'kd_ratio' => () {
        final deaths = total - ships.fold<int>(0, (a, r) => a + r.survivedBattles);
        final f = ships.fold<int>(0, (a, r) => a + r.frags);
        return deaths <= 0 ? f.toDouble() : f / deaths;
      }(),
    _ => null,
  };
}

/// 按场次加权的舰种系数, 用于 mix 阈值.
/// 主炮命中: 额外乘上该船的 hit_rate_factor (机械精度归一).
List<double>? _classMixThresholdsForTier(String metric, List<ShipRecord> ships, int tier) {
  final base = Benchmarks.base[metric];
  if (base == null) return null;
  double total = 0, weighted = 0;
  for (final r in ships) {
    var cf = Benchmarks.classFactor(r.type, metric);
    if (cf == null) continue;
    if (metric == 'main_battery_hit_rate' && r.hitRateFactor != null && r.hitRateFactor! > 0) {
      cf = cf * r.hitRateFactor!;
    }
    total += r.battles;
    weighted += r.battles * cf;
  }
  if (total <= 0) return null;
  final classF = weighted / total;
  final tierF = Benchmarks.tierFactor(metric, tier);
  return base.map((b) => b * classF * tierF).toList();
}

/// 整体 ships 加权 (跨等级) 的阈值.
List<double> _classMixThresholds(String metric, List<ShipRecord> ships) {
  final base = Benchmarks.base[metric] ?? const [1.0, 2.0, 3.0, 4.0, 5.0];
  if (ships.isEmpty) return base.toList();
  double totalB = 0, classW = 0, tierW = 0;
  for (final r in ships) {
    var cf = Benchmarks.classFactor(r.type, metric);
    if (cf == null) continue;
    if (metric == 'main_battery_hit_rate' && r.hitRateFactor != null && r.hitRateFactor! > 0) {
      cf = cf * r.hitRateFactor!;
    }
    totalB += r.battles;
    classW += r.battles * cf;
    tierW += r.battles * Benchmarks.tierFactor(metric, r.tier);
  }
  if (totalB <= 0) return base.toList();
  final cf = classW / totalB;
  final tf = tierW / totalB;
  return base.map((b) => b * cf * tf).toList();
}

/// 优势 / 劣势
({List<MapEntry<String, (double, double)>> strengths, List<MapEntry<String, (double, double)>> weaknesses})
    analyzeStrengths(Map<String, (double, double)> scores, {int n = 2}) {
  final items = scores.entries.toList()
    ..sort((a, b) => b.value.$2.compareTo(a.value.$2));
  return (
    strengths: items.take(n).toList(),
    weaknesses: items.reversed.take(n).toList().reversed.toList(),
  );
}

/// Re-export so other files don't need to import personal_rating.
double battlePowerFromPr(double pr) => computeBattlePower(pr).toDouble();
