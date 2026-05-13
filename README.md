# F1 WOWS — 战舰世界玩家战绩分析（移动端）

[![Flutter](https://img.shields.io/badge/Flutter-3.41-blue.svg)]() [![Platform](https://img.shields.io/badge/Platform-Android-green.svg)]() [![License](https://img.shields.io/badge/License-MIT-yellow.svg)]()

跨平台 Flutter app，对接 Wargaming 公共 API + wows-numbers.com，把玩家战绩做成带感的可视化：战力 PR、雷达图、战斗风格、终极挑战、本命战舰等。


## 主要功能

- **8 维战力雷达图**：胜率 / 伤害 / 经验 / 击杀 / 生存 / 命中 / 抗伤 / 侦查
- **强弱项条形图**：8 项分数横向对比
- **战斗风格自动推断**：抗线型 / 输出型 / 侦察型 / 中段怪 / ... 9 种 + 兜底
- **21 个终极挑战**：含黑五战舰收集、AL 联动、单场击杀峰值等
- **战舰榜**：等级 / 舰种 / 国家筛选，单舰六维雷达
- **6 种模式数据**：随机 / 联合 / 排位 / 公会 / 战役（单/组）
- **本命战舰**：算法 = `ship_pr × √battles`
- **快速查询**：常用玩家持久化
- **含马量值**：航母 / 潜艇 / 航站航巡航驱 加权
- **战力修正系数**：挑战 / 含马量 / 杂食 / 老兵 4 个奇怪 buff

## 安装

直接下载 [Release APK](../../releases) 装到 Android 设备（5.0+）即可。

> 首次启动需要拉取百科 + PR 数据，约 5–10 秒；之后秒开。

## 构建

### 1. 装 Flutter SDK + Android Studio

参考 https://docs.flutter.dev/get-started/install/windows

需要 Flutter 3.0+、Android SDK API 33+、AVD（如 Pixel 7 + API 34）。

### 2. 运行

```bash
flutter pub get
flutter run            # 模拟器或连接的实机
# 或打 release apk:
flutter build apk --release
```

## 关键算法

### Personal Rating
```
n_dmg   = max(0, (avg_damage / expected_damage - 0.4) / 0.6)
n_frags = max(0, (avg_frags  / expected_frags  - 0.1) / 0.9)
n_wr    = max(0, (win_rate   / expected_winrate - 0.7) / 0.3)
ship_pr = 700·n_dmg + 300·n_frags + 150·n_wr
```

### 总战力（sigmoid + 4 修正）
```
base    = 70000 / (1 + exp(-(pr - 1700) / 250))
final   = base × challenge × horse × variety × veteran
```

### 单船战力
```
ship_bp = (30000 / (1 + exp(-(ship_pr - 1700) / 300))) × min(1, sqrt(battles/100))
```

详细见 `lib/analysis/personal_rating.dart`。

## 贡献

- Issue / PR 都欢迎
- 改阈值改在 `lib/analysis/benchmarks.dart`
- 加新挑战在 `lib/analysis/challenges.dart`
- 加新风格在 `lib/analysis/battle_style.dart`

## License

MIT — see [LICENSE](LICENSE).

## 致谢

- [Wargaming Public API](https://developers.wargaming.net/) — 数据来源
- [wows-numbers.com](https://wows-numbers.com) — 全服 PR 期望值
- 群内各位热心群友帮助测试<img width="1284" height="2280" alt="qq" src="https://github.com/user-attachments/assets/fed34062-b417-4a42-baad-69fecdab4714" />

<!-- Latest: v1.0.4 -->

