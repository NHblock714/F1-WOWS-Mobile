import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../analysis/clan_scores.dart';
import '../analysis/personal_rating.dart';
import '../analysis/scoring.dart';
import '../api/wg_api.dart';
import '../models/clan.dart';
import '../models/ship_record.dart';
import '../services/clan_data_service.dart';
import '../services/clan_ships_loader.dart';
import '../theme.dart';
import '../widgets/app_footer.dart';
import '../widgets/radar_chart.dart';
import 'overview_screen.dart';

class ClanScreen extends StatefulWidget {
  final Region region;
  final int clanId;
  final String tag;
  final String name;

  const ClanScreen({
    super.key,
    required this.region,
    required this.clanId,
    required this.tag,
    required this.name,
  });

  @override
  State<ClanScreen> createState() => _ClanScreenState();
}

class _ClanScreenState extends State<ClanScreen> {
  ClanData? _data;
  String? _error;
  bool _loading = true;
  String _status = '正在加载工会数据 ...';
  String _sortKey = 'battle_power';  // battle_power / battles / win_rate / avg_damage

  // 筛选 + 船仓数据
  String? _filterClass;
  int? _filterTier;
  Map<int, List<ShipRecord>>? _memberShips;
  bool _shipsLoading = false;
  String _shipsStatus = '';
  late final ClanShipsLoader _shipsLoader = ClanShipsLoader(widget.region);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = ClanDataService(widget.region);
    try {
      final data = await svc.load(widget.clanId, (msg) {
        if (mounted) setState(() => _status = msg);
      });
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } finally {
      svc.close();
    }
  }

  void _openMember(ClanMember m) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => OverviewScreen(
        region: widget.region,
        accountId: m.accountId,
        nickname: m.nickname,
      ),
    ));
  }

  @override
  void dispose() {
    _shipsLoader.close();
    super.dispose();
  }

  Future<void> _ensureShipsLoaded() async {
    if (_memberShips != null || _shipsLoading || _data == null) return;
    setState(() {
      _shipsLoading = true;
      _shipsStatus = '准备拉取成员船仓 ...';
    });
    try {
      final ids = _data!.activeMembers.map((m) => m.accountId).toList();
      final ships = await _shipsLoader.loadAll(ids, onProgress: (loaded, total) {
        if (mounted) setState(() => _shipsStatus = '加载成员船仓 $loaded / $total ...');
      });
      if (mounted) setState(() {
        _memberShips = ships;
        _shipsLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _shipsLoading = false;
        _shipsStatus = '加载失败: $e';
      });
    }
  }

  Future<void> _setFilter({String? cls, int? tier}) async {
    setState(() {
      _filterClass = cls;
      _filterTier = tier;
    });
    if ((cls != null || tier != null) && _memberShips == null) {
      await _ensureShipsLoaded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('[${widget.tag}] ${widget.name}'),
      ),
      bottomNavigationBar: const SafeArea(
        child: Padding(padding: EdgeInsets.only(bottom: 6, top: 4), child: AppFooter()),
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: AppColors.red))))
              : _data == null
                  ? const Center(child: Text('未找到工会', style: TextStyle(color: AppColors.textDim)))
                  : _buildContent(_data!),
    );
  }

  Widget _buildLoading() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(color: AppColors.gold),
      const SizedBox(height: 16),
      Text(_status, style: const TextStyle(color: AppColors.textDim)),
    ]),
  );

  Widget _buildContent(ClanData clan) {
    final fmt = NumberFormat('#,###');
    final hasFilter = _filterClass != null || _filterTier != null;
    final scores = hasFilter && _memberShips != null
        ? computeClanRadarScoresFiltered(clan, _memberShips!, _filterClass, _filterTier)
        : computeClanRadarScores(clan);
    final overall = scores.isEmpty ? 0.0 :
        scores.values.fold<double>(0, (a, v) => a + v.$2) / scores.length;
    final fleetPower = hasFilter && _memberShips != null
        ? computeClanFleetPowerFromScores(scores)
        : computeClanFleetPower(clan);
    final fleetBP = computeBattlePower(fleetPower);

    // 筛选时: 给每个成员算筛选范围内的得分; 不筛选时为 null.
    // 排序: 筛选时按 score 降序 (无数据沉底), 否则按用户选择的 _sortKey.
    final filteredData = <int, ({int battles, double winRate, double score})?>{};
    if (hasFilter && _memberShips != null) {
      for (final m in clan.activeMembers) {
        filteredData[m.accountId] = computeMemberFilteredScore(
            _memberShips![m.accountId], _filterClass, _filterTier);
      }
    }
    final sorted = clan.activeMembers.toList()
      ..sort((a, b) {
        if (hasFilter && _memberShips != null) {
          final sa = filteredData[a.accountId]?.score ?? -1;
          final sb = filteredData[b.accountId]?.score ?? -1;
          return sb.compareTo(sa);
        }
        return switch (_sortKey) {
          'battles' => b.battles.compareTo(a.battles),
          'win_rate' => b.winRate.compareTo(a.winRate),
          'avg_damage' => b.avgDamage.compareTo(a.avgDamage),
          _ => b.avgDamage.compareTo(a.avgDamage),  // 默认按伤害
        };
      });

    // 隐藏成员: 显示在列表末尾, 用 隐藏🐴 标记
    final hiddenMembers = clan.members.where((m) => m.hidden).toList();
    final zeroBattleCount = clan.members
        .where((m) => !m.hidden && m.battles == 0)
        .length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 工会战力卡
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Color(PrColor.fromPr(fleetPower)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('FLEET POWER',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 6,
                    fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            Text(fmt.format(fleetBP),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.gold, fontSize: 50,
                    fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 2)),
          ]),
        ),
        const SizedBox(height: 12),
        // 工会基础信息
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (clan.motto != null && clan.motto!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('「${clan.motto}」',
                      style: const TextStyle(color: AppColors.textDim, fontStyle: FontStyle.italic)),
                ),
              Row(children: [
                _stat('成员', '${clan.members.length}'),
                const SizedBox(width: 12),
                _stat('活跃', '${clan.activeMembers.length}'),
                if (clan.members.length > clan.activeMembers.length) ...[
                  const SizedBox(width: 12),
                  _stat('隐藏', '${clan.members.length - clan.activeMembers.length}'),
                ],
                const SizedBox(width: 12),
                _stat('平均场次', fmt.format(clan.avgBattlesPerMember.round())),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // 雷达 + 维度/等级筛选
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              const Padding(padding: EdgeInsets.only(top: 4),
                  child: Text('🎯 工会战力雷达图',
                      style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold))),
              _buildClanFilterRow(clan),
              if (_shipsLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(children: [
                    const CircularProgressIndicator(color: AppColors.gold),
                    const SizedBox(height: 12),
                    Text(_shipsStatus, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                  ]),
                )
              else if (scores.isEmpty)
                const Padding(padding: EdgeInsets.all(40),
                  child: Text('筛选下无数据', style: TextStyle(color: AppColors.textDim)))
              else ...[
                RadarChart(scores: scores, overall: overall),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    hasFilter && _memberShips != null
                        ? '注: 筛选范围内成员等权重平均, 阈值按所选 舰种/等级 修正'
                        : '注: 工会雷达不做舰种 / 等级修正, 仅作横向粗对比',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textFaded, fontSize: 10),
                  ),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // 成员列表
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(children: [
            const Text('🧑‍🤝‍🧑 成员', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (hasFilter && _memberShips != null)
              const Text('按筛选范围综合分排序', style: TextStyle(color: AppColors.textDim, fontSize: 11))
            else ...[
              const Text('排序: ', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
              DropdownButton<String>(
                value: _sortKey,
                dropdownColor: AppColors.bgPanel,
                style: const TextStyle(color: AppColors.text, fontSize: 12),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'avg_damage', child: Text('伤害')),
                  DropdownMenuItem(value: 'win_rate', child: Text('胜率')),
                  DropdownMenuItem(value: 'battles', child: Text('场次')),
                ],
                onChanged: (v) => setState(() => _sortKey = v ?? 'avg_damage'),
              ),
            ],
          ]),
        ),
        for (final m in sorted)
          _MemberRow(
            member: m,
            fmt: fmt,
            filteredData: filteredData[m.accountId],
            hasFilter: hasFilter && _memberShips != null,
            onTap: () => _openMember(m),
          ),
        // 隐藏战绩成员: 用 隐藏🐴 标签显示
        for (final m in hiddenMembers)
          _MemberRow(
            member: m,
            fmt: fmt,
            filteredData: null,
            hasFilter: hasFilter && _memberShips != null,
            onTap: () => _openMember(m),
          ),
        if (zeroBattleCount > 0) Padding(
          padding: const EdgeInsets.all(12),
          child: Text('... 另有 $zeroBattleCount 个 0 场成员未展示',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textFaded, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
      Text(value, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildClanFilterRow(ClanData clan) {
    // 收集成员玩过的舰种 + 等级 — 但工会没有这数据;直接用所有可能选项
    const _classes = [
      ('总体', null),
      ('战列舰', 'Battleship'),
      ('巡洋舰', 'Cruiser'),
      ('驱逐舰', 'Destroyer'),
      ('航母', 'AirCarrier'),
      ('潜艇', 'Submarine'),
    ];
    final tiers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        const Text('维度', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
        const SizedBox(width: 6),
        Expanded(
          child: DropdownButton<String?>(
            value: _filterClass, isExpanded: true, isDense: true,
            dropdownColor: AppColors.bgPanel, underline: const SizedBox.shrink(),
            style: const TextStyle(color: AppColors.text, fontSize: 12),
            items: [for (final (label, val) in _classes)
              DropdownMenuItem(value: val, child: Text(label))],
            onChanged: (v) => _setFilter(cls: v, tier: _filterTier),
          ),
        ),
        const SizedBox(width: 12),
        const Text('等级', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
        const SizedBox(width: 6),
        SizedBox(width: 80,
          child: DropdownButton<int?>(
            value: _filterTier, isExpanded: true, isDense: true,
            dropdownColor: AppColors.bgPanel, underline: const SizedBox.shrink(),
            style: const TextStyle(color: AppColors.text, fontSize: 12),
            items: [
              const DropdownMenuItem(value: null, child: Text('全部')),
              for (final t in tiers) DropdownMenuItem(value: t, child: Text('T$t')),
            ],
            onChanged: (v) => _setFilter(cls: _filterClass, tier: v),
          ),
        ),
      ]),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final ClanMember member;
  final NumberFormat fmt;
  final ({int battles, double winRate, double score})? filteredData;
  final bool hasFilter;
  final VoidCallback onTap;
  const _MemberRow({
    required this.member,
    required this.fmt,
    required this.filteredData,
    required this.hasFilter,
    required this.onTap,
  });

  static const _roleZh = {
    'commander': '会长',
    'executive_officer': '副会长',
    'recruitment_officer': '招募官',
    'officer': '官员',
    'recruit': '成员',
    'private': '成员',
  };

  @override
  Widget build(BuildContext context) {
    final isHidden = member.hidden;
    // 隐藏成员: 数据列固定占位; 非隐藏按 筛选 / 总览 分情况.
    final int? showBattles;
    final double? showWinRate;
    if (isHidden) {
      showBattles = null;
      showWinRate = null;
    } else if (hasFilter && filteredData != null) {
      showBattles = filteredData!.battles;
      showWinRate = filteredData!.winRate;
    } else if (hasFilter) {
      showBattles = null;
      showWinRate = null;
    } else {
      showBattles = member.battles;
      showWinRate = member.winRate;
    }

    final card = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(member.nickname,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: isHidden ? AppColors.textDim : AppColors.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 13))),
              if (member.role == 'commander')
                const Padding(padding: EdgeInsets.only(left: 4),
                  child: Text('👑', style: TextStyle(fontSize: 12))),
            ]),
            Text('${_roleZh[member.role] ?? member.role}  ·  id=${member.accountId}',
                style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(showBattles != null ? '$showBattles场' : '—',
                style: TextStyle(
                    color: isHidden ? AppColors.textDim : AppColors.text,
                    fontSize: 11)),
            Text(
                isHidden
                    ? '战绩不可见'
                    : (showWinRate != null
                        ? '${(showWinRate * 100).toStringAsFixed(1)}%'
                        : '无对应战绩'),
                style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
          ]),
        ),
        Expanded(
          flex: 2,
          child: isHidden
              ? _buildHiddenTag()
              : (hasFilter
                  ? _buildScoreSide()
                  : Text(fmt.format(member.avgDamage.round()),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold))),
        ),
      ]),
    );

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: card,
      ),
    );
  }

  Widget _buildHiddenTag() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.gold.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold, width: 1),
        ),
        child: const Text('隐藏🐴',
            style: TextStyle(
                color: AppColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildScoreSide() {
    if (filteredData == null) {
      return const Text('—',
          textAlign: TextAlign.right,
          style: TextStyle(color: AppColors.textDim, fontSize: 13));
    }
    final g = gradeForScore(filteredData!.score);
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('${g.letter}  ${filteredData!.score.toStringAsFixed(0)}',
          style: TextStyle(color: g.color, fontSize: 14, fontWeight: FontWeight.bold)),
      const Text('综合分', style: TextStyle(color: AppColors.textDim, fontSize: 10)),
    ]);
  }
}
