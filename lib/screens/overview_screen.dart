import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../analysis/battle_style.dart';
import '../analysis/challenges.dart';
import '../analysis/personal_rating.dart';
import '../analysis/radar_scores.dart';
import '../analysis/single_ship.dart';
import '../api/wg_api.dart';
import '../models/player.dart';
import '../models/ship_record.dart';
import '../services/player_data_service.dart';
import '../theme.dart';
import '../widgets/ace_ship_card.dart';
import '../widgets/app_footer.dart';
import '../widgets/battle_style_list.dart';
import '../widgets/challenge_list.dart';
import '../widgets/constellation_background.dart';
import '../widgets/pie_chart.dart';
import '../widgets/radar_chart.dart';
import '../widgets/strength_bars.dart';

class OverviewScreen extends StatefulWidget {
  final Region region;
  final int accountId;
  final String nickname;

  const OverviewScreen({
    super.key,
    required this.region,
    required this.accountId,
    required this.nickname,
  });

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> with SingleTickerProviderStateMixin {
  PlayerData? _data;
  String? _error;
  bool _loading = true;
  String _status = '正在加载玩家数据 ...';
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final svc = PlayerDataService(widget.region);
    try {
      final data = await svc.load(widget.accountId, (msg) {
        if (mounted) setState(() => _status = msg);
      });
      if (mounted) setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      svc.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nickname),
        bottom: _loading || _error != null || (_data?.player.hidden ?? false)
            ? null
            : TabBar(
                controller: _tab,
                indicatorColor: AppColors.gold,
                labelColor: AppColors.gold,
                unselectedLabelColor: AppColors.textDim,
                tabs: const [
                  Tab(text: '📊 总览'),
                  Tab(text: '🎮 各模式'),
                  Tab(text: '⚓ 战舰'),
                ],
              ),
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : (_data?.player.hidden ?? false)
                  ? _buildHidden()
                  : TabBarView(
                      controller: _tab,
                      children: [
                        _OverviewTab(data: _data!),
                        _ModesTab(data: _data!),
                        _ShipsTab(data: _data!),
                      ],
                    ),
    );
  }

  Widget _buildLoading() => Stack(
    children: [
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.gold),
            const SizedBox(height: 16),
            Text(_status, style: const TextStyle(color: AppColors.textDim)),
          ],
        ),
      ),
      const Positioned(
        bottom: 12, left: 0, right: 0,
        child: AppFooter(),
      ),
    ],
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(_error ?? '', style: const TextStyle(color: AppColors.red)),
    ),
  );

  Widget _buildHidden() => ConstellationBackground(
    nodeCount: 35,
    connectDist: 160,
    color: const Color(0xFF9759BC),
    pointAlpha: 180,
    lineAlpha: 90,
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🐴', style: TextStyle(fontSize: 100)),
          SizedBox(height: 16),
          Text('我  是  隐  藏  马',
              style: TextStyle(color: AppColors.gold, fontSize: 32,
                  fontWeight: FontWeight.w900, letterSpacing: 4)),
          SizedBox(height: 12),
          Text('该玩家在 Wargaming 官网勾了"隐藏战绩"',
              style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          SizedBox(height: 4),
          Text('如果是你自己, asia.wargaming.net/personal 取消勾选即可解锁',
              style: TextStyle(color: AppColors.textFaded, fontSize: 11)),
        ],
      ),
    ),
  );
}

class _OverviewTab extends StatefulWidget {
  final PlayerData data;
  const _OverviewTab({required this.data});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  String? _filterClass;  // null = 总体
  int? _filterTier;      // null = 全部

  /// 计算筛选后的 (stats, ships, nDmg, nFrags, nWr).
  ({PlayerStats stats, List<ShipRecord> ships, double nDmg, double nFrags, double nWr})?
      _filtered() {
    final all = widget.data.ships;
    var sub = all;
    if (_filterClass != null) sub = sub.where((r) => r.type == _filterClass).toList();
    if (_filterTier != null) sub = sub.where((r) => r.tier == _filterTier).toList();
    if (sub.isEmpty) return null;
    final isFull = _filterClass == null && _filterTier == null;
    final stats = isFull ? widget.data.player.stats! : PlayerStats.fromShipsAggregate(sub);
    // PR aggregate for the subset
    double tD = 0, tF = 0, tW = 0, tB = 0;
    for (final r in sub) {
      if (r.nDmg == null) continue;
      final b = r.battles.toDouble();
      tB += b;
      tD += r.nDmg! * b;
      tF += r.nFrags! * b;
      tW += r.nWr! * b;
    }
    return (
      stats: stats, ships: sub,
      nDmg: tB > 0 ? tD / tB : 0,
      nFrags: tB > 0 ? tF / tB : 0,
      nWr: tB > 0 ? tW / tB : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final stats = data.player.stats;
    if (stats == null) return const Center(child: Text('无 PVP 战绩'));

    final fmt = NumberFormat('#,###');
    // 总览雷达 (受筛选影响)
    final filtered = _filtered();
    final scoresStats = filtered?.stats ?? stats;
    final scoresShips = filtered?.ships ?? data.ships;
    final scoresNDmg = filtered?.nDmg ?? data.nDmg;
    final scoresNFrags = filtered?.nFrags ?? data.nFrags;
    final scoresNWr = filtered?.nWr ?? data.nWr;
    final scores = computeOverviewScores(scoresStats, scoresShips, scoresNDmg, scoresNFrags, scoresNWr);
    final overall = scores.isEmpty ? 0.0 :
        scores.values.fold<double>(0, (a, v) => a + v.$2) / scores.length;
    // 风格/挑战/战力 用全局数据 (不受筛选)
    final styles = inferBattleStyles(
        computeOverviewScores(stats, data.ships, data.nDmg, data.nFrags, data.nWr),
        stats, data.ships);
    final challenges = getCompletedChallenges(stats, data.ships);

    final mods = computeBattlePowerModifiers(data.ships, challenges.length);
    final boostedBP = applyBattlePowerModifiers(data.battlePower, mods);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 战力卡 (含星座背景)
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            color: Color(PrColor.fromPr(data.pr)),
            child: ConstellationBackground(
              nodeCount: 28,
              connectDist: 110,
              color: Colors.white.withAlpha(180),
              pointAlpha: 150,
              lineAlpha: 60,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('BATTLE POWER',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 6,
                            fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    Text(fmt.format(boostedBP),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.gold, fontSize: 50,
                            fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 2)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 雷达 + 维度/等级筛选 + strength bars
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              const Padding(padding: EdgeInsets.only(top: 4),
                  child: Text('🎯 战力雷达图',
                      style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold))),
              _RadarFilterRow(
                ships: data.ships,
                cls: _filterClass,
                tier: _filterTier,
                onClass: (v) => setState(() => _filterClass = v),
                onTier: (v) => setState(() => _filterTier = v),
              ),
              if (filtered == null)
                const Padding(padding: EdgeInsets.all(40),
                  child: Text('筛选下无数据', style: TextStyle(color: AppColors.textDim)))
              else ...[
                RadarChart(scores: scores, overall: overall),
                const Divider(color: AppColors.border, height: 1),
                StrengthBars(scores: scores),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // 战斗风格
        _Section('⚔️ 战斗风格', BattleStyleList(styles: styles)),
        // 终极挑战
        _Section('🏅 终极挑战', ChallengeList(completed: challenges)),
        // 本命战舰
        const SizedBox(height: 4),
        AceShipCard(ships: data.ships),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section(this.title, this.child);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(title, style: const TextStyle(
                    color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// _StrengthsBlock removed; replaced by StrengthBars widget showing all 8 metrics.

class _RadarFilterRow extends StatelessWidget {
  final List<ShipRecord> ships;
  final String? cls;
  final int? tier;
  final void Function(String?) onClass;
  final void Function(int?) onTier;
  const _RadarFilterRow({
    required this.ships, required this.cls, required this.tier,
    required this.onClass, required this.onTier,
  });

  static const _classes = [
    ('总体', null),
    ('战列舰', 'Battleship'),
    ('巡洋舰', 'Cruiser'),
    ('驱逐舰', 'Destroyer'),
    ('航母', 'AirCarrier'),
    ('潜艇', 'Submarine'),
  ];

  @override
  Widget build(BuildContext context) {
    // 仅显示玩家有的舰种
    final availableTypes = ships.map((r) => r.type).toSet();
    final classItems = _classes.where((c) => c.$2 == null || availableTypes.contains(c.$2)).toList();
    final availableTiers = (ships.map((r) => r.tier).toSet().toList()..sort());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        const Text('维度', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
        const SizedBox(width: 6),
        Expanded(
          child: DropdownButton<String?>(
            value: cls,
            isExpanded: true,
            dropdownColor: AppColors.bgPanel,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: AppColors.text, fontSize: 12),
            items: [for (final (label, val) in classItems)
              DropdownMenuItem(value: val, child: Text(label))],
            onChanged: onClass,
          ),
        ),
        const SizedBox(width: 12),
        const Text('等级', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
        const SizedBox(width: 6),
        SizedBox(width: 80,
          child: DropdownButton<int?>(
            value: tier,
            isExpanded: true,
            dropdownColor: AppColors.bgPanel,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: AppColors.text, fontSize: 12),
            items: [
              const DropdownMenuItem(value: null, child: Text('全部')),
              for (final t in availableTiers)
                DropdownMenuItem(value: t, child: Text('T$t')),
            ],
            onChanged: onTier,
          ),
        ),
      ]),
    );
  }
}

class _ModesTab extends StatefulWidget {
  final PlayerData data;
  const _ModesTab({required this.data});

  @override
  State<_ModesTab> createState() => _ModesTabState();
}

class _ModesTabState extends State<_ModesTab> with TickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    final modes = widget.data.player.availableModes;
    _tab = TabController(length: modes.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modes = widget.data.player.availableModes;
    if (modes.isEmpty) {
      return const Center(child: Text('无任何模式数据', style: TextStyle(color: AppColors.textDim)));
    }
    return Column(
      children: [
        Container(
          color: AppColors.bgPanel,
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.textDim,
            tabs: [for (final m in modes) Tab(text: modeDisplayZh[m] ?? m)],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              for (final m in modes)
                _ModeDetail(stats: widget.data.player.modeStats[m]!, isOperation: m.startsWith('oper_')),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeDetail extends StatelessWidget {
  final PlayerStats stats;
  final bool isOperation;
  const _ModeDetail({required this.stats, required this.isOperation});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _row('场次', fmt.format(stats.battles)),
              _row('胜率', '${(stats.winRate * 100).toStringAsFixed(2)}%'),
              _row('场均伤害', fmt.format(stats.avgDamage.toInt())),
              _row('场均经验', fmt.format(stats.avgXp.toInt())),
              _row('场均击杀', stats.avgFrags.toStringAsFixed(2)),
              _row('生存率', '${(stats.survivalRate * 100).toStringAsFixed(2)}%'),
              if (!isOperation) _row('K/D', stats.kdRatio.toStringAsFixed(2)),
              _row('主炮命中率', '${(stats.mainBatteryHitRate * 100).toStringAsFixed(2)}%'),
              const Divider(color: AppColors.border),
              _row('单场最高伤害', fmt.format(stats.maxDamageDealt)),
              _row('单场最高经验', fmt.format(stats.maxXp)),
              _row('单场最高击杀', stats.maxFragsBattle.toString()),
              _row('平局', stats.draws.toString()),
              _row('冲撞击沉', stats.rammingFrags.toString()),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textDim)),
        Text(value, style: const TextStyle(
            color: AppColors.text, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _ShipsTab extends StatefulWidget {
  final PlayerData data;
  const _ShipsTab({required this.data});

  @override
  State<_ShipsTab> createState() => _ShipsTabState();
}

class _ShipsTabState extends State<_ShipsTab> {
  String _sortKey = 'battle_power'; // battle_power / battles / avg_damage / win_rate
  int? _filterTier;
  String? _filterClass;
  String? _filterNation;

  @override
  Widget build(BuildContext context) {
    final ships = widget.data.ships;
    if (ships.isEmpty) return const Center(child: Text('无战舰数据'));
    final fmt = NumberFormat('#,###');

    final tiers = ships.map((r) => r.tier).toSet().toList()..sort();
    final classes = ships.map((r) => r.type).toSet().toList()..sort();
    final nations = ships.where((r) => r.nation != null).map((r) => r.nation!).toSet().toList()..sort();

    // 舰种分布
    final classCounts = <String, int>{};
    for (final r in ships) {
      classCounts.update(r.type, (v) => v + r.battles, ifAbsent: () => r.battles);
    }
    final tierCounts = <int, int>{};
    for (final r in ships) {
      tierCounts.update(r.tier, (v) => v + r.battles, ifAbsent: () => r.battles);
    }
    final totalBattles = ships.fold<int>(0, (a, r) => a + r.battles);

    // 排序 + 过滤
    var filtered = ships.toList();
    if (_filterTier != null) filtered = filtered.where((r) => r.tier == _filterTier).toList();
    if (_filterClass != null) filtered = filtered.where((r) => r.type == _filterClass).toList();
    if (_filterNation != null) filtered = filtered.where((r) => r.nation == _filterNation).toList();
    filtered.sort((a, b) => switch (_sortKey) {
          'battles' => b.battles.compareTo(a.battles),
          'avg_damage' => b.avgDamage.compareTo(a.avgDamage),
          'win_rate' => b.winRate.compareTo(a.winRate),
          _ => (b.shipPr ?? 0).compareTo(a.shipPr ?? 0),
        });

    final classNames = const {
      'AirCarrier': '航母', 'Battleship': '战列',
      'Cruiser': '巡洋', 'Destroyer': '驱逐', 'Submarine': '潜艇',
    };

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('共 ${ships.length} 艘有战绩的舰船',
            style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        const SizedBox(height: 10),
        // 舰种分布 (CustomPaint 饼图)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🥧 舰种分布', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ClassPieChart(slices: [
                for (final entry in classCounts.entries)
                  PieSlice(
                    '${classNames[entry.key] ?? entry.key}  ${entry.value} (${(entry.value * 100 / totalBattles).toStringAsFixed(1)}%)',
                    entry.value,
                    _classColor(entry.key),
                  ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        // 等级分布
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('📊 等级分布', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _TierBar(counts: tierCounts),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        // 筛选: 等级 / 舰种 / 国家 (下拉)
        Row(children: [
          const SizedBox(width: 36, child: Text('等级', style: TextStyle(color: AppColors.textDim, fontSize: 12))),
          Expanded(child: DropdownButton<int?>(
            value: _filterTier, isExpanded: true, isDense: true,
            dropdownColor: AppColors.bgPanel, underline: const SizedBox.shrink(),
            style: const TextStyle(color: AppColors.text, fontSize: 12),
            items: [
              const DropdownMenuItem(value: null, child: Text('全部')),
              for (final t in tiers) DropdownMenuItem(value: t, child: Text('T$t')),
            ],
            onChanged: (v) => setState(() => _filterTier = v),
          )),
        ]),
        Row(children: [
          const SizedBox(width: 36, child: Text('舰种', style: TextStyle(color: AppColors.textDim, fontSize: 12))),
          Expanded(child: DropdownButton<String?>(
            value: _filterClass, isExpanded: true, isDense: true,
            dropdownColor: AppColors.bgPanel, underline: const SizedBox.shrink(),
            style: const TextStyle(color: AppColors.text, fontSize: 12),
            items: [
              const DropdownMenuItem(value: null, child: Text('全部')),
              for (final c in classes) DropdownMenuItem(value: c, child: Text(classNames[c] ?? c)),
            ],
            onChanged: (v) => setState(() => _filterClass = v),
          )),
        ]),
        Row(children: [
          const SizedBox(width: 36, child: Text('国家', style: TextStyle(color: AppColors.textDim, fontSize: 12))),
          Expanded(child: DropdownButton<String?>(
            value: _filterNation, isExpanded: true, isDense: true,
            dropdownColor: AppColors.bgPanel, underline: const SizedBox.shrink(),
            style: const TextStyle(color: AppColors.text, fontSize: 12),
            items: [
              const DropdownMenuItem(value: null, child: Text('全部')),
              for (final n in nations) DropdownMenuItem(value: n, child: Text(n.toUpperCase())),
            ],
            onChanged: (v) => setState(() => _filterNation = v),
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Text('排序: ', style: TextStyle(color: AppColors.textDim)),
          DropdownButton<String>(
            value: _sortKey,
            dropdownColor: AppColors.bgPanel,
            style: const TextStyle(color: AppColors.text),
            items: const [
              DropdownMenuItem(value: 'battle_power', child: Text('战力')),
              DropdownMenuItem(value: 'battles', child: Text('场次')),
              DropdownMenuItem(value: 'avg_damage', child: Text('伤害')),
              DropdownMenuItem(value: 'win_rate', child: Text('胜率')),
            ],
            onChanged: (v) => setState(() => _sortKey = v ?? 'battle_power'),
          ),
        ]),
        const SizedBox(height: 8),
        // 战舰榜
        for (final r in filtered.take(30))
          _ShipRow(record: r, fmt: fmt, classNames: classNames, onTap: () => _showShipRadar(r)),
        if (filtered.length > 30)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('… 还有 ${filtered.length - 30} 艘 (筛选缩小范围查看)',
                style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                textAlign: TextAlign.center),
          ),
      ],
    );
  }

  Color _classColor(String type) => switch (type) {
        'AirCarrier' => const Color(0xFF9467BD),
        'Battleship' => const Color(0xFFD62728),
        'Cruiser' => const Color(0xFFFF7F0E),
        'Destroyer' => const Color(0xFF2CA02C),
        'Submarine' => const Color(0xFF1F77B4),
        _ => const Color(0xFF888888),
      };

  void _showShipRadar(ShipRecord r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgPanel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ShipRadarSheet(record: r),
    );
  }
}

class _ShipRadarSheet extends StatelessWidget {
  final ShipRecord record;
  const _ShipRadarSheet({required this.record});

  @override
  Widget build(BuildContext context) {
    final result = computeSingleShipScores(record);
    final scores = result.scores;
    final confidence = result.confidence;
    final overall = scores.isEmpty ? 0.0 :
        scores.values.fold<double>(0, (a, v) => a + v.$2) / scores.length;
    final classNames = const {
      'AirCarrier': '航母', 'Battleship': '战列舰',
      'Cruiser': '巡洋舰', 'Destroyer': '驱逐舰', 'Submarine': '潜艇',
    };
    final fmt = NumberFormat('#,###');
    final bp = computeShipBattlePower(record.shipPr, record.battles);
    final threshold = record.tier >= 10 ? 80 : 40;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.textFaded, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 12),
          Text(record.name,
              style: const TextStyle(color: AppColors.text, fontSize: 22,
                  fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
          Text('T${record.tier} · ${classNames[record.type] ?? record.type} · ${(record.nation ?? '').toUpperCase()}',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          const SizedBox(height: 10),
          if (bp > 0)
            Text('战力 ${fmt.format(bp)}',
                style: const TextStyle(color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (confidence < 1.0)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.orange.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '⚠ 场次不足 (${record.battles} / $threshold 场), 各项评分已 ×${confidence.toStringAsFixed(2)} 修正',
                style: const TextStyle(color: AppColors.orange, fontSize: 11),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '✓ 场次充足 (≥ $threshold), 评分无修正',
                style: const TextStyle(color: AppColors.green, fontSize: 11),
              ),
            ),
          const SizedBox(height: 12),
          RadarChart(scores: scores, overall: overall),
          const SizedBox(height: 16),
          _detailRow('场次', '${record.battles}'),
          _detailRow('胜率', '${(record.winRate * 100).toStringAsFixed(2)}%'),
          _detailRow('场均伤害', fmt.format(record.avgDamage.round())),
          _detailRow('场均经验', fmt.format(record.avgXp.round())),
          _detailRow('场均击杀', record.avgFrags.toStringAsFixed(2)),
          _detailRow('生存率', '${(record.survivalRate * 100).toStringAsFixed(2)}%'),
          if (record.mainBatteryShots > 0)
            _detailRow('主炮命中率', '${(record.mainBatteryHitRate * 100).toStringAsFixed(2)}%'),
          if (record.torpedoesShots > 0)
            _detailRow('鱼雷命中率', '${(record.torpedoHitRate * 100).toStringAsFixed(2)}%'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _TierBar extends StatelessWidget {
  final Map<int, int> counts;
  const _TierBar({required this.counts});

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return const SizedBox.shrink();
    final maxV = counts.values.reduce((a, b) => a > b ? a : b);
    final sortedTiers = counts.keys.toList()..sort();
    return Column(
      children: [
        for (final t in sortedTiers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              SizedBox(width: 32, child: Text('T$t', style: const TextStyle(color: AppColors.text, fontSize: 11))),
              Expanded(
                child: LinearProgressIndicator(
                  value: counts[t]! / maxV,
                  minHeight: 14,
                  backgroundColor: AppColors.bgPanel,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(width: 52, child: Text('${counts[t]}',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 11), textAlign: TextAlign.right)),
            ]),
          ),
      ],
    );
  }
}

class _ShipRow extends StatelessWidget {
  final ShipRecord record;
  final NumberFormat fmt;
  final Map<String, String> classNames;
  final VoidCallback onTap;
  const _ShipRow({required this.record, required this.fmt, required this.classNames, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bp = computeShipBattlePower(record.shipPr, record.battles);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(record.name,
                  style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 13)),
              Text('T${record.tier} · ${classNames[record.type] ?? record.type}',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
            ]),
          ),
          Expanded(flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${record.battles}场',
                  style: const TextStyle(color: AppColors.text, fontSize: 11)),
              Text('${(record.winRate * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
            ]),
          ),
          Expanded(flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmt.format(record.avgDamage.round()),
                  style: const TextStyle(color: AppColors.text, fontSize: 11)),
              Text('伤害', style: TextStyle(color: AppColors.textDim, fontSize: 9)),
            ]),
          ),
          Expanded(flex: 2,
            child: Text(bp > 0 ? fmt.format(bp) : '—',
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
      ),
    );
  }
}
