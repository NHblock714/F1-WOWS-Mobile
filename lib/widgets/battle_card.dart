import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../analysis/battle_style.dart';
import '../analysis/benchmarks.dart';
import '../analysis/personal_rating.dart';
import '../api/wg_api.dart';
import '../models/player.dart';
import '../models/ship_record.dart';
import '../theme.dart';
import 'radar_chart.dart';

/// 战绩名片 - 用 RepaintBoundary 捕获为 PNG.
/// 固定宽度 380 px (逻辑), 打 3x 后约 1140px.
class BattleCard extends StatelessWidget {
  final Player player;
  final Region region;
  final int battlePower;
  final double pr;
  final Map<String, (double, double)> scores;
  final double overall;
  final List<BattleStyle> styles;
  final ShipRecord? aceShip;
  final String signature;
  final String qrUrl;

  const BattleCard({
    super.key,
    required this.player,
    required this.region,
    required this.battlePower,
    required this.pr,
    required this.scores,
    required this.overall,
    required this.styles,
    required this.aceShip,
    required this.signature,
    required this.qrUrl,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final date = DateFormat('yyyy.MM.dd').format(DateTime.now());

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 380,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E1A2E), Color(0xFF16243F)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(date),
            const SizedBox(height: 12),
            _playerName(),
            const SizedBox(height: 12),
            _battlePowerCard(fmt),
            const SizedBox(height: 14),
            _radar(),
            if (aceShip != null) ...[
              const SizedBox(height: 12),
              _aceShipBlock(aceShip!, fmt),
            ],
            if (styles.isNotEmpty) ...[
              const SizedBox(height: 12),
              _stylesBlock(),
            ],
            if (signature.isNotEmpty) ...[
              const SizedBox(height: 16),
              _signature(),
            ],
            const SizedBox(height: 16),
            _qrFooter(),
          ],
        ),
      ),
    );
  }

  Widget _header(String date) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('⚓ F1 WOWS',
              style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          Text('${region.displayName}  ·  $date',
              style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        ],
      );

  Widget _playerName() => Text(
        player.nickname,
        style: const TextStyle(
            color: AppColors.text,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            fontStyle: FontStyle.italic),
      );

  Widget _battlePowerCard(NumberFormat fmt) {
    final bg = Color(PrColor.fromPr(pr));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: bg.withAlpha(120), blurRadius: 20, spreadRadius: 1),
        ],
      ),
      child: Column(children: [
        const Text('BATTLE POWER',
            style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                letterSpacing: 4,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(fmt.format(battlePower),
            style: const TextStyle(
                color: AppColors.gold,
                fontSize: 44,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 1)),
      ]),
    );
  }

  Widget _radar() => SizedBox(
        height: 280,
        child: RadarChart(scores: scores, overall: overall),
      );

  Widget _aceShipBlock(ShipRecord ace, NumberFormat fmt) {
    final cls = Benchmarks.classDisplayZh[ace.type] ?? ace.type;
    final bp = computeShipBattlePower(ace.shipPr, ace.battles);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldDeep, width: 1),
      ),
      child: Row(children: [
        SizedBox(
          width: 100,
          height: 50,
          child: ace.imageContour != null
              ? CachedNetworkImage(
                  imageUrl: ace.imageContour!,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.directions_boat, color: AppColors.textFaded),
                )
              : const Icon(Icons.directions_boat, color: AppColors.textFaded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('⭐ 本命舰: ${ace.name}',
                style: const TextStyle(
                    color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('T${ace.tier} · $cls · 战力 ${fmt.format(bp)}',
                style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
            Text(
                '场次 ${ace.battles} · 胜率 ${(ace.winRate * 100).toStringAsFixed(1)}% · 伤害 ${fmt.format(ace.avgDamage.round())}',
                style: const TextStyle(color: AppColors.text, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }

  Widget _stylesBlock() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final s in styles.take(4))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.bgPanel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.goldDeep, width: 1),
            ),
            child: Text('${s.emoji} ${s.name}',
                style: const TextStyle(
                    color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _signature() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppColors.goldDeep.withAlpha(180), width: 3),
          ),
        ),
        child: Text(
          signature,
          style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500),
        ),
      );

  Widget _qrFooter() => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.bgPanel,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.goldDeep, width: 1),
            ),
            child: QrImageView(
              data: qrUrl,
              version: QrVersions.auto,
              size: 76,
              backgroundColor: AppColors.bgPanel,
              foregroundColor: AppColors.gold,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              gapless: true,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('扫码下载 F1 WOWS',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('GitHub · NHblock714/F1-WOWS-Mobile',
                    style: TextStyle(color: AppColors.textDim, fontSize: 10)),
              ],
            ),
          ),
        ],
      );
}

/// QR 链接: GitHub Releases 页面.
String buildPlayerQrUrl(Region region, int accountId, String nickname) {
  // region/accountId/nickname 保留参数签名兼容性, 此处实际不用.
  return 'https://github.com/NHblock714/F1-WOWS-Mobile/releases';
}
