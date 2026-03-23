import 'package:flutter/foundation.dart'; // FORCE REBUILD 103
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:homegenie_app/core/theme/app_theme.dart';
import 'package:homegenie_app/features/root/root_page.dart';
import 'package:homegenie_app/features/dashboard/dashboard_controller.dart';

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
      home: RootPage(
        isDark: _isDark,
        onToggleTheme: () => setState(() => _isDark = !_isDark),
      ),
    );
  }
}
