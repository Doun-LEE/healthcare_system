import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_sheet.dart';

/// 세트 간 휴식 타이머. 하단 시트로 띄운다.
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

class _RestTimerSheetState extends State<RestTimerSheet> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = _remaining <= 0;
    final progress = (_remaining / widget.seconds).clamp(0.0, 1.0);
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
                  done ? 'GO' : '${_remaining ~/ 60}:${(_remaining % 60).toString().padLeft(2, '0')}',
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
                onPressed: () => setState(() => _remaining += 30),
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
