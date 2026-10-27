import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/store_io.dart' if (dart.library.js_interop) 'core/store_web.dart';
import 'firebase_options.dart';
import 'services/cloud_sync.dart';
import 'services/error_report.dart';
import 'state/app_state.dart';
import 'ui/app_theme.dart';
import 'ui/home_shell.dart';
import 'ui/login_screen.dart';
import 'ui/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await CloudSync.init(firebaseOptions);
  } catch (e) {
    CloudSync.initError = e.toString();
  }
  // 잡히지 않은 오류를 Firestore errors/ 에 남긴다(로그인한 사용자만, 세션당 최대 8건).
  if (CloudSync.isConfigured) await ErrorReport.install();
  final state = AppState(await createStore());
  await state.load();
  runApp(FitRoutineApp(state: state));
}

class FitRoutineApp extends StatelessWidget {
  const FitRoutineApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: Consumer<AppState>(
        builder: (_, s, _) {
          // 프로필에 저장된 앱 디자인(기본·귀여운·상남자)을 루트에서 ThemeData 로 만든다.
          final style = AppThemeStyle.parse(s.currentUser?.theme);
          return MaterialApp(
            title: 'FitRoutine',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(style, Brightness.light),
            darkTheme: buildAppTheme(style, Brightness.dark),
            themeMode: ThemeMode.system,
            home: !s.authed
                ? const LoginScreen()
                : (s.currentUser!.onboarded ? const HomeShell() : const OnboardingScreen()),
          );
        },
      ),
    );
  }
}
