import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/shell/presentation/pages/main_shell.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    debugPrint('[Flutter Error] ${details.exceptionAsString()}');
    debugPrint(details.stack.toString());
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Platform Error] $error\n$stack');
    return true;
  };
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e, st) {
    debugPrint('[Firebase Init Error] $e\n$st');
  }
  runApp(const ProviderScope(child: MyApp()));
}

// 타이틀/버튼/배지 등 임팩트가 필요한 곳은 굵은 디스플레이 폰트,
// 본문은 가독성 좋은 본문 폰트로 — 두 폰트를 섞어 게임다운 느낌을 낸다.
TextTheme _buildTextTheme(Brightness brightness) {
  final base = GoogleFonts.notoSansKrTextTheme(
    ThemeData(brightness: brightness).textTheme,
  );
  final display = GoogleFonts.blackHanSansTextTheme(base);
  return base.copyWith(
    displayLarge: display.displayLarge,
    displayMedium: display.displayMedium,
    displaySmall: display.displaySmall,
    headlineLarge: display.headlineLarge,
    headlineMedium: display.headlineMedium,
    headlineSmall: display.headlineSmall,
    titleLarge: display.titleLarge,
    labelLarge: display.labelLarge,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YGO Random Challenge',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          brightness: Brightness.light,
        ),
        textTheme: _buildTextTheme(Brightness.light),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          scrolledUnderElevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C6BC0),
          brightness: Brightness.dark,
        ),
        textTheme: _buildTextTheme(Brightness.dark),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          scrolledUnderElevation: 2,
        ),
      ),
      home: const MainShell(),
    );
  }
}
