/// 从百科火炮参数推算"机械精度": (射程_m / 散布_m) × (弹速 / 800).
/// 数值越大 = 该舰天生越准. 返回 null = 无数据 (CV/Sub 通常).
double? mechanicalAccuracy(Map<String, dynamic>? artillery) {
  if (artillery == null) return null;
  final maxDisp = (artillery['max_dispersion'] as num?)?.toDouble();
  final distanceKm = (artillery['distance'] as num?)?.toDouble();
  if (maxDisp == null || distanceKm == null || maxDisp <= 0) return null;
  final shells = artillery['shells'] as Map?;
  if (shells == null) return null;
  double? velocity;
  for (final t in ['AP', 'HE', 'SAP']) {
    final s = shells[t];
    if (s is Map && s['bullet_speed'] != null) {
      velocity = (s['bullet_speed'] as num).toDouble();
      break;
    }
  }
  if (velocity == null) return null;
  final rangeM = distanceKm * 1000;
  return (rangeM / maxDisp) * (velocity / 800.0);
}

/// 每个舰种的平均机械精度, 用于把单船精度归一到 ~1.0.
Map<String, double> computeClassAccuracyMeans(Map<String, dynamic> encyclopedia) {
  final byClass = <String, List<double>>{};
  encyclopedia.forEach((sid, meta) {
    if (meta is! Map) return;
    final cls = meta['type']?.toString();
    final profile = meta['default_profile'] as Map?;
    final art = profile?['artillery'] as Map<String, dynamic>?;
    final acc = mechanicalAccuracy(art);
    if (cls != null && acc != null) {
      byClass.putIfAbsent(cls, () => []).add(acc);
    }
  });
  return {
    for (final e in byClass.entries)
      if (e.value.isNotEmpty)
        e.key: e.value.reduce((a, b) => a + b) / e.value.length,
  };
}
