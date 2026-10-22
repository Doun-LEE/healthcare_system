import 'package:flutter/material.dart';

/// 앱 공통 바텀시트. [showModalBottomSheet]와 같은 인자를 받되,
/// - 아이폰 홈 바·안드로이드 제스처 바 높이만큼 아래 여백을 항상 넣고
/// - 키보드가 올라오면 그만큼 시트를 밀어 올려 버튼이 가려지지 않게 한다.
/// 시트 안에서는 따로 viewInsets 패딩을 넣지 않아도 된다.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = true,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  bool isDismissible = true,
  bool enableDrag = true,
}) =>
    showModalBottomSheet<T>(
      context: context,
      showDragHandle: showDragHandle,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      builder: (c) {
        final mq = MediaQuery.of(c);
        final bottom = mq.viewPadding.bottom + mq.viewInsets.bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottom),
          child: MediaQuery.removeViewInsets(
            context: c,
            removeBottom: true,
            child: MediaQuery.removeViewPadding(context: c, removeBottom: true, child: builder(c)),
          ),
        );
      },
    );
