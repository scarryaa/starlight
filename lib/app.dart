import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/presentation/main_layout.dart';
import 'package:starlight/services/settings_service.dart';
import 'package:starlight/themes/theme_provider.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late FileExplorerController _fileExplorerController;
  late SettingsService _settingsService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fileExplorerController = FileExplorerController();
    _settingsService = SettingsService();
    _initTempDirectory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearTempDirectory();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _clearTempDirectory();
    } else if (state == AppLifecycleState.resumed) {
      _initTempDirectory();
    }
  }

  Future<void> _initTempDirectory() async {
    await _fileExplorerController.initTempDirectory();
  }

  Future<void> _clearTempDirectory() async {
    await _fileExplorerController.clearTempDirectory();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _fileExplorerController),
        ChangeNotifierProvider.value(value: _settingsService),
        ChangeNotifierProxyProvider<SettingsService, ThemeProvider>(
          create: (context) => ThemeProvider(_settingsService),
          update: (context, settings, previous) =>
              previous ?? ThemeProvider(settings),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentThemeData,
            themeMode: themeProvider.themeMode,
            home: const MainLayout(),
          );
        },
      ),
    );
  }
}
