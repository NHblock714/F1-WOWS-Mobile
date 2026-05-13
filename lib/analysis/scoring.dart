/// 五点阈值评分 (与桌面端 analysis.py 同算法).
const scorePoints = [10.0, 40.0, 70.0, 100.0, 130.0];

double scoreValue(double value, List<double> thresholds) {
  if (value <= 0) return 0;
  if (value < thresholds[0]) {
    return scorePoints[0] * (value / thresholds[0]);
  }
  if (value >= thresholds.last * 1.5) {
    return scorePoints.last * 1.15;
  }
  // linear interpolation
  for (int i = 0; i < thresholds.length - 1; i++) {
    if (value <= thresholds[i + 1]) {
      final t = (value - thresholds[i]) / (thresholds[i + 1] - thresholds[i]);
      return scorePoints[i] + t * (scorePoints[i + 1] - scorePoints[i]);
    }
  }
  return scorePoints.last;
}
