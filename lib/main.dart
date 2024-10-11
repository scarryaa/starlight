import 'dart:io';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/editor/editor.dart';
import 'package:starlight/features/file_explorer/file_explorer.dart';
import 'package:starlight/features/status_bar/status_bar.dart';
import 'package:starlight/services/caret_position_notifier.dart';
import 'package:starlight/services/config_service.dart';
import 'package:starlight/services/file_service.dart';
import 'package:starlight/services/tab_service.dart';
import 'package:starlight/services/hotkey_service.dart';
import 'package:starlight/services/theme_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as path;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final caretPositionNotifier = CaretPositionNotifier();
  final fileService = FileService('');
  final tabService = TabService(
      fileService: fileService, caretPositionNotifier: caretPositionNotifier);
  final configService =
      ConfigService(fileService: fileService, tabService: tabService);

  if (!File(configService.configPath).existsSync()) {
    configService.createDefaultConfig();
  }
  configService.loadConfig();

  final initialDirectory = configService.config['initialDirectory'] ?? '';
  fileService.setCurrentDirectory(initialDirectory);

  final themeManager = ThemeManager(
    initialThemeMode: configService.config['theme'] ?? 'system',
  );

  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
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

      windowManager.waitUntilReadyToShow(windowOptions, () async {
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
  }

  runApp(MyApp(
    caretPositionNotifier: caretPositionNotifier,
    themeManager: themeManager,
    configService: configService,
    fileService: fileService,
    tabService: tabService,
  ));
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

class MyApp extends StatefulWidget {
  final ThemeManager themeManager;
  final ConfigService configService;
  final FileService fileService;
  final TabService tabService;
  final CaretPositionNotifier caretPositionNotifier;

  const MyApp({
    super.key,
    required this.themeManager,
    required this.configService,
    required this.fileService,
    required this.tabService,
    required this.caretPositionNotifier,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _saveWindowSizeAndPosition();
  }

  void _saveWindowSizeAndPosition() {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.getSize().then((size) {
        widget.configService.saveWindowSize(size);
      });
      windowManager.getPosition().then((position) {
        widget.configService.saveWindowPosition(position);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.themeManager),
        Provider.value(value: widget.configService),
        ChangeNotifierProvider.value(value: widget.fileService),
        ChangeNotifierProvider.value(value: widget.tabService),
        ChangeNotifierProvider.value(value: widget.caretPositionNotifier),
      ],
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, child) {
          return MaterialApp(
            title: 'starlight',
            debugShowCheckedModeBanner: false,
            theme: themeManager.lightTheme,
            darkTheme: themeManager.darkTheme,
            themeMode: themeManager.themeMode,
            home: Scaffold(
              body: Column(
                children: [
                  CustomTitleBar(
                    themeManager: themeManager,
                    configService: widget.configService,
                    fileService: widget.fileService,
                  ),
                  Expanded(
                    child: MyHomePage(
                      title: 'starlight',
                      configService: widget.configService,
                      fileService: widget.fileService,
                      tabService: widget.tabService,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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

class MyHomePage extends StatefulWidget {
  final String title;
  final ConfigService configService;
  final FileService fileService;
  final TabService tabService;

  const MyHomePage({
    super.key,
    required this.title,
    required this.configService,
    required this.fileService,
    required this.tabService,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late HotkeyService hotkeyService;
  bool _hotkeysRegistered = false;
  final FocusNode _rootFocusNode = FocusNode();
  final FocusNode _childFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    hotkeyService = HotkeyService();
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hotkeysRegistered) {
      _registerHotkeys();
      _hotkeysRegistered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: _rootFocusNode,
      autofocus: true,
      actions: {},
      child: Focus(
        focusNode: _childFocusNode,
        onKeyEvent: (node, event) {
          final result = hotkeyService.handleKeyEvent(event);
          return result == KeyEventResult.handled
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        },
        child: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    ValueListenableBuilder<bool>(
                      valueListenable:
                          widget.configService.fileExplorerVisibilityNotifier,
                      builder: (context, isVisible, child) {
                        return Visibility(
                          visible: isVisible,
                          child: FileExplorer(
                            fileService: widget.fileService,
                            initialDirectory: widget
                                    .configService.config['initialDirectory'] ??
                                '',
                            tabService: widget.tabService,
                          ),
                        );
                      },
                    ),
                    Editor(
                      configService: widget.configService,
                      hotkeyService: hotkeyService,
                      tabService: widget.tabService,
                      fileService: widget.fileService,
                      lineHeight:
                          widget.configService.config['lineHeight'] ?? 1.5,
                      fontFamily: widget.configService.config['fontFamily'] ??
                          'ZedMono Nerd Font',
                      fontSize:
                          widget.configService.config['fontSize'].toDouble() ??
                              16,
                      tabSize: widget.configService.config['tabSize'] ?? 4,
                    ),
                  ],
                ),
              ),
              StatusBar(
                tabService: widget.tabService,
                configService: widget.configService,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _registerHotkeys() {
    final bool isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
    hotkeyService.registerGlobalHotkey(
      SingleActivator(LogicalKeyboardKey.keyS,
          meta: isMacOS, control: !isMacOS),
      () {
        if (widget.tabService.currentTabIndexNotifier.value != null) {
          widget.tabService.updateTabContent(
              widget.tabService.currentTab!.path,
              widget
                  .tabService
                  .tabs[widget.tabService.currentTabIndexNotifier.value!]
                  .content,
              isModified: false);
          widget.fileService.writeFile(
              widget
                  .tabService
                  .tabs[widget.tabService.currentTabIndexNotifier.value!]
                  .fullPath,
              widget
                  .tabService
                  .tabs[widget.tabService.currentTabIndexNotifier.value!]
                  .content);
        } else {
          print("Could not save: currentTabIndexNotifier.value is null.");
        }
      },
    );
    hotkeyService.registerGlobalHotkey(
        SingleActivator(LogicalKeyboardKey.keyN,
            meta: isMacOS, control: !isMacOS),
        () {});
    hotkeyService.registerGlobalHotkey(
      SingleActivator(LogicalKeyboardKey.comma,
          meta: isMacOS, control: !isMacOS),
      () {
        widget.configService.openConfig();
      },
    );
  }
}
