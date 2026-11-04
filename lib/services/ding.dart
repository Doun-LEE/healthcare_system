import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 휴식 끝 '띵' 소리. 듣고 있던 음악을 멈추지 않고 잠깐 줄였다가(덕킹) 울리고,
/// 알림 볼륨을 따르므로 무음·진동 모드에서는 울리지 않는다.
class Ding {
  Ding._();

  static AudioPlayer? _player;

  static Future<void> play() async {
    try {
      final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await p.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notificationEvent,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ));
      await p.stop();
      await p.play(AssetSource('sounds/ding.wav'), volume: 1.0);
    } catch (e) {
      // 소리는 부가 기능이라 실패해도 진동으로 충분하다.
      debugPrint('ding failed: $e');
    }
  }
}
