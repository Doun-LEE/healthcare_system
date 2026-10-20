import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_update.dart';

/// 내 정보 화면의 "앱 정보" — 현재 버전, 새 버전 확인/다운로드.
class VersionSection extends StatefulWidget {
  const VersionSection({super.key});

  @override
  State<VersionSection> createState() => _VersionSectionState();
}

class _VersionSectionState extends State<VersionSection> {
  String _current = '…';
  String _currentOnly = '0.0.0';
  ReleaseInfo? _latest;
  bool _checking = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    AppUpdate.currentVersion().then((v) => mounted ? setState(() => _current = v) : null);
    AppUpdate.currentVersionOnly().then((v) => mounted ? setState(() => _currentOnly = v) : null);
    // 앱을 열 때 한 번 조용히 확인한다 (APK 에서만 의미 있음).
    if (!kIsWeb) _check(silent: true);
  }

  Future<void> _check({bool silent = false}) async {
    setState(() => _checking = true);
    final r = await AppUpdate.latest();
    if (!mounted) return;
    setState(() {
      _latest = r;
      _checking = false;
      _checked = true;
    });
    if (!silent && r == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('릴리스 정보를 가져오지 못했어요. 네트워크를 확인하세요.')));
    }
  }

  bool get _hasUpdate => _latest != null && AppUpdate.compare(_latest!.version, _currentOnly) > 0;

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('열 수 없어요: $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(_hasUpdate ? Icons.new_releases : Icons.info_outline, color: _hasUpdate ? cs.tertiary : cs.primary),
          title: Text('ldw_healthcare_system v$_current${kIsWeb ? ' · 웹(개발용)' : ''}'),
          subtitle: Text(
            _hasUpdate
                ? '새 버전 v${_latest!.version} 이 나왔어요'
                : _checked
                    ? (_latest == null ? '최신 버전 확인 실패' : '최신 버전입니다')
                    : '버전 확인 전',
            style: text.bodySmall?.copyWith(color: _hasUpdate ? cs.tertiary : cs.onSurfaceVariant),
          ),
          trailing: _checking
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(tooltip: '새 버전 확인', icon: const Icon(Icons.refresh), onPressed: () => _check()),
        ),
        if (_hasUpdate) ...[
          if (_latest!.notes.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(_latest!.notes.trim(), maxLines: 6, overflow: TextOverflow.ellipsis, style: text.bodySmall),
            ),
          FilledButton.icon(
            onPressed: () => _open(_latest!.apkUrl ?? _latest!.pageUrl),
            icon: const Icon(Icons.download),
            label: Text('v${_latest!.version} 다운로드 후 설치'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('다운로드가 끝나면 알림에서 파일을 열어 "설치"를 누르세요. 데이터는 그대로 유지됩니다.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
        ],
      ],
    );
  }
}
