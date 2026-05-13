import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

/// 雷达图 (8 轴, 与 PC RadarChart 一致).
class RadarChart extends StatelessWidget {
  final Map<String, (double raw, double score)> scores;
  final double overall;

  const RadarChart({super.key, required this.scores, required this.overall});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _RadarPainter(scores: scores, overall: overall),
        child: Container(),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Map<String, (double, double)> scores;
  final double overall;

  _RadarPainter({required this.scores, required this.overall});

  /// 4 档主色 (与 PC qt_charts._polygon_color 一致).
  /// 5 档评级 (与 _gradeForScore 同步): 金 / 紫 / 蓝 / 绿 / 红
  Color _polygonColor() {
    if (overall >= 100) return AppColors.gold;
    if (overall >= 70)  return AppColors.purple;
    if (overall >= 40)  return AppColors.blue;
    if (overall >= 10)  return AppColors.green;
    return AppColors.red;
  }

  /// 5 档评级: S 金 (100+) / A 紫 (70-100) / B 蓝 (40-70) / C 绿 (10-40) / D 红 (<10).
  ({String letter, Color color}) _gradeForScore(double score) {
    if (score >= 100) return (letter: 'S', color: AppColors.gold);
    if (score >= 70)  return (letter: 'A', color: AppColors.purple);
    if (score >= 40)  return (letter: 'B', color: AppColors.blue);
    if (score >= 10)  return (letter: 'C', color: AppColors.green);
    return (letter: 'D', color: AppColors.red);
  }

  String _fmtValue(String label, double raw) {
    final percentMetrics = {'胜率', '生存率', '主炮命中', '🐴含量', '隐藏🐴'};
    if (percentMetrics.contains(label)) {
      return '${(raw * 100).toStringAsFixed(1)}%';
    }
    if (label == '场均抗伤' || label == '场均侦查') {
      return '${(raw / 1000).round()}k';
    }
    if (raw >= 100) {
      return NumberFormat('#,###').format(raw.round());
    }
    return raw.toStringAsFixed(2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final labels = scores.keys.toList();
    final values = scores.values.map((v) => v.$2).toList();
    final n = labels.length;
    if (n == 0) return;

    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final rMax = side / 2 - 60;
    final rForScore = (double s) => rMax * (s < 0 ? 0 : s) / 130.0;
    final angles = List.generate(n, (i) => 2 * math.pi * i / n - math.pi / 2);

    // 网格圈
    for (final (gs, dashed) in [(40, true), (70, false), (100, false)]) {
      final r = rForScore(gs.toDouble());
      final path = Path();
      for (int i = 0; i < n; i++) {
        final p = Offset(center.dx + r * math.cos(angles[i]), center.dy + r * math.sin(angles[i]));
        if (i == 0) path.moveTo(p.dx, p.dy);
        else path.lineTo(p.dx, p.dy);
      }
      path.close();
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = dashed ? const Color(0xFF78551E) : const Color(0xFF505058);
      if (dashed) {
        _drawDashedPath(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }

    // 径向轴
    final axisPaint = Paint()
      ..color = const Color(0xFF3C3C44)
      ..strokeWidth = 1;
    final rOuter = rForScore(130);
    for (final a in angles) {
      canvas.drawLine(center,
          Offset(center.dx + rOuter * math.cos(a), center.dy + rOuter * math.sin(a)), axisPaint);
    }

    // 玩家多边形 (单色, 由总平均分决定颜色档位)
    final color = _polygonColor();
    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final r = rForScore(values[i]);
      pts.add(Offset(center.dx + r * math.cos(angles[i]), center.dy + r * math.sin(angles[i])));
    }
    final polyPath = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < n; i++) {
      polyPath.lineTo(pts[i].dx, pts[i].dy);
    }
    polyPath.close();
    canvas.drawPath(polyPath, Paint()
      ..color = color.withAlpha(75)
      ..style = PaintingStyle.fill);
    canvas.drawPath(polyPath, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8);

    // 顶点
    final dotPaint = Paint()..color = color;
    for (final p in pts) {
      canvas.drawCircle(p, 4, dotPaint);
    }

    // ★BEST 光晕
    for (int i = 0; i < n; i++) {
      if (values[i] >= 95) {
        for (final (r, a) in [(14, 35), (10, 80), (6, 200)]) {
          canvas.drawCircle(pts[i],
              r.toDouble(),
              Paint()..color = AppColors.gold.withAlpha(a));
        }
      }
    }

    // 标签 (名称 + 数值 + ★BEST)
    final tp = TextPainter(textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center);
    final defaultRLabel = rMax + 30;
    for (int i = 0; i < n; i++) {
      final a = angles[i];
      final polyR = rForScore(values[i]);
      final rLabel = math.max(defaultRLabel, polyR + 42);
      final cx = center.dx + rLabel * math.cos(a);
      final cy = center.dy + rLabel * math.sin(a);
      final isBest = values[i] >= 95;
      final raw = scores[labels[i]]!.$1;
      final valueText = _fmtValue(labels[i], raw);

      final grade = _gradeForScore(values[i]);

      // 名称 + 评级徽章 (同一行: "胜率 [S]")
      tp.text = TextSpan(children: [
        TextSpan(text: '${labels[i]} ',
            style: TextStyle(
              color: isBest ? AppColors.gold : AppColors.text,
              fontSize: 11,
            )),
        TextSpan(text: grade.letter,
            style: TextStyle(
              color: grade.color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            )),
      ]);
      tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - 18));
      // 值
      tp.text = TextSpan(text: valueText,
          style: TextStyle(
            color: isBest ? AppColors.gold : AppColors.text,
            fontSize: 13, fontWeight: FontWeight.bold));
      tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - 4));
      // BEST
      if (isBest) {
        tp.text = const TextSpan(text: '★BEST',
            style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold));
        tp.layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, cy + 12));
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 5.0, dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + dashWidth, metric.length)),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.scores != scores || old.overall != overall;
}
