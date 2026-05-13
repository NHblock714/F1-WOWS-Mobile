import '../api/wg_api.dart';
import '../models/clan.dart';

class ClanDataService {
  final Region region;
  final WgApi _wg;

  ClanDataService(this.region) : _wg = WgApi(region);

  Future<ClanData?> load(int clanId, void Function(String)? onProgress) async {
    onProgress?.call('获取工会信息 ...');
    final info = await _wg.getClanInfo(clanId);
    if (info == null) return null;

    final tag = info['tag']?.toString() ?? '';
    final name = info['name']?.toString() ?? '';
    final motto = info['motto']?.toString();
    final colorStr = info['color']?.toString();
    int? color;
    if (colorStr != null && colorStr.startsWith('#') && colorStr.length == 7) {
      color = int.tryParse('FF${colorStr.substring(1)}', radix: 16);
    }

    final membersMap = info['members'] as Map<String, dynamic>?;
    if (membersMap == null || membersMap.isEmpty) {
      return ClanData(clanId: clanId, tag: tag, name: name, motto: motto, color: color, members: []);
    }

    // 成员 account_id 列表
    final memberMeta = <int, String>{};   // account_id -> role
    membersMap.forEach((aid, mInfo) {
      final id = int.tryParse(aid);
      if (id != null && mInfo is Map) {
        memberMeta[id] = mInfo['role']?.toString() ?? '';
      }
    });

    onProgress?.call('批量拉取 ${memberMeta.length} 个成员战绩 ...');
    final batch = await _wg.getPlayersInfoBatch(memberMeta.keys.toList());

    final members = <ClanMember>[];
    for (final entry in memberMeta.entries) {
      final aid = entry.key;
      final role = entry.value;
      final pinfo = batch['$aid'] as Map<String, dynamic>?;
      if (pinfo == null) {
        members.add(ClanMember(accountId: aid, nickname: 'id=$aid', role: role, hidden: true));
        continue;
      }
      final nickname = pinfo['nickname']?.toString() ?? 'id=$aid';
      final hidden = pinfo['hidden_profile'] == true || pinfo['statistics'] == null;
      if (hidden) {
        members.add(ClanMember(accountId: aid, nickname: nickname, role: role, hidden: true));
        continue;
      }
      final pvp = ((pinfo['statistics'] as Map?)?['pvp']) as Map?;
      final mb = (pvp?['main_battery'] as Map?) ?? const {};
      members.add(ClanMember(
        accountId: aid,
        nickname: nickname,
        role: role,
        battles: (pvp?['battles'] as num?)?.toInt() ?? 0,
        wins: (pvp?['wins'] as num?)?.toInt() ?? 0,
        damageDealt: (pvp?['damage_dealt'] as num?)?.toInt() ?? 0,
        xp: (pvp?['xp'] as num?)?.toInt() ?? 0,
        frags: (pvp?['frags'] as num?)?.toInt() ?? 0,
        survivedBattles: (pvp?['survived_battles'] as num?)?.toInt() ?? 0,
        mainBatteryHits: (mb['hits'] as num?)?.toInt() ?? 0,
        mainBatteryShots: (mb['shots'] as num?)?.toInt() ?? 0,
        artAgro: (pvp?['art_agro'] as num?)?.toInt() ?? 0,
        torpedoAgro: (pvp?['torpedo_agro'] as num?)?.toInt() ?? 0,
        damageScouting: (pvp?['damage_scouting'] as num?)?.toInt() ?? 0,
        planesKilled: (pvp?['planes_killed'] as num?)?.toInt() ?? 0,
        shipsSpotted: (pvp?['ships_spotted'] as num?)?.toInt() ?? 0,
      ));
    }

    return ClanData(
      clanId: clanId, tag: tag, name: name, motto: motto, color: color,
      members: members,
    );
  }

  void close() {
    _wg.close();
  }
}
