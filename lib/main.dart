import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/app.dart';
import 'package:starlight/services/editor_service.dart';
import 'package:starlight/services/file_explorer_service.dart';
import 'package:starlight/services/keyboard_shortcut_service.dart';
import 'package:starlight/services/lsp_service.dart';
import 'package:starlight/services/settings_service.dart';
import 'package:starlight/services/ui_service.dart';
import 'package:starlight/themes/theme_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initializeWindow() async {
  SettingsService settingsService = await SettingsService().init();
  WindowOptions windowOptions = WindowOptions(
    size: Size(settingsService.windowWidth, settingsService.windowHeight),
    minimumSize: const Size(700, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    fullScreen: settingsService.isFullscreen,
  );
  await windowManager.ensureInitialized();
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsService = await SettingsService().init();
  await initializeWindow();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settingsService),
      ChangeNotifierProvider(create: (_) => UIService()),
      ChangeNotifierProxyProvider<SettingsService, ThemeProvider>(
        create: (context) => ThemeProvider(settingsService),
        update: (context, settingsService, previous) =>
            previous ?? ThemeProvider(settingsService),
      ),
      ChangeNotifierProxyProvider<SettingsService, FileExplorerService>(
        create: (context) => FileExplorerService(settingsService),
        update: (context, settingsService, previous) {
          if (previous == null) {
            return FileExplorerService(settingsService);
          }
          previous.updateSettings(settingsService);
          return previous;
        },
      ),
      Provider<EditorService>(
        create: (_) => EditorService(),
        lazy: true,
      ),
      Provider<KeyboardShortcutService>(
        create: (context) => KeyboardShortcutService(
          context.read<EditorService>(),
        ),
        lazy: true,
      ),
      ChangeNotifierProvider(create: (_) => LspService()),
    ],
    child: const App(),
  ));
}
