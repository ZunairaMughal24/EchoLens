import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/spatial_scan/presentation/screens/spatial_scan_screen.dart';

void main() {
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
