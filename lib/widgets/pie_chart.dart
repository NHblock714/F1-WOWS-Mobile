import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

class PieSlice {
  final String label;
  final int value;
  final Color color;
  PieSlice(this.label, this.value, this.color);
}

class ClassPieChart extends StatelessWidget {
  final List<PieSlice> slices;
  const ClassPieChart({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty || slices.every((s) => s.value == 0)) {
      return const SizedBox.shrink();
    }
    return Row(children: [
      SizedBox(width: 110, height: 110,
        child: CustomPaint(painter: _PiePainter(slices: slices))),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in slices) Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Container(width: 12, height: 12,
                  decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(child: Text(s.label,
                  style: const TextStyle(color: AppColors.text, fontSize: 12))),
                Text('${s.value}',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
              ]),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _PiePainter extends CustomPainter {
  final List<PieSlice> slices;
  _PiePainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (a, s) => a + s.value);
    if (total <= 0) return;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) / 2 - 2,
    );
    double startAngle = -math.pi / 2;
    for (final s in slices) {
      final sweep = 2 * math.pi * s.value / total;
      canvas.drawArc(rect, startAngle, sweep, true,
          Paint()..color = s.color..style = PaintingStyle.fill);
      canvas.drawArc(rect, startAngle, sweep, true,
          Paint()..color = AppColors.bgDark..style = PaintingStyle.stroke..strokeWidth = 1.5);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter o) => o.slices != slices;
}
