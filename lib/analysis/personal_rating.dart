import 'dart:math' as math;
import '../models/ship_record.dart';

const lowerDmg = 0.4;
const lowerFrags = 0.1;
const lowerWr = 0.7;

double? normalize(num? actual, num? expected, double lower) {
  if (expected == null || expected <= 0 || actual == null) return null;
  final v = (actual / expected - lower) / (1 - lower);
  return v < 0 ? 0 : v.toDouble();
}

double computePr(double nDmg, double nFrags, double nWr) {
  return 700 * nDmg + 300 * nFrags + 150 * nWr;
}

/// 基础战力: PR → sigmoid 压缩到 0~70000.
/// PR=1000 → ~500 / 1700 → 35000 / 2200 → ~62000 / 2500+ → 渐近 70000.
int computeBattlePower(double pr) {
  if (pr <= 0) return 0;
  return (70000 / (1 + math.exp(-(pr - 1700) / 250))).toInt();
}

/// 单船战力: sigmoid 上限 30k * 投入度 sqrt(battles/100).
int computeShipBattlePower(double? shipPr, int battles) {
  if (shipPr == null || shipPr <= 0 || battles <= 0) return 0;
  final base = 30000 / (1 + math.exp(-(shipPr - 1700) / 300));
  final investment = math.min(1.0, math.sqrt(battles / 100.0));
  return (base * investment).toInt();
}

/// 4 个奇怪修正系数 dict.
/// challenge: 1.0 + 0.02*N (最大 1.40)
/// horse:     0.85 ~ 1.10 (水面舰占比)
/// variety:   1.00 ~ 1.15 (舰种/等级杂食)
/// veteran:   1.00 ~ 1.20 (总场次 log)
Map<String, double> computeBattlePowerModifiers(
    List<ShipRecord> ships, int nChallenges) {
  final m = {
    'challenge': 1.0 + 0.02 * math.max(0, nChallenges),
    'horse': 1.0,
    'variety': 1.0,
    'veteran': 1.0,
  };
  if (ships.isEmpty) return m;
  final totalB = ships.fold<int>(0, (a, r) => a + r.battles);
  if (totalB <= 0) return m;

  // 🐴 含量
  final cv = ships.where((r) => r.type == 'AirCarrier').fold<int>(0, (a, r) => a + r.battles);
  final sub = ships.where((r) => r.type == 'Submarine').fold<int>(0, (a, r) => a + r.battles);
  final surfacePct = (totalB - cv - sub) / totalB;
  if (surfacePct >= 0.80) m['horse'] = 1.10;
  else if (surfacePct < 0.30) m['horse'] = 0.85;
  else if (surfacePct < 0.60) m['horse'] = 0.95;

  // 🌈 杂食值
  final nClasses = ships.map((r) => r.type).toSet().length;
  final nTiers = ships.map((r) => r.tier).toSet().length;
  final v = math.max(0, nClasses - 2) * 0.025 + math.max(0, nTiers - 3) * 0.012;
  m['variety'] = 1.0 + math.min(0.15, v);

  // 🎖️ 老兵
  final bonus = (math.log(1 + totalB / 100.0) / math.ln10) * 0.06;
  m['veteran'] = 1.0 + math.min(0.20, bonus);

  return m;
}

int applyBattlePowerModifiers(int baseBp, Map<String, double> modifiers) {
  if (baseBp <= 0) return baseBp;
  double mult = 1.0;
  for (final k in ['challenge', 'horse', 'variety', 'veteran']) {
    mult *= modifiers[k] ?? 1.0;
  }
  return (baseBp * mult).toInt();
}

class PrColor {
  static int fromPr(double pr) {
    if (pr < 300) return 0xFF7A6F66;
    if (pr < 750) return 0xFFA8804E;
    if (pr < 1100) return 0xFFC7A82E;
    if (pr < 1350) return 0xFF7CCC42;
    if (pr < 1550) return 0xFF4F9F38;
    if (pr < 1750) return 0xFF2B8FB0;
    if (pr < 2100) return 0xFF9759BC;
    if (pr < 2450) return 0xFFDA00A6;
    return 0xFFFFD700;
  }
}
