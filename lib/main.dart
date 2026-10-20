import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/store_io.dart' if (dart.library.js_interop) 'core/store_web.dart';
import 'state/app_state.dart';
import 'ui/home_shell.dart';
import 'ui/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      child: MaterialApp(
        title: 'FitRoutine',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: Consumer<AppState>(
          builder: (_, s, _) => s.authed ? const HomeShell() : const LoginScreen(),
        ),
      ),
    );
  }

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7CB342), brightness: b);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
