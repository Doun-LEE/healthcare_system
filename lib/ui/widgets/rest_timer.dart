import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_sheet.dart';

/// 세트 간 휴식 타이머. 하단 시트로 띄운다.
/// 남은 시간을 '끝나는 시각' 기준으로 계산해서, 다른 앱(카톡·인스타)에 다녀와도 그동안 흐른 시간이 반영된다.
class RestTimerSheet extends StatefulWidget {
  const RestTimerSheet({super.key, required this.seconds});
  final int seconds;

  static Future<void> show(BuildContext context, int seconds) =>
      showAppSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => RestTimerSheet(seconds: seconds),
      );

  @override
  State<RestTimerSheet> createState() => _RestTimerSheetState();
}

class _RestTimerSheetState extends State<RestTimerSheet> with WidgetsBindingObserver {
  late DateTime _endsAt;
  late int _total;
  Timer? _timer;
  bool _alerted = false;

  int get _remaining {
    final ms = _endsAt.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _total = widget.seconds;
    _endsAt = DateTime.now().add(Duration(seconds: widget.seconds));
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (_remaining <= 0 && !_alerted) {
      _alerted = true;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱으로 돌아오면 바로 남은 시간을 다시 그린다(백그라운드 동안 멈춘 타이머 보정).
    if (state == AppLifecycleState.resumed) _tick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remaining = _remaining;
    final done = remaining <= 0;
    final progress = (remaining / _total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(done ? '휴식 끝! 다음 세트' : '휴식 중',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    color: done ? cs.primary : cs.tertiary,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
                Text(
                  done ? 'GO' : '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => setState(() {
                  final base = done ? DateTime.now() : _endsAt;
                  _endsAt = base.add(const Duration(seconds: 30));
                  _total = (_total + 30).clamp(1, 3600);
                  _alerted = false;
                }),
                child: const Text('+30초'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(done ? '시작' : '건너뛰기'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
