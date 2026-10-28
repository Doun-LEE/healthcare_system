import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../engine/load_estimator.dart';
import '../engine/splits.dart';
import '../engine/session_generator.dart';
import '../models/models.dart';
import 'widgets/level_card.dart';
import '../state/app_state.dart';
import 'app_theme.dart';
import 'widgets/account_sheet.dart';
import 'widgets/injury_chips.dart';
import 'widgets/marine_mascot.dart';
import 'widgets/mascot.dart';
import 'widgets/backup_section.dart';
import 'friends_screen.dart';
import 'shared_gym_admin_screen.dart';
import 'widgets/version_section.dart';

/// 신체 스펙·인바디 스캔·분할/시간 설정·API 키·접근 코드·로그아웃.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final u = state.currentUser!;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final est = LoadEstimator(u);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.myHandle == null ? u.name : '${u.name}  ·  ${state.myHandle}'),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: state.logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 통계
          Row(children: [
            _Stat(label: '완료 세션', value: '${state.completedSessions}'),
            _Stat(label: '연속 주', value: '${state.currentStreakWeeks}주'),
            _Stat(label: '숙련도', value: u.level.label),
          ]),
          const SizedBox(height: 16),

          // 신체 스펙
          _Section(title: '신체 스펙', children: [
            SegmentedButton<Sex>(
              segments: Sex.values.map((s) => ButtonSegment(value: s, label: Text(s.label))).toList(),
              selected: {u.sex},
              onSelectionChanged: (s) => _edit(state, (p) => p.sex = s.first),
            ),
            const SizedBox(height: 8),
            _NumField(label: '키 (cm)', value: u.heightCm, onChanged: (v) => _edit(state, (p) => p.heightCm = v)),
            _NumField(label: '체중 (kg)', value: u.weightKg, onChanged: (v) => _edit(state, (p) => p.weightKg = v)),
            _NumField(label: '나이', value: u.age.toDouble(), integer: true, onChanged: (v) => _edit(state, (p) => p.age = v.round())),
            _NumField(label: '골격근량 (kg, 인바디)', value: u.skeletalMuscleKg, onChanged: (v) => _edit(state, (p) => p.skeletalMuscleKg = v)),
            _NumField(label: '체지방률 (%, 인바디)', value: u.bodyFatPct, onChanged: (v) => _edit(state, (p) => p.bodyFatPct = v)),
            const SizedBox(height: 14),
            Text('3대 기록 (kg, 1RM 또는 최고 중량 · 선택)', style: text.labelLarge),
            Text('입력하면 추정 대신 이 값으로 무게를 계산하고, 레벨 판정에도 쓰입니다. 비우면 신체 스펙으로 추정.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: _NumField(label: '스쿼트', value: u.squat1rm, onChanged: (v) => _edit(state, (p) => p.squat1rm = v > 0 ? v : null))),
              const SizedBox(width: 8),
              Expanded(child: _NumField(label: '벤치', value: u.bench1rm, onChanged: (v) => _edit(state, (p) => p.bench1rm = v > 0 ? v : null))),
            ]),
            Row(children: [
              Expanded(child: _NumField(label: '데드리프트', value: u.deadlift1rm, onChanged: (v) => _edit(state, (p) => p.deadlift1rm = v > 0 ? v : null))),
              const SizedBox(width: 8),
              Expanded(child: _NumField(label: 'OHP', value: u.ohp1rm, onChanged: (v) => _edit(state, (p) => p.ohp1rm = v > 0 ? v : null))),
            ]),
            if (u.squat1rm != null || u.bench1rm != null || u.deadlift1rm != null)
              Text('3대 합계: ${((u.squat1rm ?? 0) + (u.bench1rm ?? 0) + (u.deadlift1rm ?? 0)).round()}kg',
                  style: text.bodyMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Text('레벨 판정', style: text.labelLarge),
            Text('키·체중·나이·성별·골격근·체지방·3대 기록으로 리프트별·체성분별 등급을 매기고 종합 레벨을 정합니다.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            LevelCard(profile: u),
            SwitchListTile(
              value: u.levelAuto,
              contentPadding: EdgeInsets.zero,
              title: const Text('숙련도 자동 판정'),
              subtitle: Text(u.levelAuto ? '판정 결과에 따라 루틴 강도(세트·횟수·무게)를 적용합니다.' : '아래에서 직접 고른 숙련도를 씁니다.'),
              onChanged: (v) => _edit(state, (p) => p.levelAuto = v),
            ),
            if (!u.levelAuto)
              SegmentedButton<TrainingLevel>(
                segments: TrainingLevel.values.map((l) => ButtonSegment(value: l, label: Text(l.label))).toList(),
                selected: {u.level},
                onSelectionChanged: (s) => _edit(state, (p) => p.level = s.first),
              ),
            const SizedBox(height: 14),
            Text('운동 목표', style: text.labelLarge),
            SegmentedButton<TrainingGoal>(
              segments: TrainingGoal.values.map((g) => ButtonSegment(value: g, label: Text(g.label))).toList(),
              selected: {u.goal},
              onSelectionChanged: (s) => _edit(state, (p) => p.goal = s.first),
            ),
            Text(u.goal.description, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            Text('부상 · 주의 부위', style: text.labelLarge),
            const SizedBox(height: 4),
            InjuryChips(
              injuries: u.injuries,
              cautions: u.cautions,
              onChanged: (inj, cau) => _edit(state, (p) {
                p.injuries
                  ..clear()
                  ..addAll(inj);
                p.cautions
                  ..clear()
                  ..addAll(cau);
              }),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('무게 계산 기준 1RM', style: text.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    '스쿼트 ${est.oneRepMax(RefLift.squat).round()}kg${u.squat1rm != null ? '(실제)' : ''} · 벤치 ${est.oneRepMax(RefLift.bench).round()}kg${u.bench1rm != null ? '(실제)' : ''} · 데드 ${est.oneRepMax(RefLift.deadlift).round()}kg${u.deadlift1rm != null ? '(실제)' : ''} · OHP ${est.oneRepMax(RefLift.ohp).round()}kg${u.ohp1rm != null ? '(실제)' : ''}',
                    style: text.bodyMedium,
                  ),
                  Text('근육 보정 ×${est.muscleFactor.toStringAsFixed(2)} · 체지방 보정 ×${est.fatFactor.toStringAsFixed(2)}. 실제 수행 결과로 매 세션 자동 보정됩니다.',
                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await state.recalibrateFuture();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('미래 계획의 무게를 다시 추정했어요.')));
                }
              },
              icon: const Icon(Icons.tune),
              label: const Text('스펙 변경을 미래 루틴에 반영'),
            ),
          ]),

          // 루틴 설정
          _Section(title: '루틴 설정', children: [
            Text('분할', style: text.labelLarge),
            const SizedBox(height: 4),
            RadioGroup<int>(
              groupValue: u.splitDays,
              onChanged: (v) => _edit(state, (p) => p.splitDays = v ?? p.splitDays),
              child: Column(
                children: [
                  for (final t in splitTemplates)
                    RadioListTile<int>(
                      value: t.days,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.name),
                      subtitle: Text(t.description),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('하루 운동 시간: ${u.sessionMinutes}분${u.volumeBias != 1.0 ? ' · 볼륨 보정 ${(u.volumeBias * 100).round()}%' : ''}', style: text.labelLarge),
            if (u.volumeBias != 1.0)
              Row(children: [
                Expanded(
                  child: Text(
                    '운동 완료 때 계획보다 ${u.volumeBias > 1 ? '더' : '덜'} 수행해서 루틴 볼륨을 ${u.volumeBias > 1 ? '늘려' : '줄여'} 짭니다.',
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                TextButton(onPressed: () => _edit(state, (p) => p.volumeBias = 1.0), child: const Text('초기화')),
              ]),
            Slider(
              value: u.sessionMinutes.toDouble(),
              min: 30,
              max: 150,
              divisions: 12,
              label: '${u.sessionMinutes}분',
              onChanged: (v) => _edit(state, (p) => p.sessionMinutes = v.round()),
            ),
            SwitchListTile(
              value: u.includeCardio,
              contentPadding: EdgeInsets.zero,
              title: const Text('유산소 포함'),
              subtitle: const Text('세션 끝에 10~20분 추가(감량 목표면 30분까지)'),
              onChanged: (v) => _edit(state, (p) => p.includeCardio = v),
            ),
            if (u.includeCardio)
              SwitchListTile(
                value: u.cardioOnLegDays,
                contentPadding: const EdgeInsets.only(left: 16),
                dense: true,
                title: const Text('하체 날에도 유산소'),
                subtitle: const Text('끄면 하체 날은 회복을 위해 유산소를 뺍니다'),
                onChanged: (v) => _edit(state, (p) => p.cardioOnLegDays = v),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('하루 시작 시각', style: text.labelLarge),
                  Text('이 시각 전에 하는 운동은 전날 운동으로 봐요. 밤샘·야간 근무면 늦게 잡으세요. 시작한 운동은 끝낼 때까지 그 날 운동으로 남아요.',
                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: u.dayStartHour.clamp(0, 12),
                items: [
                  for (var h = 0; h <= 12; h++)
                    DropdownMenuItem(value: h, child: Text(h == 0 ? '자정' : (h < 12 ? '새벽·오전 $h시' : '정오'))),
                ],
                onChanged: (v) => _edit(state, (p) => p.dayStartHour = v ?? p.dayStartHour),
              ),
            ]),
            const SizedBox(height: 12),
            Text('갑자기 쉬게 되면', style: text.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'shift', label: Text('루틴 뒤로 밀기')),
                ButtonSegment(value: 'keep', label: Text('루틴 그대로')),
              ],
              selected: {u.restMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _edit(state, (p) => p.restMode = s.first),
            ),
            Text(
              u.restMode == 'keep'
                  ? '쉬거나 못 간 날은 그 날만 "휴식"으로 표시하고, 날짜별로 정해진 루틴(예: 금요일 하체)은 그대로 둡니다.'
                  : '쉬거나 못 간 날의 부위가 빠지지 않게, 이후 루틴을 하루씩 뒤로 밀어 다시 맞춥니다.',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: u.autoAdjust,
              contentPadding: EdgeInsets.zero,
              title: const Text('데이터 기반 자동 첨삭'),
              subtitle: const Text('쉬거나 못 간 날 때문에 이후 루틴을 다시 짤 때, 근육별 회복 상태(덜 회복된 근육은 세트 -1·무게 90%·운동 교체)와 최근 4주 부족한 근육을 반영해요. 계획대로 한 날은 건드리지 않아요.'),
              onChanged: (v) => _edit(state, (p) => p.autoAdjust = v),
            ),
            const SizedBox(height: 12),
            Text('운동 전 워밍업·스트레칭', style: text.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'auto', label: Text('자동')),
                ButtonSegment(value: 'custom', label: Text('직접 정하기')),
                ButtonSegment(value: 'off', label: Text('안 함')),
              ],
              selected: {u.warmupMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _edit(state, (p) => p.warmupMode = s.first),
            ),
            Text(
              switch (u.warmupMode) {
                'custom' => '아래에서 고른 운동을 매번 웨이트 전에 넣어요(가볍게 2세트).',
                'off' => '워밍업 없이 바로 본 운동부터.',
                _ => '동적 스트레칭 5분 + 그 날 부위에 맞는 활성화 운동(예: 등 날엔 암풀다운·덤벨 풀오버·풀업)을 가볍게 2세트.',
              },
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (u.warmupMode == 'custom')
              for (final key in ['all', 'back', 'chest', 'shoulder', 'arms', 'legs', 'abs'])
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 52,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(key == 'all' ? '매번' : MuscleGroup.parse(key).label, style: text.labelMedium),
                      ),
                    ),
                    Expanded(
                      child: Wrap(spacing: 6, runSpacing: 4, children: [
                        for (final id in (key == 'all' ? u.warmupIds : (u.warmupByGroupIds[key] ?? const <String>[])))
                          if (exerciseById(id) != null)
                            InputChip(
                              label: Text(exerciseById(id)!.name),
                              onDeleted: () => _edit(state, (p) => key == 'all' ? p.warmupIds.remove(id) : p.warmupByGroupIds[key]?.remove(id)),
                              visualDensity: VisualDensity.compact,
                            ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: Text(key == 'all' ? '매번 할 것' : '이 부위 날'),
                          onPressed: () => _pickWarmups(context, state, key),
                          visualDensity: VisualDensity.compact,
                        ),
                      ]),
                    ),
                  ]),
                ),
            const SizedBox(height: 12),
            Text('운동 구역 순서', style: text.labelLarge),
            Text('손잡이를 끌어 하루 루틴에서 어떤 구역을 먼저 할지 정합니다.', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (o, n) => _edit(state, (p) {
                final list = List.of(p.sectionOrder);
                final item = list.removeAt(o);
                list.insert(n, item);
                p.sectionOrder = list;
              }),
              children: [
                for (var i = 0; i < u.sectionOrder.length; i++)
                  ListTile(
                    key: ValueKey(u.sectionOrder[i]),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                    title: Text(SessionGenerator.sectionLabel(u.sectionOrder[i])),
                    trailing: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '웨이트 구역 안은 처음엔 복합운동(고중량) → 고립운동 순서로 짜고, 루틴에서 직접 순서를 바꾸면 그 순서를 기억해 다음 루틴에도 반영합니다.'
              '${u.exerciseRank.isNotEmpty ? ' 현재 ${u.exerciseRank.length}개 운동의 순서를 학습했어요.' : ''}',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (u.exerciseRank.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => state.resetOrderLearning(), child: const Text('학습한 순서 초기화')),
              ),
          ]),

          // 앱 디자인
          _Section(title: '앱 디자인', children: [
            Text('고르면 바로 바뀌고, 이 계정으로 로그인한 다른 기기에도 똑같이 적용돼요. 색·모양과 함께 인사말·완료 문구·오늘의 한마디 말투도 바뀌어요. 라이트/다크는 기기 설정을 따라요.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (c, box) {
              final w = (box.maxWidth - 8) / 2;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in AppThemeStyle.values)
                  SizedBox(
                    width: w,
                    child: _ThemeCard(
                      style: s,
                      selected: AppThemeStyle.parse(u.theme) == s,
                      onTap: () => _edit(state, (p) => p.theme = s.id),
                    ),
                  ),
              ]);
            }),
          ]),

          // 계정
          const _Section(title: '계정 · 동기화', children: [AccountSection()]),
          if (state.isAdmin)
            _Section(title: '관리자 · 헬스장 데이터 정리', children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('겹치는 헬스장 정리'),
                subtitle: const Text('친구들이 같은 이름으로 등록한 헬스장을 모아 대표 데이터를 정해요. 가져오기할 때 대표가 표시돼요.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => SharedGymAdminScreen.open(context),
              ),
            ]),
          const SizedBox(height: 12),
          const _Section(title: '기록 저장 · 불러오기', children: [BackupSection()]),

          // 친구(파트너)는 홈 상단 친구 목록으로 옮겼다.
          _Section(title: '친구 · 운동 파트너', children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.people_outline),
              title: const Text('친구 목록 · 채팅'),
              subtitle: Text(state.myHandle == null ? '로그인하면 ID로 친구를 추가할 수 있어요' : '내 ID ${state.myHandle} · 홈 상단에서도 바로 열려요'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => FriendsScreen.open(context),
            ),
          ]),

          // 앱 정보 / 업데이트
          const _Section(title: '앱 정보', children: [VersionSection()]),

          // 보안/연동
          _Section(title: '보안 · 연동', children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock),
              title: const Text('접근 코드 변경'),
              subtitle: const Text('로그인 시 입력하는 숫자 코드'),
              onTap: () async {
                final v = await _promptText(context, '새 접근 코드 (4자 이상)', '', obscure: true);
                if (v != null && v.trim().length >= 4) await state.setAccessCode(v);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_forever, color: cs.error),
              title: Text('이 프로필 삭제', style: TextStyle(color: cs.error)),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('프로필을 삭제할까요?'),
                    content: const Text('계획과 기록이 모두 삭제되며 복구할 수 없습니다.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제')),
                    ],
                  ),
                );
                if (ok == true) await state.deleteProfile(u.id);
              },
            ),
          ]),
        ],
      ),
    );
  }

  void _edit(AppState state, void Function(UserProfile) f) => state.updateProfile(f);

  Future<void> _pickWarmups(BuildContext context, AppState state, String key) async {
    final u = state.currentUser!;
    final chosen = {...(key == 'all' ? u.warmupIds : (u.warmupByGroupIds[key] ?? const <String>[]))};
    var query = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: Text(key == 'all' ? '매번 하는 워밍업' : '${MuscleGroup.parse(key).label} 날 워밍업'),
          content: SizedBox(
            width: double.maxFinite,
            height: 460,
            child: Column(children: [
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '예: 풀오버, 어덕션, 스트레칭', isDense: true),
                onChanged: (v) => setState(() => query = v.trim()),
              ),
              Expanded(
                child: ListView(children: [
                  for (final e in [
                    ...warmupChoices,
                    ...exerciseCatalog.where((x) => !warmupChoices.contains(x) && (key == 'all' || x.group.name == key)),
                  ].where((x) => exerciseMatches(x, query)))
                    CheckboxListTile(
                      dense: true,
                      value: chosen.contains(e.id),
                      title: Text(e.name),
                      subtitle: Text('${e.warmupOnly ? '워밍업 · ' : ''}${e.group.label} · ${e.emphasis.take(2).join(' · ')}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      onChanged: (v) => setState(() => v == true ? chosen.add(e.id) : chosen.remove(e.id)),
                    ),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('저장')),
          ],
        ),
      ),
    );
    if (ok == true) {
      _edit(state, (p) {
        final list = chosen.toList();
        if (key == 'all') {
          p.warmupIds
            ..clear()
            ..addAll(list);
        } else {
          p.warmupByGroupIds[key] = list;
        }
      });
    }
  }
}

Future<String?> _promptText(BuildContext context, String title, String hint, {bool obscure = false}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, obscureText: obscure, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('저장')),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        color: cs.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            Text(value, style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

/// 앱 디자인 고르기 카드: 그 테마의 색·모서리로 자기 모습을 미리 보여준다.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.style, required this.selected, required this.onTap});
  final AppThemeStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final preview = buildAppTheme(style, brightness);
    final pcs = preview.colorScheme;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(style.radius);
    return Semantics(
      button: true,
      selected: selected,
      label: '앱 디자인 ${style.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          decoration: BoxDecoration(
            color: pcs.surfaceContainerLow,
            borderRadius: radius,
            border: Border.all(color: selected ? cs.primary : pcs.outlineVariant, width: selected ? 2.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 미리보기: 그 테마 색의 버튼·칩 모양.
              Row(children: [
                Container(
                  width: 34,
                  height: 22,
                  decoration: BoxDecoration(color: pcs.primary, borderRadius: BorderRadius.circular(style.radius / 2)),
                  alignment: Alignment.center,
                  child: Text(
                    '12',
                    style: preview.textTheme.labelLarge?.copyWith(color: pcs.onPrimary, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                if (style == AppThemeStyle.cute)
                  const Mascot(size: 30, bob: false)
                else if (style == AppThemeStyle.marine)
                  const MarineEmblem(size: 28)
                else
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: pcs.secondaryContainer, borderRadius: BorderRadius.circular(style.radius / 2)),
                  ),
                const Spacer(),
                if (selected) Icon(Icons.check_circle, size: 18, color: cs.primary) else Icon(style.icon, size: 18, color: pcs.onSurfaceVariant),
              ]),
              const SizedBox(height: 10),
              Text(style.label, style: preview.textTheme.titleSmall?.copyWith(color: pcs.onSurface)),
              const SizedBox(height: 2),
              Text(style.description, style: text.bodySmall?.copyWith(color: pcs.onSurfaceVariant, fontSize: 11), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}

/// 포커스를 잃을 때 저장하는 숫자 입력.
class _NumField extends StatefulWidget {
  const _NumField({required this.label, required this.value, required this.onChanged, this.integer = false});
  final String label;
  final double? value;
  final bool integer;
  final void Function(double) onChanged;

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _c;
  final _focus = FocusNode();

  String _fmt(double? v) => v == null ? '' : (widget.integer ? v.round().toString() : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1)));

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: _fmt(widget.value));
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _NumField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) _c.text = _fmt(widget.value);
  }

  void _commit() {
    final v = double.tryParse(_c.text);
    if (v != null && v != widget.value) widget.onChanged(v);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: _c,
          focusNode: _focus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: widget.label, isDense: true),
          onSubmitted: (_) => _commit(),
        ),
      );
}
