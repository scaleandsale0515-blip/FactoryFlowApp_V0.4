import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'database/database_helper.dart';
import 'services/settings_service.dart';
import 'services/excel_service.dart';
import 'utils/app_theme.dart';
import 'utils/app_strings.dart';
import 'screens/admin/admin_lock_screen.dart';
import 'screens/shell/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  // Touch DB once to ensure tables exist before UI builds
  await DatabaseHelper.instance.database;
  await SettingsService.instance.init();
  runApp(const FactoryFlowApp());
}

class FactoryFlowApp extends StatefulWidget {
  const FactoryFlowApp({super.key});
  @override
  State<FactoryFlowApp> createState() => _FactoryFlowAppState();
}

class _FactoryFlowAppState extends State<FactoryFlowApp> {
  bool _isDark = true;
  bool _activated = false;
  bool _loading = true;

  @override
  void initState() { super.initState(); _bootstrap(); }

Future<void> _bootstrap() async {
  try {
    final theme = await SettingsService.instance.get('theme') ?? 'dark';
    final activated = await SettingsService.instance.isActivated();

    if (mounted) {
      setState(() {
        _isDark = theme != 'light';
        _activated = activated;
        _loading = false; // ✅ UI LOAD FIRST
      });
    }

    // ✅ Run heavy task AFTER UI loads
    if (activated) {
      _runBackgroundTasks();
    }
  } catch (e) {
    debugPrint("BOOTSTRAP ERROR: $e");

    if (mounted) {
      setState(() {
        _loading = false; // NEVER BLOCK UI
      });
    }
  }
}

  Future<void> _runBackgroundTasks() async {
  try {
    await ExcelService.instance
        .checkAndRotate()
        .timeout(const Duration(seconds: 10)); // ⛔ prevent freeze
  } catch (e) {
    debugPrint("Background task error: $e");
  }
}

void _onActivated() {
  setState(() => _activated = true);
  _runBackgroundTasks(); // ✅ safe call
}

  void _onThemeChanged(bool isDark) {
    setState(() => _isDark = isDark);
    SettingsService.instance.set('theme', isDark ? 'dark' : 'light');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FactoryFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: _loading
          ? const Scaffold(backgroundColor: AppColors.darkBg, body: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          : _activated
              ? AppShell(isDark: _isDark, onThemeChanged: _onThemeChanged)
              : AdminLockScreen(onActivated: _onActivated),
    );
  }
}
