import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';

/// ' · 📍 헬스장 이름' (헬스장이 둘 이상이거나 파트너 헬스장일 때만).
String placeLabel(BuildContext context, DayPlan p) {
  if (p.isRest) return '';
  if (p.atOtherGym) return ' · 📍 ${p.venueName}';
  final state = context.read<AppState>();
  if (state.gyms.length < 2) return '';
  final g = state.gymOf(p);
  return g == null ? '' : ' · 📍 ${g.name}';
}

/// 그 날 루틴 만들기: 헬스장이 둘 이상이면 먼저 어디서 할지 고른다.
Future<void> makeDayWithGym(BuildContext context, DateTime date) async {
  final state = context.read<AppState>();
  String? gymId;
  if (state.gyms.length > 1) {
    gymId = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('${date.month}/${date.day} 어디서 운동해요?'),
        children: [
          for (final g in state.gyms)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, g.id),
              child: Row(children: [
                Icon(g.id == state.activeGym?.id ? Icons.star : Icons.place_outlined, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('${g.name} · 기구 ${g.equipment.length}개')),
              ]),
            ),
        ],
      ),
    );
    if (gymId == null) return;
  }
  await state.regenerateDay(date, gymId: gymId);
}
