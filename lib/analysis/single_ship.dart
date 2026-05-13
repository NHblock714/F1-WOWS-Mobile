import 'dart:math' as math;
import '../models/ship_record.dart';
import 'benchmarks.dart';
import 'scoring.dart';

/// 计算单艘船的 6 维评分 (与 PC compute_single_ship_scores 思路一致).
/// 返回 (scores_map, confidence).
({Map<String, (double, double)> scores, double confidence}) computeSingleShipScores(ShipRecord r) {
  final threshold = r.tier >= 10 ? 80 : 40;
  final confidence = r.battles >= threshold ? 1.0 :
      r.battles <= 1 ? 0.5 :
      0.5 + 0.5 * (r.battles - 1) / (threshold - 1);

  List<double>? thresholds(String metric) {
    final base = Benchmarks.base[metric];
    if (base == null) return null;
    final cf = Benchmarks.classFactor(r.type, metric);
    if (cf == null) return null;
    final tf = Benchmarks.tierFactor(metric, r.tier);
    return base.map((b) => b * cf * tf).toList();
  }

  double scoreAbs(String metric, double value) {
    final t = thresholds(metric);
    if (t == null) return 0;
    return scoreValue(value, t);
  }

  double scorePR(double? nVal, bool isWr) {
    if (nVal == null) return 0;
    final sc = isWr ? 90 * nVal - 50 : 60 * nVal - 20;
    return sc.clamp(0, scorePoints.last * 1.15);
  }

  final scores = <String, (double, double)>{};

  // PR-based 3 axes, take max of PR & absolute
  final winRateAbs = scoreAbs('win_rate', r.winRate);
  final winRatePr = scorePR(r.nWr, true);
  scores['胜率'] = (r.winRate, winRateAbs > winRatePr ? winRateAbs : winRatePr);

  final dmgAbs = scoreAbs('avg_damage', r.avgDamage);
  final dmgPr = scorePR(r.nDmg, false);
  scores['场均伤害'] = (r.avgDamage, dmgAbs > dmgPr ? dmgAbs : dmgPr);

  final fragsAbs = scoreAbs('avg_frags', r.avgFrags);
  final fragsPr = scorePR(r.nFrags, false);
  scores['击杀效率'] = (r.kdRatio, fragsAbs > fragsPr ? fragsAbs : fragsPr);

  // Absolute-only axes
  scores['场均经验'] = (r.avgXp, scoreAbs('avg_xp', r.avgXp));

  final mbT = thresholds('main_battery_hit_rate');
  if (mbT != null) {
    scores['主炮命中'] = (r.mainBatteryHitRate, scoreValue(r.mainBatteryHitRate, mbT));
  } else {
    scores['主炮命中'] = (r.mainBatteryHitRate, 0);
  }

  // 场次 - 0-100 线性, threshold 以上 log 缓增 (与 Python _battle_count_score 对齐)
  double battleScore;
  if (r.battles <= 0) {
    battleScore = 0;
  } else if (r.battles <= threshold) {
    battleScore = r.battles / threshold * 100;
  } else {
    final over = r.battles - threshold;
    battleScore = 100 + 4.3 * math.log(1.0 + over / 100.0);
  }
  scores['场次'] = (r.battles.toDouble(), battleScore);

  // Apply confidence to all except 场次 (场次 itself is the confidence)
  final adjusted = <String, (double, double)>{};
  for (final e in scores.entries) {
    if (e.key == '场次') {
      adjusted[e.key] = e.value;
    } else {
      adjusted[e.key] = (e.value.$1, e.value.$2 * confidence);
    }
  }
  return (scores: adjusted, confidence: confidence);
}
