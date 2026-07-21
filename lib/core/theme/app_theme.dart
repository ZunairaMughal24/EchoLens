import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_theme.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.voidBlack,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyanPulse,
        secondary: AppColors.violetGlow,
        surface: AppColors.nebulaSurface,
        error: AppColors.amberWarn,
      ),
      textTheme: AppTextTheme.materialTextTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
