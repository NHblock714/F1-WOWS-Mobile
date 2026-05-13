import 'package:flutter/material.dart';
import '../analysis/challenges.dart';
import '../theme.dart';

class ChallengeList extends StatelessWidget {
  final List<Challenge> completed;
  const ChallengeList({super.key, required this.completed});

  static const _palette = [
    AppColors.gold, AppColors.green, AppColors.blue,
    Color(0xFF9B59B6), Color(0xFFE67E22), Color(0xFF1ABC9C),
    Color(0xFFE84393), Color(0xFF3498DB), Color(0xFFF1C40F),
    Color(0xFF16A085), Color(0xFFD35400),
  ];

  @override
  Widget build(BuildContext context) {
    if (completed.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('还没有达成任何挑战',
            style: TextStyle(color: AppColors.textDim, fontStyle: FontStyle.italic, fontSize: 12)),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < completed.length; i++)
          _ChallengeCard(c: completed[i], pillColor: _palette[i % _palette.length]),
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Challenge c;
  final Color pillColor;
  const _ChallengeCard({required this.c, required this.pillColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(c.name,
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11),
                children: [
                  TextSpan(text: '（${c.condText}）',
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                  TextSpan(text: '  ${c.desc}',
                      style: const TextStyle(color: AppColors.textDim)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
