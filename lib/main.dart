import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/app.dart';
import 'package:starlight/services/editor_service.dart';
import 'package:starlight/services/file_explorer_service.dart';
import 'package:starlight/services/keyboard_shortcut_service.dart';
import 'package:starlight/services/settings_service.dart';
import 'package:starlight/services/ui_service.dart';
import 'package:starlight/themes/theme_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initializeWindow() async {
  SettingsService settingsService = SettingsService();
  await settingsService.init();
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
  await initializeWindow();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => UIService()),
      ChangeNotifierProvider(create: (_) => SettingsService()),
      ChangeNotifierProxyProvider<SettingsService, ThemeProvider>(
        create: (context) => ThemeProvider(context.read<SettingsService>()),
        update: (context, settingsService, previous) =>
            previous ?? ThemeProvider(settingsService),
      ),
      Provider<FileExplorerService>(
        create: (_) => FileExplorerService(),
        lazy: true,
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
    ],
    child: const App(),
  ));
}
