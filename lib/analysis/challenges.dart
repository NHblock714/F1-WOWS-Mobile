import '../models/player.dart';
import '../models/ship_record.dart';

class Challenge {
  final String name;
  final String condText;
  final String desc;
  final bool Function(PlayerStats stats, List<ShipRecord> ships) check;
  const Challenge(this.name, this.condText, this.desc, this.check);
}

bool _anyShipAvgDamage(List<ShipRecord> ships, int target) =>
    ships.any((r) => r.avgDamage.round() == target);

bool _anyShipBattlesAtLeast(List<ShipRecord> ships, int n) =>
    ships.any((r) => r.battles >= n);

bool _anyBbMaxScouting(List<ShipRecord> ships, int threshold) =>
    ships.any((r) => r.type == 'Battleship' && r.maxDamageScouting >= threshold);

bool _anyHighTierLowDamage(List<ShipRecord> ships, int minTier, int maxAvgDamage, {int minBattles = 5}) =>
    ships.any((r) => r.tier >= minTier && r.battles >= minBattles && r.avgDamage <= maxAvgDamage);

bool _anyShipMbHitRate(List<ShipRecord> ships, double threshold, {int minBattles = 5, int minShots = 100}) =>
    ships.any((r) => r.battles >= minBattles && r.mainBatteryShots >= minShots && r.mainBatteryHitRate >= threshold);

bool _anyDdTorpHitRate(List<ShipRecord> ships, double threshold, {int minBattles = 5, int minShots = 50}) =>
    ships.any((r) => r.type == 'Destroyer' && r.battles >= minBattles && r.torpedoesShots >= minShots && r.torpedoHitRate >= threshold);

bool _cvSubShare(List<ShipRecord> ships, double threshold) {
  final total = ships.fold<int>(0, (a, r) => a + r.battles);
  if (total <= 0) return false;
  final cv = ships.where((r) => r.type == 'AirCarrier').fold<int>(0, (a, r) => a + r.battles);
  final sub = ships.where((r) => r.type == 'Submarine').fold<int>(0, (a, r) => a + r.battles);
  return (cv + sub) / total >= threshold;
}

bool _lowTierShare(List<ShipRecord> ships, int maxTier, double threshold) {
  final total = ships.fold<int>(0, (a, r) => a + r.battles);
  if (total <= 0) return false;
  final low = ships.where((r) => r.tier <= maxTier).fold<int>(0, (a, r) => a + r.battles);
  return low / total >= threshold;
}

bool _blackFridayCount(List<ShipRecord> ships, int min) =>
    ships.where((r) => r.name.endsWith(' B')).length >= min;

bool _alCollabCount(List<ShipRecord> ships, int min) =>
    ships.where((r) => r.name.startsWith('AL ')).length >= min;

const challenges = <Challenge>[
  Challenge('摧枯拉朽', '单场击杀战舰 ≥ 8', '会战兵力是11舰对4舰，优势在我',
      _maxFrags8),
  Challenge('铁壁防线', '单场潜在伤害 ≥ 8000k', '这下总算能赢了…吧？',
      _maxAgro),
  Challenge('亡牌飞行员', '单场击毁飞机 ≥ 60', '是谁给你的勇气从空中向我发起进攻',
      _maxPlanes),
  Challenge('天空之眼', '单场侦察舰船 ≥ 18 艘', '那年海战，对面只来了6舰，我甩了一下刘海，才发现右边还有12舰',
      _maxSpotted),
  Challenge('冒险模式', '单场经验 ≥ 6600', '其他人都在干什么？',
      _maxXp),
  Challenge('创造模式', '单场伤害 ≥ 400k', '你说终于赢了，我说真刷爽了',
      _maxDmg),
  Challenge('观察模式', '单场侦查伤害 ≥ 400k', '我说终于赢了，你说真刷爽了',
      _maxScouting),
  Challenge('野兽先辈', '任意战舰场均伤害 = 114514', '发射出去的不是炮弹，是湿意罢（悲）',
      _beast),
  Challenge('真爱粉', '任意战舰场次 ≥ 10000', 'onb真的遇到战舰仙人了',
      _trueLove),
  Challenge('真正的和平', '平局累计 ≥ 10 场', '20达布隆的活拼什么命啊',
      _peace),
  Challenge('碰碰船', '冲撞击沉累计 ≥ 200 艘', '别怕孩子们看我肘他，不耗孩子们我漏水了',
      _ramming),
  Challenge('面壁者', '任意战列舰单场侦查伤害 ≥ 200k', '我也是计划的一部分？',
      _wallFacer),
  Challenge('CN_70', '任意战斗场次 ≥ 5 场的 T8+ 战舰场均伤害 ≤ 4000', '您已被移出小队',
      _cn70),
  Challenge('PAC', '任意战斗场次 ≥ 5 场的战舰主炮命中率 ≥ 60%', '没问题啊，我玩絮库夫和埃尔宾的',
      _pac),
  Challenge('水雷魂', '任意战斗场次 ≥ 5 场的驱逐舰鱼雷命中率 ≥ 15%', 'てん こう へい か まん さい!',
      _torpSoul),
  Challenge('全家福', '航母 + 潜艇场次占比 ≥ 60%', '浮木刚用完，去打会瓦进点货',
      _familyPic),
  Challenge('刮宫圣手', 'T6 及以下场次占比 ≥ 30%', '太老了，你回去吧',
      _lowTier),
  Challenge('舰队防空', '场均击落飞机 ≥ 7', '哎我怎么老贝榨啊',
      _fleetAA),
  Challenge('林翩翩', '拥有 ≥ 15 条黑五战舰', '她说是晒黑的',
      _bf),
  Challenge('天青车道', '拥有 ≥ 10 条 AL 联动战舰', '二次元的钱真好赚',
      _al),
  Challenge('吸鼠坝王', '获得以一当十成就 ≥ 10 次',
      '我草终于重连回来了，唉不是怎么就剩我一个了',
      _soloWarrior),
];

bool _maxFrags8(PlayerStats s, _) => s.maxFragsBattle >= 8;
bool _maxAgro(PlayerStats s, _) => s.maxTotalAgro >= 8000000;
bool _maxPlanes(PlayerStats s, _) => s.maxPlanesKilled >= 60;
bool _maxSpotted(PlayerStats s, _) => s.maxShipsSpotted >= 18;
bool _maxXp(PlayerStats s, _) => s.maxXp >= 6600;
bool _maxDmg(PlayerStats s, _) => s.maxDamageDealt >= 400000;
bool _maxScouting(PlayerStats s, _) => s.maxDamageScouting >= 400000;
bool _beast(_, List<ShipRecord> df) => _anyShipAvgDamage(df, 114514);
bool _trueLove(_, List<ShipRecord> df) => _anyShipBattlesAtLeast(df, 10000);
bool _peace(PlayerStats s, _) => s.draws >= 10;
bool _ramming(PlayerStats s, _) => s.rammingFrags >= 200;
bool _wallFacer(_, List<ShipRecord> df) => _anyBbMaxScouting(df, 200000);
bool _cn70(_, List<ShipRecord> df) => _anyHighTierLowDamage(df, 8, 4000);
bool _pac(_, List<ShipRecord> df) => _anyShipMbHitRate(df, 0.60);
bool _torpSoul(_, List<ShipRecord> df) => _anyDdTorpHitRate(df, 0.15);
bool _familyPic(_, List<ShipRecord> df) => _cvSubShare(df, 0.60);
bool _lowTier(_, List<ShipRecord> df) => _lowTierShare(df, 6, 0.30);
bool _fleetAA(PlayerStats s, _) => s.avgPlanesKilled >= 7;
bool _bf(_, List<ShipRecord> df) => _blackFridayCount(df, 15);
bool _al(_, List<ShipRecord> df) => _alCollabCount(df, 10);
bool _soloWarrior(PlayerStats s, _) => (s.achievements['SOLO_WARRIOR'] ?? 0) >= 10;

List<Challenge> getCompletedChallenges(PlayerStats? stats, List<ShipRecord> ships) {
  if (stats == null) return [];
  return challenges.where((c) {
    try {
      return c.check(stats, ships);
    } catch (_) {
      return false;
    }
  }).toList();
}
