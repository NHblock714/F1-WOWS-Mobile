import '../models/player.dart';
import '../models/ship_record.dart';

class BattleStyle {
  final String name;
  final String emoji;
  final String desc;
  final int power;
  const BattleStyle(this.name, this.emoji, this.desc, this.power);
}

/// 舰种倾向 (放第 1 位).
BattleStyle? _classTendency(List<ShipRecord> ships) {
  if (ships.isEmpty) return null;
  final total = ships.fold<int>(0, (a, r) => a + r.battles);
  if (total <= 0) return null;
  final sub = ships.where((r) => r.type == 'Submarine').fold<int>(0, (a, r) => a + r.battles);
  final cv = ships.where((r) => r.type == 'AirCarrier').fold<int>(0, (a, r) => a + r.battles);
  final surface = total - sub - cv;
  final subPct = sub / total;
  final cvPct = cv / total;
  final surfacePct = surface / total;
  if (subPct >= 0.30) return BattleStyle('水下巨人', '🐋', '族谱单开并不总是代表从龙之功', (200 + subPct * 500).toInt());
  if (cvPct >= 0.30) return BattleStyle('空中小人', '✈️', '别急，这组掉光还有下一组', (200 + cvPct * 500).toInt());
  if (surfacePct >= 0.60) return BattleStyle('水面庶民', '🚢', '我知道我在玩什么，但我别无选择', (100 + (surfacePct - 0.60) * 500).toInt());
  return null;
}

int _stylePower(Iterable<String> metrics, Map<String, double> s) {
  double total = 0;
  for (final m in metrics) {
    final v = s[m] ?? 40.0;
    if (v > 40) total += v - 40;
  }
  return (total * 10).clamp(0, 2500).toInt();
}

/// 推断战斗风格列表 (第 1 位是固定的舰种倾向; 后续是触发的风格按置信度排序).
List<BattleStyle> inferBattleStyles(
  Map<String, (double, double)> scores,
  PlayerStats? stats,
  List<ShipRecord> ships,
) {
  final result = <BattleStyle>[];
  final tendency = _classTendency(ships);
  if (tendency != null) result.add(tendency);

  if (scores.isEmpty) return result;

  final s = <String, double>{
    for (final e in scores.entries) e.key: e.value.$2,
  };
  final kd = s['击杀效率'] ?? 50;
  final dmg = s['场均伤害'] ?? 50;
  final frags = s['场均击杀'] ?? 50;
  final tank = s['场均抗伤'] ?? 50;
  final scout = s['场均侦查'] ?? 50;
  final hit = s['主炮命中'] ?? 50;
  final win = s['胜率'] ?? 50;
  final xp = s['场均经验'] ?? 50;

  final candidates = <(BattleStyle, double)>[];
  void add(String name, String emoji, String desc, Iterable<String> metrics, double conf) {
    candidates.add((BattleStyle(name, emoji, desc, _stylePower(metrics, s)), conf));
  }

  if (tank >= 80) add('抗线型', '🛡️', '爱慕还是耐揍王', ['场均抗伤'], tank);
  if (dmg >= 80) add('输出型', '💥', '你问赢了输了，我说赚了', ['场均伤害'], dmg);
  if (scout >= 80) add('侦察型', '👁️', '我会一直视奸你，直到永远...', ['场均侦查'], scout * 1.2);
  if (hit >= 80) add('中段怪', '🎯', '没关就是没开', ['主炮命中'], hit * 1.1);
  if (kd < 45 && (dmg >= 55 || frags >= 60)) add('冲锋型', '⚔️', '数据？我只是着急开下一把', ['场均伤害', '场均击杀'], dmg + frags - kd);
  if (kd >= 70 && win >= 55) add('稳健型', '🧘', '我已前压至 22 公里', ['击杀效率', '胜率'], kd + win);
  if (win >= 100 && xp >= 55) add('战术大师', '🏆', '等打赢这场仗我就回老家结婚', ['胜率', '场均经验'], win + xp);
  if (frags >= 70 && dmg < frags - 10) add('收割型', '🪓', 'K 头只是为了防止复活', ['场均击杀'], frags);
  final qualifying = s.values.where((v) => 55 <= v && v <= 90).length;
  if (qualifying >= 6 && (s.values.isNotEmpty ? s.values.reduce((a,b) => a < b ? a : b) : 0) >= 40) {
    add('全能型', '⚖️', '男人，什么罐头我说', s.keys, s.values.fold<double>(0, (a, v) => a + v) / s.length);
  }

  if (candidates.isEmpty) {
    final avg = s.values.isEmpty ? 0 : s.values.reduce((a, b) => a + b) / s.length;
    if (avg < 30) {
      result.add(BattleStyle('海猴巅峰', '🌱', '已严肃下载战舰世界 （游玩时长2h）', 0));
    } else if (avg < 50) {
      result.add(BattleStyle('绝望之谷', '📈', '请问有考虑过转会吗', 0));
    } else {
      result.add(BattleStyle('混合型', '🌀', '又是一天新的金瓶掣签', 0));
    }
    return result;
  }

  candidates.sort((a, b) => b.$2.compareTo(a.$2));
  for (final (style, _) in candidates) {
    result.add(style);
  }
  return result;
}
