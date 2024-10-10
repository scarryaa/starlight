import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/editor/editor.dart';
import 'package:starlight/features/file_explorer/file_explorer.dart';
import 'package:starlight/features/status_bar/status_bar.dart';
import 'package:starlight/services/config_service.dart';
import 'package:starlight/services/file_service.dart';
import 'package:starlight/services/tab_service.dart';
import 'package:starlight/services/hotkey_service.dart';
import 'package:starlight/services/theme_manager.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ThemeManager themeManager = ThemeManager();

  if (!kIsWeb) {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      await windowManager.ensureInitialized();

      WindowOptions windowOptions = const WindowOptions(
        minimumSize: Size(700, 600),
        size: Size(700, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }
  }

  runApp(MyApp(
    themeManager: themeManager,
  ));
}

class MyApp extends StatelessWidget {
  final ThemeManager themeManager;

  const MyApp({super.key, required this.themeManager});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: themeManager,
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, child) {
          return MaterialApp(
            title: 'starlight',
            debugShowCheckedModeBanner: false,
            theme: themeManager.lightTheme,
            darkTheme: themeManager.darkTheme,
            themeMode: themeManager.themeMode,
            home: MyHomePage(title: 'starlight'),
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key, required this.title}) {
    tabService = TabService(fileService: fileService);
    hotkeyService = HotkeyService();
    configService =
        ConfigService(fileService: fileService, tabService: tabService);
    themeManager = ThemeManager();
    _initializeConfig();
  }

  final FileService fileService = FileService();
  late TabService tabService;
  late HotkeyService hotkeyService;
  late ConfigService configService;
  late ThemeManager themeManager;
  final String title;

  void _initializeConfig() {
    if (!File(configService.configPath).existsSync()) {
      configService.createDefaultConfig();
    }
    configService.loadConfig();
    themeManager
        .setThemeMode(configService.config['themeMode'] ?? ThemeMode.system);
  }

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _hotkeysRegistered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hotkeysRegistered) {
      _registerHotkeys();
      _hotkeysRegistered = true;
    }
  }

  void _registerHotkeys() {
    final bool isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
    widget.hotkeyService.registerGlobalHotkey(
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
              widget.tabService
                  .tabs[widget.tabService.currentTabIndexNotifier.value!].path,
              widget
                  .tabService
                  .tabs[widget.tabService.currentTabIndexNotifier.value!]
                  .content);
        } else {
          print("Could not save: currentTabIndexNotifier.value is null.");
        }
      },
    );
    widget.hotkeyService.registerGlobalHotkey(
        SingleActivator(LogicalKeyboardKey.keyN,
            meta: isMacOS, control: !isMacOS),
        () {});
    widget.hotkeyService.registerGlobalHotkey(
      SingleActivator(LogicalKeyboardKey.comma,
          meta: isMacOS, control: !isMacOS),
      () {
        widget.configService.openConfig();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      actions: const <Type, Action<Intent>>{},
      shortcuts: const {},
      child: Focus(
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          final result = widget.hotkeyService.handleKeyEvent(event);
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
                    FileExplorer(
                      initialDirectory:
                          widget.configService.config['initialDirectory'] ?? '',
                      tabService: widget.tabService,
                    ),
                    Editor(
                      configService: widget.configService,
                      hotkeyService: widget.hotkeyService,
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
}
