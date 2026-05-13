/// 单艘船的完整数据 (合并 WG ships + encyclopedia + wows-numbers PR).
class ShipRecord {
  final String shipId;
  final String name;
  final int tier;
  final String type; // Battleship/Cruiser/Destroyer/AirCarrier/Submarine
  final String? nation;
  final bool isPremium;
  final String? imageContour;
  final String? imageSmall;

  final int battles;
  final int wins;
  final int damageDealt;
  final int xp;
  final int frags;
  final int survivedBattles;
  final int mainBatteryHits;
  final int mainBatteryShots;
  final int torpedoesHits;
  final int torpedoesShots;
  final int planesKilled;
  final int damageScouting;
  final int shipsSpotted;
  final int artAgro;
  final int torpedoAgro;
  final int maxDamageScouting;

  final double? expectedDamage;
  final double? expectedFrags;
  final double? expectedWinrate;
  final double? hitRateFactor;  // 机械精度 / 同舰种平均, 用于主炮命中阈值修正
  final bool isHybrid;          // 航站/航巡/航驱 (非 CV 但带飞机)

  ShipRecord({
    required this.shipId,
    required this.name,
    required this.tier,
    required this.type,
    this.nation,
    this.isPremium = false,
    this.imageContour,
    this.imageSmall,
    required this.battles,
    this.wins = 0,
    this.damageDealt = 0,
    this.xp = 0,
    this.frags = 0,
    this.survivedBattles = 0,
    this.mainBatteryHits = 0,
    this.mainBatteryShots = 0,
    this.torpedoesHits = 0,
    this.torpedoesShots = 0,
    this.planesKilled = 0,
    this.damageScouting = 0,
    this.shipsSpotted = 0,
    this.artAgro = 0,
    this.torpedoAgro = 0,
    this.maxDamageScouting = 0,
    this.expectedDamage,
    this.expectedFrags,
    this.expectedWinrate,
    this.hitRateFactor,
    this.isHybrid = false,
  });

  double get winRate => battles > 0 ? wins / battles : 0;
  double get avgDamage => battles > 0 ? damageDealt / battles : 0;
  double get avgXp => battles > 0 ? xp / battles : 0;
  double get avgFrags => battles > 0 ? frags / battles : 0;
  double get survivalRate => battles > 0 ? survivedBattles / battles : 0;
  double get mainBatteryHitRate =>
      mainBatteryShots > 0 ? mainBatteryHits / mainBatteryShots : 0;
  double get torpedoHitRate =>
      torpedoesShots > 0 ? torpedoesHits / torpedoesShots : 0;
  double get avgScoutingDamage => battles > 0 ? damageScouting / battles : 0;
  double get avgPotentialDamage =>
      battles > 0 ? (artAgro + torpedoAgro) / battles : 0;
  double get avgPlanesKilled => battles > 0 ? planesKilled / battles : 0;

  double get kdRatio {
    final deaths = battles - survivedBattles;
    if (deaths <= 0) return frags.toDouble();
    return frags / deaths;
  }

  /// PR n_dmg / n_frags / n_wr (与 PC ships.py 同公式).
  double? get nDmg {
    if (expectedDamage == null || expectedDamage! <= 0) return null;
    final v = (avgDamage / expectedDamage! - 0.4) / 0.6;
    return v < 0 ? 0 : v;
  }
  double? get nFrags {
    if (expectedFrags == null || expectedFrags! <= 0) return null;
    final v = (avgFrags / expectedFrags! - 0.1) / 0.9;
    return v < 0 ? 0 : v;
  }
  double? get nWr {
    if (expectedWinrate == null || expectedWinrate! <= 0) return null;
    final v = (winRate / expectedWinrate! - 0.7) / 0.3;
    return v < 0 ? 0 : v;
  }

  double? get shipPr {
    if (nDmg == null || nFrags == null || nWr == null) return null;
    return 700 * nDmg! + 300 * nFrags! + 150 * nWr!;
  }
}
