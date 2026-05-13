import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../analysis/battle_style.dart';
import '../analysis/challenges.dart';
import '../analysis/personal_rating.dart';
import '../analysis/radar_scores.dart';
import '../api/wg_api.dart';
import '../models/ship_record.dart';
import '../services/player_data_service.dart';
import '../theme.dart';
import '../widgets/app_footer.dart';
import '../widgets/battle_card.dart';

class BattleCardScreen extends StatefulWidget {
  final PlayerData data;
  final Region region;
  const BattleCardScreen({super.key, required this.data, required this.region});

  @override
  State<BattleCardScreen> createState() => _BattleCardScreenState();
}

class _BattleCardScreenState extends State<BattleCardScreen> {
  final GlobalKey _cardKey = GlobalKey();
  final TextEditingController _sigCtrl = TextEditingController();
  static const int _maxSigLen = 30;
  bool _saving = false;

  @override
  void dispose() {
    _sigCtrl.dispose();
    super.dispose();
  }

  /// 用 PC 同算法挑本命舰: 场次门槛 80→30→10→1 依次降, ace_score = ship_pr × √battles
  ShipRecord? _pickAceShip(List<ShipRecord> ships) {
    if (ships.isEmpty) return null;
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

  Future<Uint8List?> _captureCard() async {
    try {
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // 等一帧确保渲染完成
      await WidgetsBinding.instance.endOfFrame;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('截图失败: $e'), backgroundColor: AppColors.red),
        );
      }
      return null;
    }
  }

  Future<void> _share() async {
    setState(() => _saving = true);
    try {
      final bytes = await _captureCard();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/F1WOWS_${widget.data.player.nickname}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'F1 WOWS 战绩名片 · ${widget.data.player.nickname}',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final stats = data.player.stats;
    if (stats == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('生成战绩名片')),
        body: const Center(child: Text('无 PVP 战绩, 无法生成名片', style: TextStyle(color: AppColors.textDim))),
      );
    }

    final scores = computeOverviewScores(stats, data.ships, data.nDmg, data.nFrags, data.nWr);
    final overall = scores.isEmpty ? 0.0 :
        scores.values.fold<double>(0, (a, v) => a + v.$2) / scores.length;
    final styles = inferBattleStyles(scores, stats, data.ships);
    final challenges = getCompletedChallenges(stats, data.ships);
    final mods = computeBattlePowerModifiers(data.ships, challenges.length);
    final boostedBP = applyBattlePowerModifiers(data.battlePower, mods);
    final ace = _pickAceShip(data.ships);
    final qrUrl = buildPlayerQrUrl(widget.region, data.player.accountId, data.player.nickname);

    return Scaffold(
      appBar: AppBar(title: const Text('生成战绩名片')),
      bottomNavigationBar: const SafeArea(
        child: Padding(padding: EdgeInsets.only(bottom: 6, top: 4), child: AppFooter()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: BattleCard(
                      player: data.player,
                      region: widget.region,
                      battlePower: boostedBP,
                      pr: data.pr,
                      scores: scores,
                      overall: overall,
                      styles: styles,
                      aceShip: ace,
                      signature: _sigCtrl.text.trim(),
                      qrUrl: qrUrl,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: const BoxDecoration(
                color: AppColors.bgPanel,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _sigCtrl,
                    maxLength: _maxSigLen,
                    decoration: InputDecoration(
                      hintText: '写一句签名 (可留空)',
                      hintStyle: const TextStyle(color: AppColors.textFaded),
                      counterStyle: const TextStyle(color: AppColors.textFaded, fontSize: 10),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.preview, size: 18),
                        label: const Text('刷新预览'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gold,
                          side: const BorderSide(color: AppColors.goldDeep),
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: () => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.ios_share, size: 18),
                        label: Text(_saving ? '生成中...' : '保存 / 分享'),
                        onPressed: _saving ? null : _share,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
