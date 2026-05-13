/// 评分阈值 + 舰种/等级系数 (移植自 data/benchmarks.json).
class Benchmarks {
  static const base = <String, List<double>>{
    'win_rate': [0.47, 0.50, 0.53, 0.56, 0.60],
    'avg_damage': [30000, 50000, 70000, 100000, 130000],
    'avg_xp': [800, 1200, 1500, 1800, 2200],
    'avg_frags': [0.4, 0.7, 1.0, 1.3, 1.6],
    'survival_rate': [0.30, 0.40, 0.50, 0.60, 0.70],
    'main_battery_hit_rate': [0.165, 0.22, 0.275, 0.42, 0.54],
    'avg_potential_damage': [350000, 700000, 1150000, 1700000, 2400000],
    'avg_scouting_damage': [5000, 12000, 22000, 35000, 60000],
    'kd_ratio': [0.6, 1.0, 1.4, 1.9, 2.5],
  };

  /// class_factors[shipType][metric] — null = 不适用.
  static const classFactors = <String, Map<String, double?>>{
    'AirCarrier': {
      'avg_damage': 1.10, 'avg_frags': 1.40, 'survival_rate': 1.35,
      'main_battery_hit_rate': null,
      'avg_potential_damage': null, 'avg_scouting_damage': 4.50,
      'kd_ratio': 2.75,
    },
    'Battleship': {
      'avg_damage': 1.50, 'avg_frags': 0.70, 'survival_rate': 1.10,
      'main_battery_hit_rate': 0.80,
      'avg_potential_damage': 1.40, 'avg_scouting_damage': 0.40,
      'kd_ratio': 0.85,
    },
    'Cruiser': {
      'avg_damage': 1.00, 'avg_frags': 1.00, 'survival_rate': 1.00,
      'main_battery_hit_rate': 1.00,
      'avg_potential_damage': 1.00, 'avg_scouting_damage': 1.00,
      'kd_ratio': 1.00,
    },
    'Destroyer': {
      'avg_damage': 0.90, 'avg_frags': 1.25, 'survival_rate': 0.70,
      'main_battery_hit_rate': 1.20,
      'avg_potential_damage': 0.45, 'avg_scouting_damage': 2.40,
      'kd_ratio': 1.10,
    },
    'Submarine': {
      'avg_damage': 0.70, 'avg_frags': 0.90, 'survival_rate': 1.00,
      'main_battery_hit_rate': null,
      'avg_potential_damage': null, 'avg_scouting_damage': 1.50,
      'kd_ratio': 1.70,
    },
  };

  static const tierFactorsDmg = <int, double>{
    1: 0.15, 2: 0.25, 3: 0.35, 4: 0.45, 5: 0.60,
    6: 0.72, 7: 0.84, 8: 0.92, 9: 0.97, 10: 1.05, 11: 1.10,
  };

  static const tierFactorsXp = <int, double>{
    1: 0.50, 2: 0.55, 3: 0.62, 4: 0.70, 5: 0.78,
    6: 0.84, 7: 0.90, 8: 0.95, 9: 0.98, 10: 1.02, 11: 1.05,
  };

  static const tierFactorsAgro = <int, double>{
    1: 0.05, 2: 0.08, 3: 0.14, 4: 0.22, 5: 0.34,
    6: 0.48, 7: 0.62, 8: 0.80, 9: 0.93, 10: 1.05, 11: 1.10,
  };

  static const tierFactorsScout = <int, double>{
    1: 0.30, 2: 0.40, 3: 0.50, 4: 0.60, 5: 0.70,
    6: 0.78, 7: 0.85, 8: 0.92, 9: 0.97, 10: 1.05, 11: 1.10,
  };

  static const tierDifficulty = <int, double>{
    1: 0.55, 2: 0.60, 3: 0.66, 4: 0.72, 5: 0.78,
    6: 0.84, 7: 0.89, 8: 0.93, 9: 0.97, 10: 1.00, 11: 1.03,
  };

  static const classDisplayZh = <String, String>{
    'AirCarrier': '航母',
    'Battleship': '战列舰',
    'Cruiser': '巡洋舰',
    'Destroyer': '驱逐舰',
    'Submarine': '潜艇',
  };

  static double? classFactor(String shipType, String metric) {
    final map = classFactors[shipType];
    if (map == null) return 1.0;
    return map[metric] ?? (map.containsKey(metric) ? null : 1.0);
  }

  static double tierFactor(String metric, int tier) {
    return switch (metric) {
      'avg_damage' => tierFactorsDmg[tier] ?? 1.0,
      'avg_xp' => tierFactorsXp[tier] ?? 1.0,
      'avg_potential_damage' => tierFactorsAgro[tier] ?? 1.0,
      'avg_scouting_damage' => tierFactorsScout[tier] ?? 1.0,
      _ => 1.0,
    };
  }
}
