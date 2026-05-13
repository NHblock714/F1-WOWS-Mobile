import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../version.dart';

const _releaseUrl = 'https://github.com/NHblock714/F1-WOWS-Mobile/releases';

/// 底部品牌行 + 「检查更新」链接 (跳到 GitHub releases 页).
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  Future<void> _openReleases() async {
    final uri = Uri.parse(_releaseUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'F1 WOWS v$appVersion  ·  Powered by NHblock',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textFaded, fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 2),
        InkWell(
          onTap: _openReleases,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              '检查更新 →',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 11,
                letterSpacing: 0.5,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.gold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
