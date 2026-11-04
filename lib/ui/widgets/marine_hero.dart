import 'package:flutter/material.dart';

/// 해병대 테마 캐릭터: 실사 사진(Unsplash License, Brian Lee)을 구릿빛 만화 채색으로 가공하고
/// 디지털 위장 팔각모·빨간 명찰·챙 그림자·붉은 눈빛을 합성한 이미지(assets/themes/marine_hero.png).
/// 배경은 투명하고 아래쪽은 녹아 있어 어떤 배경 위에도 얹을 수 있다.
class MarineHero extends StatelessWidget {
  const MarineHero({super.key, this.size = 100});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/themes/marine_hero.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
}
