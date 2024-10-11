import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:starlight/services/file_service.dart';
import 'package:starlight/services/theme_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:starlight/services/config_service.dart';
import 'package:path/path.dart' as path;

Future<void> initializeDesktopConfig(ConfigService configService) async {
  await windowManager.ensureInitialized();

  Size windowSize = configService.getWindowSize();
  Offset windowPosition = configService.getWindowPosition();

  // Ensure the window size is not smaller than the minimum size
  windowSize = Size(
    windowSize.width < 700 ? 700 : windowSize.width,
    windowSize.height < 600 ? 600 : windowSize.height,
  );

  WindowOptions windowOptions = WindowOptions(
    size: windowSize,
    minimumSize: const Size(700, 600),
    center: windowPosition == Offset.zero,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  if (Platform.isWindows) {
    doWhenWindowReady(() {
      appWindow.minSize = const Size(700, 600);
      appWindow.size = windowSize;
      appWindow.position = windowPosition;
      appWindow.show();
    });
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: [
        MinimizeWindowButton(
            colors: WindowButtonColors(iconNormal: theme.iconTheme.color)),
        MaximizeWindowButton(
            colors: WindowButtonColors(iconNormal: theme.iconTheme.color)),
        CloseWindowButton(
            colors: WindowButtonColors(iconNormal: theme.iconTheme.color)),
      ],
    );
  }
}

class CustomTitleBar extends StatelessWidget {
  final ThemeManager themeManager;
  final ConfigService configService;
  final FileService fileService;

  const CustomTitleBar({
    super.key,
    required this.themeManager,
    required this.configService,
    required this.fileService,
  });

  Future<void> _selectDirectory(BuildContext context) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      configService.updateConfig('initialDirectory', selectedDirectory);
      fileService.setCurrentDirectory(selectedDirectory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      color: themeManager.themeMode == ThemeMode.dark
          ? Colors.grey[900]
          : Colors.grey[300],
      child: WindowTitleBarBox(
        child: Row(
          children: [
            Expanded(
              child: MoveWindow(
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    const MacosWindowButtons(),
                    const SizedBox(width: 8),
                    SizedBox(
                      child: ValueListenableBuilder<String>(
                        valueListenable: fileService.currentDirectoryNotifier,
                        builder: (context, currentDirectory, child) {
                          return TextButton(
                            onPressed: () => _selectDirectory(context),
                            child: Text(
                              currentDirectory.isEmpty
                                  ? "Select a project"
                                  : path.basename(currentDirectory),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: themeManager.themeMode == ThemeMode.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MacosWindowButtons extends StatelessWidget {
  const MacosWindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _windowButton(Colors.red, 12),
        const SizedBox(width: 8),
        _windowButton(Colors.yellow, 12),
        const SizedBox(width: 8),
        _windowButton(Colors.green, 12),
      ],
    );
  }

  Widget _windowButton(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
