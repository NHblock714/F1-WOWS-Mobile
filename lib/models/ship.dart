class Ship {
  final String shipId;
  final String name;
  final int? tier;
  final String? type;
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
  final int maxDamageScouting;
  final double? expectedDamage;
  final double? expectedFrags;
  final double? expectedWinrate;

  Ship({
    required this.shipId,
    required this.name,
    this.tier,
    this.type,
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
    this.maxDamageScouting = 0,
    this.expectedDamage,
    this.expectedFrags,
    this.expectedWinrate,
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
}
