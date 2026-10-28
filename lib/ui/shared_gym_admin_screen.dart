import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// 관리자: 같은 이름의 헬스장을 등록한 사람들을 모아 보고 대표 데이터를 지정한다.
class SharedGymAdminScreen extends StatefulWidget {
  const SharedGymAdminScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SharedGymAdminScreen()));

  @override
  State<SharedGymAdminScreen> createState() => _SharedGymAdminScreenState();
}

class _SharedGymAdminScreenState extends State<SharedGymAdminScreen> {
  late Future<List<SharedGymGroup>> _groups;

  @override
  void initState() {
    super.initState();
    _groups = context.read<AppState>().sharedGymGroups();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('헬스장 데이터 정리'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() => _groups = state.sharedGymGroups()))],
      ),
      body: FutureBuilder<List<SharedGymGroup>>(
        future: _groups,
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final groups = snap.data!;
          final dup = groups.where((g) => g.entries.length > 1).toList();
          final single = groups.where((g) => g.entries.length == 1).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text('나와 친구들의 헬스장을 이름으로 묶었어요. 같은 곳을 여러 명이 등록했으면 한 명의 데이터를 대표로 정하세요. '
                  '친구가 그 헬스장을 가져올 때 대표 표시(✔)가 뜨고, 겹칠 때 "교체"를 권해요.',
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              if (dup.isEmpty) Text('겹치는 헬스장이 없어요.', style: text.bodyMedium),
              for (final g in dup) _GroupCard(group: g, onPick: (e) async {
                await state.setCanonicalGym(g, e);
                if (mounted) setState(() {});
              }),
              if (single.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('한 명만 등록한 헬스장', style: text.labelLarge),
                for (final g in single)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(g.name),
                    subtitle: Text('${g.entries.first.ownerName} · 기구 ${g.entries.first.equipmentCount}개'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onPick});
  final SharedGymGroup group;
  final Future<void> Function(SharedGymEntry) onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final canonOwner = group.canonical?['owner'];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(group.name, style: text.titleMedium)),
            Text('${group.entries.length}명', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 6),
          for (final e in group.entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(canonOwner == e.uid ? Icons.verified : Icons.person_outline, color: canonOwner == e.uid ? cs.primary : cs.onSurfaceVariant),
              title: Text('${e.ownerName} · ${e.gymName}'),
              subtitle: Text('기구 ${e.equipmentCount}개${canonOwner == e.uid ? ' · 대표' : ''}'),
              trailing: canonOwner == e.uid
                  ? null
                  : TextButton(onPressed: () => onPick(e), child: const Text('대표로')),
            ),
        ]),
      ),
    );
  }
}
