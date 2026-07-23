import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/spatial_scan/presentation/screens/spatial_scan_screen.dart';

void main() {
  // SystemChrome calls touch a platform channel, which needs the binding
  // initialized first — runApp() normally does this implicitly, but these
  // calls run before runApp() here, so it has to be explicit.
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge, transparent system bars with light (for-dark-background)
  // icons — without this the OS falls back to its own default status bar
  // styling, which on a near-black app reads as an obvious unpolished seam
  // rather than the immersive look every mainstream dark-mode app has.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  runApp(const ProviderScope(child: EchoLensApp()));
}

class EchoLensApp extends StatelessWidget {
  const EchoLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Re-asserted via AnnotatedRegion (not just the one-time call in main())
    // so it survives route pushes/modal sheets, which can otherwise reset
    // system bar styling back to the platform default mid-session.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: MaterialApp(
        title: 'EchoLens',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const SpatialScanScreen(),
      ),
    );
  }
}
