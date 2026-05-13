import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../analysis/battle_style.dart';
import '../theme.dart';

class BattleStyleList extends StatelessWidget {
  final List<BattleStyle> styles;
  const BattleStyleList({super.key, required this.styles});

  static const _palette = [
    AppColors.gold, AppColors.green, AppColors.blue,
    Color(0xFF9B59B6), Color(0xFFE67E22), Color(0xFF1ABC9C),
    Color(0xFFE84393), Color(0xFF3498DB), Color(0xFFF1C40F),
    Color(0xFF16A085), Color(0xFFD35400),
  ];

  @override
  Widget build(BuildContext context) {
    if (styles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('暂无可推断的风格', style: TextStyle(color: AppColors.textDim)),
      );
    }
    final fmt = NumberFormat('#,###');
    return Column(
      children: [
        for (int i = 0; i < styles.length; i++)
          _StyleCard(
            style: styles[i],
            pillColor: _palette[i % _palette.length],
            fmt: fmt,
          ),
      ],
    );
  }
}

class _StyleCard extends StatelessWidget {
  final BattleStyle style;
  final Color pillColor;
  final NumberFormat fmt;
  const _StyleCard({required this.style, required this.pillColor, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(style.name,
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          if (style.power > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.gold.withAlpha(60)),
              ),
              child: Text('战力 +${fmt.format(style.power)}',
                  style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(style.desc,
                style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
