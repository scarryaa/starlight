import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/file_explorer/file_Explorer_controller.dart';
import 'package:starlight/themes/theme_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(700, 600),
    minimumSize: Size(700, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => FileExplorerController()),
      ],
      child: const MyApp(),
    ),
  );
}
