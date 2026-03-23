import 'package:flutter/material.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';

class AppCardTheme {
  static CardThemeData light(double radius) {
    return CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
    );
  }

  static CardThemeData dark(double radius) {
    return CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    );
  }
}
