import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'features/spatial_scan/presentation/screens/spatial_scan_screen.dart';

void main() {
  // google_fonts fetches weights from Google's CDN on first use and throws
  // if the device has no network. Disabling runtime fetching makes it fall
  // back to the closest system font instead of crashing when offline; a
  // fully offline-proof release should bundle the .ttf files as assets
  // instead (see AppTextTheme doc comment).
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ProviderScope(child: EchoLensApp()));
}

class EchoLensApp extends StatelessWidget {
  const EchoLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EchoLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SpatialScanScreen(),
    );
  }
}
