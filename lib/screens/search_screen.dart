import 'package:flutter/material.dart';
import '../api/wg_api.dart';
import '../services/cache.dart';
import '../services/quick_queries.dart';
import '../theme.dart';
import '../version.dart';
import '../widgets/constellation_background.dart';
import 'overview_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _nicknameController = TextEditingController();
  final _quickSvc = QuickQueriesService();
  Region _region = Region.asia;
  List<Map<String, dynamic>> _candidates = [];
  List<QuickQuery> _quickList = [];
  bool _loading = false;
  String? _error;
  String _cacheStatus = '';

  @override
  void initState() {
    super.initState();
    _refreshCacheStatus();
    _loadQuickList();
  }

  Future<void> _loadQuickList() async {
    final items = await _quickSvc.load();
    if (mounted) setState(() => _quickList = items);
  }

  Future<void> _refreshCacheStatus() async {
    final ages = await Cache.instance.ages();
    final parts = <String>[];
    for (final entry in [
      ('百科', RegExp(r'^encyclopedia_')),
      ('PR', RegExp(r'^wows_numbers')),
    ]) {
      Duration? best;
      for (final e in ages.entries) {
        if (entry.$2.hasMatch(e.key)) {
          if (best == null || e.value < best) best = e.value;
        }
      }
      if (best == null) {
        parts.add('${entry.$1} 未缓存');
      } else {
        final s = best.inSeconds;
        final txt = s < 3600 ? '${(s / 60).round()}分钟'
            : s < 86400 ? '${(s / 3600).round()}小时'
            : '${(s / 86400).round()}天';
        parts.add('${entry.$1} $txt前');
      }
    }
    if (mounted) setState(() => _cacheStatus = '数据: ${parts.join(" · ")}');
  }

  Future<void> _search() async {
    final nick = _nicknameController.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_]{3,25}$').hasMatch(nick)) {
      setState(() => _error = '昵称须为 3-25 位字母/数字/下划线');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _candidates = [];
    });
    try {
      final api = WgApi(_region);
      final results = await api.searchPlayers(nick);
      api.close();
      setState(() {
        _candidates = results;
        if (results.isEmpty) _error = '未找到匹配玩家';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _clearCache() async {
    await Cache.instance.clear();
    await _refreshCacheStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('缓存已清空, 下次查询将重新拉取')),
      );
    }
  }

  Future<void> _addQuick(Map<String, dynamic> c) async {
    final ok = await _quickSvc.add(QuickQuery(
      region: _region.name,
      accountId: c['account_id'] as int,
      nickname: c['nickname'].toString(),
    ));
    await _loadQuickList();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '已添加 ${c['nickname']} 到快速查询' : '该玩家已在快速查询中'),
      ));
    }
  }

  Future<void> _removeQuick(int accountId) async {
    await _quickSvc.remove(accountId);
    await _loadQuickList();
  }

  void _openPlayer(int accountId, String nickname, Region region) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => OverviewScreen(
        region: region,
        accountId: accountId,
        nickname: nickname,
      ),
    )).then((_) => _refreshCacheStatus());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '⚓ F1 WOWS',
          style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textDim),
            tooltip: '清空数据缓存',
            onPressed: _clearCache,
          ),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: 6, top: 4),
          child: Text(
            'F1 WOWS v$appVersion  ·  Powered by NHblock',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textFaded, fontSize: 11, letterSpacing: 1),
          ),
        ),
      ),
      body: ConstellationBackground(
        nodeCount: 30,
        connectDist: 130,
        color: AppColors.gold.withAlpha(120),
        pointAlpha: 90,
        lineAlpha: 50,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionLabel('① 服务器'),
              DropdownButtonFormField<Region>(
                initialValue: _region,
                dropdownColor: AppColors.bgPanel,
                items: Region.values.map((r) =>
                  DropdownMenuItem(value: r, child: Text(r.displayName))
                ).toList(),
                onChanged: (v) => setState(() {
                  if (v != null) _region = v;
                  _candidates = [];
                }),
              ),
              const SizedBox(height: 16),
              const _SectionLabel('② 玩家昵称'),
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(hintText: '3-25 位字母/数字/_'),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _search,
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('搜索'),
              ),
              if (_cacheStatus.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_cacheStatus,
                  style: const TextStyle(color: AppColors.textFaded, fontSize: 10),
                  textAlign: TextAlign.center),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.red)),
              ],
              if (_candidates.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionLabel('③ 选择玩家'),
                ..._candidates.map((c) => Card(
                  child: ListTile(
                    title: Text(c['nickname'] ?? ''),
                    subtitle: Text('id=${c['account_id']}',
                        style: const TextStyle(color: AppColors.textDim)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.star_border, color: AppColors.gold),
                        tooltip: '加入快速查询',
                        onPressed: () => _addQuick(c),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.gold),
                    ]),
                    onTap: () => _openPlayer(c['account_id'], c['nickname'], _region),
                  ),
                )),
              ],
              if (_quickList.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionLabel('⚡ 快速查询'),
                ..._quickList.map((q) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.link, color: AppColors.gold),
                    title: Text(q.nickname,
                      style: const TextStyle(color: AppColors.gold, fontSize: 14)),
                    subtitle: Text('${Region.values.firstWhere((r) => r.name == q.region, orElse: () => Region.asia).displayName}  ·  id=${q.accountId}',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textFaded, size: 18),
                      onPressed: () => _removeQuick(q.accountId),
                    ),
                    onTap: () {
                      final r = Region.values.firstWhere((x) => x.name == q.region, orElse: () => Region.asia);
                      _openPlayer(q.accountId, q.nickname, r);
                    },
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4, top: 4),
    child: Text(text, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
  );
}
