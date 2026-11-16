import 'package:flutter/material.dart';

/// 세그먼트 버튼 글자: 폭이 모자라면 줄을 바꾸지 않고 살짝 줄여서 한 줄로.
class SegLabel extends StatelessWidget {
  const SegLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, softWrap: false),
      );
}
