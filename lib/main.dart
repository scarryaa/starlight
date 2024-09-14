import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/app.dart';
import 'package:starlight/services/editor_service.dart';
import 'package:starlight/services/file_explorer_service.dart';
import 'package:starlight/services/keyboard_shortcut_service.dart';
import 'package:starlight/services/ui_service.dart';
import 'package:starlight/themes/theme_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initializeWindow() async {
  WindowOptions windowOptions = const WindowOptions(
    size: Size(700, 600),
    minimumSize: Size(700, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.ensureInitialized();
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeWindow();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
      ),
      Provider<FileExplorerService>(
        create: (_) => FileExplorerService(),
        lazy: true,
      ),
      Provider<EditorService>(
        create: (_) => EditorService(),
        lazy: true,
      ),
      Provider<UIService>(
        create: (_) => UIService(),
        lazy: true,
      ),
      Provider<KeyboardShortcutService>(
        create: (context) =>
            KeyboardShortcutService(context.read<EditorService>()),
        lazy: true,
      ),
    ],
    child: const App(),
  ));
}
