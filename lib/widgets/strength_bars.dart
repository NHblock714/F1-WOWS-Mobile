import 'package:flutter/material.dart';
import '../theme.dart';

class StrengthBars extends StatelessWidget {
  final Map<String, (double, double)> scores;
  const StrengthBars({super.key, required this.scores});

  Color _barColor(double score) {
    if (score >= 100) return AppColors.gold;
    if (score >= 70) return AppColors.green;
    if (score >= 40) return AppColors.orange;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) return const SizedBox.shrink();
    // sort by score desc
    final items = scores.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    const maxScore = 130.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        children: [
          for (final e in items) Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              SizedBox(width: 72,
                child: Text(e.key, style: const TextStyle(color: AppColors.textDim, fontSize: 11), textAlign: TextAlign.right)),
              const SizedBox(width: 6),
              Expanded(
                child: Stack(children: [
                  // 服务器均值参考线 (score 40)
                  Container(height: 12, decoration: BoxDecoration(
                      color: AppColors.bgPanel, borderRadius: BorderRadius.circular(3))),
                  Container(
                    height: 12,
                    width: MediaQuery.of(context).size.width *
                        (e.value.$2.clamp(0, maxScore) / maxScore) * 0.45,
                    decoration: BoxDecoration(
                      color: _barColor(e.value.$2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 6),
              SizedBox(width: 32,
                child: Text(e.value.$2.round().toString(),
                  style: TextStyle(color: _barColor(e.value.$2), fontSize: 11, fontWeight: FontWeight.bold))),
            ]),
          ),
        ],
      ),
    );
  }
}
