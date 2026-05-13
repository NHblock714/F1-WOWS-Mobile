import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../analysis/benchmarks.dart';
import '../analysis/personal_rating.dart';
import '../models/ship_record.dart';
import '../theme.dart';

class AceShipCard extends StatelessWidget {
  final List<ShipRecord> ships;
  const AceShipCard({super.key, required this.ships});

  ShipRecord? get _ace {
    if (ships.isEmpty) return null;
    // PC 同算法: 场次门槛 80→30→10→1 依次降, ace_score = ship_pr × √battles
    for (final minB in [80, 30, 10, 1]) {
      final cand = ships.where((r) => r.battles >= minB && r.shipPr != null).toList();
      if (cand.isEmpty) continue;
      cand.sort((a, b) {
        final sa = (a.shipPr ?? 0) * math.sqrt(a.battles);
        final sb = (b.shipPr ?? 0) * math.sqrt(b.battles);
        return sb.compareTo(sa);
      });
      return cand.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ace = _ace;
    if (ace == null) {
      return const SizedBox.shrink();
    }
    final fmt = NumberFormat('#,###');
    final cls = Benchmarks.classDisplayZh[ace.type] ?? ace.type;
    final bp = computeShipBattlePower(ace.shipPr, ace.battles);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // 战舰剪影
            SizedBox(
              width: 120,
              height: 80,
              child: ace.imageContour != null
                  ? CachedNetworkImage(
                      imageUrl: ace.imageContour!,
                      placeholder: (_, __) => const Center(
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: AppColors.textFaded),
                    )
                  : const Icon(Icons.directions_boat, color: AppColors.textFaded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⭐ ${ace.name}',
                    style: const TextStyle(
                      color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Text('T${ace.tier} · $cls · ${(ace.nation ?? '').toUpperCase()}',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                  const SizedBox(height: 6),
                  Text('战力 ${fmt.format(bp)}',
                      style: const TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '场次 ${ace.battles} · 胜率 ${(ace.winRate * 100).toStringAsFixed(1)}% · 伤害 ${fmt.format(ace.avgDamage.round())}',
                    style: const TextStyle(color: AppColors.text, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
