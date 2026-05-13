/// 工会简略信息 (搜索结果用).
class ClanSummary {
  final int clanId;
  final String tag;
  final String name;
  final int membersCount;

  ClanSummary({
    required this.clanId,
    required this.tag,
    required this.name,
    required this.membersCount,
  });

  factory ClanSummary.fromJson(Map<String, dynamic> j) => ClanSummary(
        clanId: (j['clan_id'] as num).toInt(),
        tag: j['tag']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        membersCount: (j['members_count'] as num?)?.toInt() ?? 0,
      );
}

/// 工会成员的简略战绩 (用于成员列表 + 聚合).
class ClanMember {
  final int accountId;
  final String nickname;
  final String role;           // commander / executive_officer / officer / recruit ...
  final int battles;
  final int wins;
  final int damageDealt;
  final int xp;
  final int frags;
  final int survivedBattles;
  final int mainBatteryHits;
  final int mainBatteryShots;
  final int artAgro;
  final int torpedoAgro;
  final int damageScouting;
  final int planesKilled;
  final int shipsSpotted;
  final bool hidden;

  ClanMember({
    required this.accountId,
    required this.nickname,
    required this.role,
    this.battles = 0,
    this.wins = 0,
    this.damageDealt = 0,
    this.xp = 0,
    this.frags = 0,
    this.survivedBattles = 0,
    this.mainBatteryHits = 0,
    this.mainBatteryShots = 0,
    this.artAgro = 0,
    this.torpedoAgro = 0,
    this.damageScouting = 0,
    this.planesKilled = 0,
    this.shipsSpotted = 0,
    this.hidden = false,
  });

  double get winRate => battles > 0 ? wins / battles : 0;
  double get avgDamage => battles > 0 ? damageDealt / battles : 0;
  double get avgXp => battles > 0 ? xp / battles : 0;
  double get avgFrags => battles > 0 ? frags / battles : 0;
  double get survivalRate => battles > 0 ? survivedBattles / battles : 0;
  double get avgPotentialDamage =>
      battles > 0 ? (artAgro + torpedoAgro) / battles : 0;
  double get avgScoutingDamage =>
      battles > 0 ? damageScouting / battles : 0;
  double get mainBatteryHitRate =>
      mainBatteryShots > 0 ? mainBatteryHits / mainBatteryShots : 0;

  double get kdRatio {
    final deaths = battles - survivedBattles;
    if (deaths <= 0) return frags.toDouble();
    return frags / deaths;
  }
}

/// 工会详细数据 (含聚合战绩 + 成员列表).
class ClanData {
  final int clanId;
  final String tag;
  final String name;
  final String? motto;
  final int? color;            // 0xAARRGGBB
  final List<ClanMember> members;

  ClanData({
    required this.clanId,
    required this.tag,
    required this.name,
    this.motto,
    this.color,
    required this.members,
  });

  /// 排除隐藏玩家 / 0 场玩家.
  List<ClanMember> get activeMembers =>
      members.where((m) => !m.hidden && m.battles > 0).toList();

  // ───── 聚合指标 (跨成员加权平均) ─────
  int get totalBattles => activeMembers.fold(0, (a, m) => a + m.battles);
  int get totalWins => activeMembers.fold(0, (a, m) => a + m.wins);
  int get totalDamage => activeMembers.fold(0, (a, m) => a + m.damageDealt);
  int get totalXp => activeMembers.fold(0, (a, m) => a + m.xp);
  int get totalFrags => activeMembers.fold(0, (a, m) => a + m.frags);
  int get totalSurvived => activeMembers.fold(0, (a, m) => a + m.survivedBattles);
  int get totalMbHits => activeMembers.fold(0, (a, m) => a + m.mainBatteryHits);
  int get totalMbShots => activeMembers.fold(0, (a, m) => a + m.mainBatteryShots);
  int get totalPotentialDamage => activeMembers.fold(0, (a, m) => a + m.artAgro + m.torpedoAgro);
  int get totalScouting => activeMembers.fold(0, (a, m) => a + m.damageScouting);
  int get totalPlanesKilled => activeMembers.fold(0, (a, m) => a + m.planesKilled);
  int get totalShipsSpotted => activeMembers.fold(0, (a, m) => a + m.shipsSpotted);

  /// 活跃成员等权重平均 (不按场次加权).
  double _mean(double Function(ClanMember m) f) {
    final active = activeMembers;
    if (active.isEmpty) return 0;
    return active.fold<double>(0, (a, m) => a + f(m)) / active.length;
  }

  double get avgWinRate => _mean((m) => m.winRate);
  double get avgDamage => _mean((m) => m.avgDamage);
  double get avgXp => _mean((m) => m.avgXp);
  double get avgFrags => _mean((m) => m.avgFrags);
  double get avgSurvival => _mean((m) => m.survivalRate);
  double get avgPotentialDamage => _mean((m) => m.avgPotentialDamage);
  double get avgScoutingDamage => _mean((m) => m.avgScoutingDamage);
  double get mainBatteryHitRate => _mean((m) => m.mainBatteryHitRate);
  double get kdRatio => _mean((m) => m.kdRatio);

  /// 隐藏🐴比例: 隐藏战绩的成员数 / 总成员数 (越高表示「臭名昭著」越严重)
  double get hiddenHorseRatio {
    if (members.isEmpty) return 0;
    return members.where((m) => m.hidden).length / members.length;
  }

  /// 活跃成员人均场次 (老兵工会的活跃度指标).
  double get avgBattlesPerMember {
    final n = activeMembers.length;
    return n > 0 ? totalBattles / n : 0;
  }
}
