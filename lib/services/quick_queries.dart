import 'cache.dart';

class QuickQuery {
  final String region;
  final int accountId;
  final String nickname;
  const QuickQuery({required this.region, required this.accountId, required this.nickname});

  Map<String, dynamic> toJson() => {
        'region': region,
        'account_id': accountId,
        'nickname': nickname,
      };

  factory QuickQuery.fromJson(Map<String, dynamic> j) => QuickQuery(
        region: j['region'].toString(),
        accountId: j['account_id'] as int,
        nickname: j['nickname'].toString(),
      );
}

class QuickQueriesService {
  static const _key = 'quick_queries_v1';

  Future<List<QuickQuery>> load() async {
    final raw = await Cache.instance.get<List>(_key, const Duration(days: 3650));
    if (raw == null) return [];
    return raw.map((e) => QuickQuery.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> save(List<QuickQuery> items) async {
    await Cache.instance.set(_key, items.map((q) => q.toJson()).toList());
  }

  Future<bool> add(QuickQuery q) async {
    final items = await load();
    if (items.any((x) => x.accountId == q.accountId)) return false;
    items.add(q);
    await save(items);
    return true;
  }

  Future<void> remove(int accountId) async {
    final items = await load();
    items.removeWhere((x) => x.accountId == accountId);
    await save(items);
  }
}
