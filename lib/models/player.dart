class PlayerStats {
  final int battles;
  final int wins;
  final int damageDealt;
  final int xp;
  final int frags;
  final int survivedBattles;
  final int mainBatteryHits;
  final int mainBatteryShots;
  final int planesKilled;
  final int damageScouting;
  final int shipsSpotted;
  final int artAgro;
  final int torpedoAgro;
  final int draws;
  final int rammingFrags;
  final int maxDamageDealt;
  final int maxXp;
  final int maxFragsBattle;
  final int maxTotalAgro;
  final int maxPlanesKilled;
  final int maxShipsSpotted;
  final int maxDamageScouting;

  PlayerStats({
    required this.battles,
    required this.wins,
    required this.damageDealt,
    required this.xp,
    required this.frags,
    required this.survivedBattles,
    required this.mainBatteryHits,
    required this.mainBatteryShots,
    this.planesKilled = 0,
    this.damageScouting = 0,
    this.shipsSpotted = 0,
    this.artAgro = 0,
    this.torpedoAgro = 0,
    this.draws = 0,
    this.rammingFrags = 0,
    this.maxDamageDealt = 0,
    this.maxXp = 0,
    this.maxFragsBattle = 0,
    this.maxTotalAgro = 0,
    this.maxPlanesKilled = 0,
    this.maxShipsSpotted = 0,
    this.maxDamageScouting = 0,
  });

  /// 账号级成就 {id: count}, 由 PlayerDataService 注入到 PVP stats.
  Map<String, int> achievements = const {};

  double get winRate => battles > 0 ? wins / battles : 0;
  double get avgDamage => battles > 0 ? damageDealt / battles : 0;
  double get avgXp => battles > 0 ? xp / battles : 0;
  double get avgFrags => battles > 0 ? frags / battles : 0;
  double get survivalRate => battles > 0 ? survivedBattles / battles : 0;
  double get mainBatteryHitRate =>
      mainBatteryShots > 0 ? mainBatteryHits / mainBatteryShots : 0;
  double get avgPlanesKilled => battles > 0 ? planesKilled / battles : 0;
  double get avgScoutingDamage => battles > 0 ? damageScouting / battles : 0;
  double get avgShipsSpotted => battles > 0 ? shipsSpotted / battles : 0;
  double get avgPotentialDamage =>
      battles > 0 ? (artAgro + torpedoAgro) / battles : 0;

  double get kdRatio {
    final deaths = battles - survivedBattles;
    if (deaths <= 0) return frags.toDouble();
    return frags / deaths;
  }

  /// 把一组 ShipRecord 聚合成 PlayerStats (用于筛选后的雷达).
  /// 注意: 不带 max_* / draws / ramming_frags (这些是玩家级别统计).
  static PlayerStats fromShipsAggregate(Iterable<dynamic> records) {
    int b = 0, w = 0, dd = 0, xp = 0, fr = 0, sb = 0;
    int mbH = 0, mbS = 0, tpH = 0, tpS = 0;
    int pk = 0, ds = 0, ss = 0, aa = 0, ta = 0;
    for (final r in records) {
      b += r.battles as int;
      w += r.wins as int;
      dd += r.damageDealt as int;
      xp += r.xp as int;
      fr += r.frags as int;
      sb += r.survivedBattles as int;
      mbH += r.mainBatteryHits as int;
      mbS += r.mainBatteryShots as int;
      tpH += r.torpedoesHits as int;
      tpS += r.torpedoesShots as int;
      pk += r.planesKilled as int;
      ds += r.damageScouting as int;
      ss += r.shipsSpotted as int;
      aa += r.artAgro as int;
      ta += r.torpedoAgro as int;
    }
    return PlayerStats(
      battles: b, wins: w, damageDealt: dd, xp: xp, frags: fr,
      survivedBattles: sb, mainBatteryHits: mbH, mainBatteryShots: mbS,
      planesKilled: pk, damageScouting: ds, shipsSpotted: ss,
      artAgro: aa, torpedoAgro: ta,
    );
  }

  static PlayerStats? fromModeDict(Map<String, dynamic>? data) {
    if (data == null || (data['battles'] ?? 0) == 0) return null;
    final mb = (data['main_battery'] as Map?) ?? {};
    final ramming = (data['ramming'] as Map?) ?? {};
    return PlayerStats(
      battles: data['battles'] ?? 0,
      wins: data['wins'] ?? 0,
      damageDealt: data['damage_dealt'] ?? 0,
      xp: data['xp'] ?? 0,
      frags: data['frags'] ?? 0,
      survivedBattles: data['survived_battles'] ?? 0,
      mainBatteryHits: mb['hits'] ?? 0,
      mainBatteryShots: mb['shots'] ?? 0,
      planesKilled: data['planes_killed'] ?? 0,
      damageScouting: data['damage_scouting'] ?? 0,
      shipsSpotted: data['ships_spotted'] ?? 0,
      artAgro: data['art_agro'] ?? 0,
      torpedoAgro: data['torpedo_agro'] ?? 0,
      draws: data['draws'] ?? 0,
      rammingFrags: ramming['frags'] ?? 0,
      maxDamageDealt: data['max_damage_dealt'] ?? 0,
      maxXp: data['max_xp'] ?? 0,
      maxFragsBattle: data['max_frags_battle'] ?? 0,
      maxTotalAgro: data['max_total_agro'] ?? 0,
      maxPlanesKilled: data['max_planes_killed'] ?? 0,
      maxShipsSpotted: data['max_ships_spotted'] ?? 0,
      maxDamageScouting: data['max_damage_scouting'] ?? 0,
    );
  }
}

const modeKeys = ['pvp', 'pve', 'rank_solo', 'club', 'oper_solo', 'oper_div'];

const modeDisplayZh = <String, String>{
  'pvp': '随机战斗',
  'pve': '联合战斗',
  'rank_solo': '排位 (单人)',
  'club': '公会战',
  'oper_solo': '战役 (单人)',
  'oper_div': '战役 (组队)',
};

class Player {
  final int accountId;
  final String nickname;
  final bool hidden;
  final Map<String, PlayerStats> modeStats;

  Player({
    required this.accountId,
    required this.nickname,
    required this.hidden,
    this.modeStats = const {},
  });

  PlayerStats? get stats => modeStats['pvp'];

  List<String> get availableModes =>
      modeKeys.where((m) => modeStats[m] != null).toList();

  factory Player.fromApi(Map<String, dynamic> info) {
    final hidden = info['hidden_profile'] == true || info['statistics'] == null;
    if (hidden) {
      return Player(
        accountId: info['account_id'],
        nickname: info['nickname'],
        hidden: true,
      );
    }
    final statistics = info['statistics'] as Map<String, dynamic>;
    final modes = <String, PlayerStats>{};
    for (final m in modeKeys) {
      final s = PlayerStats.fromModeDict(statistics[m] as Map<String, dynamic>?);
      if (s != null) modes[m] = s;
    }
    return Player(
      accountId: info['account_id'],
      nickname: info['nickname'],
      hidden: false,
      modeStats: modes,
    );
  }
}
