import 'package:flutter/material.dart';

enum ScreenSize { mobile, web, desktop }

extension ScreenSizeX on ScreenSize {
  bool get isMobile => this == ScreenSize.mobile;
  bool get isTablet => this == ScreenSize.web;
  bool get isWeb => this == ScreenSize.web;
  bool get isDesktop => this == ScreenSize.desktop;
}

class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;

  static ScreenSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobile) return ScreenSize.mobile;
    if (width < tablet) return ScreenSize.web; // Tablet/Web
    return ScreenSize.desktop;
  }
}

/// Responsive builder: delegates to the correct layout widget
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, ScreenSize) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final size = Breakpoints.of(context);
    return builder(context, size);
  }
}
