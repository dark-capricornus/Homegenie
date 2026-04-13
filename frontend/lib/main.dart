import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/core/theme/app_colors.dart';
import 'package:homegenie_app/core/theme/app_theme.dart';
import 'package:homegenie_app/features/root/root_page.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';
import 'package:homegenie_app/features/onboarding/onboarding_view.dart';
import 'package:homegenie_app/features/auth/views/auth_view.dart';

final appLog = Logger('HomeGenieApp');

void main() {
  Logger.root.level = Level.ALL; 
  Logger.root.onRecord.listen((record) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('${record.level.name}: ${record.time}: ${record.message}');
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DashboardController()..initialize(),
        ),
      ],
      child: const HomeGenieApp(),
    ),
  );
}

class HomeGenieApp extends StatefulWidget {
  const HomeGenieApp({super.key});

  @override
  State<HomeGenieApp> createState() => _HomeGenieAppState();
}

class _HomeGenieAppState extends State<HomeGenieApp> {
  bool _isDark = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeGenie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: Selector<DashboardController, (bool, bool, bool)>(
        selector: (context, controller) => (
          controller.isLoading,
          controller.hasModeSet,
          controller.isLoggedIn,
        ),
        builder: (context, data, child) {
          final isLoading = data.$1;
          final hasModeSet = data.$2;
          final isLoggedIn = data.$3;

          appLog.info('ROOT_BUILD: isLoading=$isLoading, hasModeSet=$hasModeSet, isLoggedIn=$isLoggedIn');

          if (isLoading && !hasModeSet) {
            return Scaffold(
              backgroundColor: _isDark ? AppColors.darkBackground : AppColors.lightBackground,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text('Starting HomeGenie...',
                        style: TextStyle(
                          color: _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
            );
          }

          if (!hasModeSet) {
            return OnboardingPage(
              isDark: _isDark,
              onToggleTheme: () => setState(() => _isDark = !_isDark),
            );
          }
          
          if (!isLoggedIn) {
            return const AuthView();
          }

          return RootPage(
            isDark: _isDark,
            onToggleTheme: () => setState(() => _isDark = !_isDark),
          );
        },
      ),
    );
  }
}
