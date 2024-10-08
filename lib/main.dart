import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/editor.dart';
import 'package:starlight/features/file_explorer/file_explorer.dart';
import 'package:starlight/services/config_service.dart';
import 'package:starlight/services/file_service.dart';
import 'package:starlight/services/tab_service.dart';
import 'package:starlight/services/hotkey_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'starlight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(title: 'starlight'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key, required this.title}) {
    tabService = TabService(fileService: fileService);
    hotkeyService = HotkeyService();
    configService =
        ConfigService(fileService: fileService, tabService: tabService);
    _createConfigFileIfNotExists();
  }

  final FileService fileService = FileService();
  late TabService tabService;
  late HotkeyService hotkeyService;
  late ConfigService configService;
  final String title;

  void _createConfigFileIfNotExists() {
    File configFile = File(configService.configPath);
    if (!configFile.existsSync()) {
      configFile.createSync(recursive: true);
      configFile.writeAsStringSync('{}');
    }
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
    widget.hotkeyService.registerHotkey(
      SingleActivator(LogicalKeyboardKey.keyS,
          meta: isMacOS, control: !isMacOS),
      () {
        if (widget.tabService.currentTabIndex != null) {
          widget.fileService.writeFile(
              widget.tabService.tabs[widget.tabService.currentTabIndex!].path,
              widget
                  .tabService.tabs[widget.tabService.currentTabIndex!].content);
        } else {
          print("Could not save: currentTabIndex is null.");
        }
      },
    );
    widget.hotkeyService.registerHotkey(
        SingleActivator(LogicalKeyboardKey.keyN,
            meta: isMacOS, control: !isMacOS),
        () {});
    widget.hotkeyService.registerHotkey(
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
          body: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              FileExplorer(
                initialDirectory: '',
                tabService: widget.tabService,
              ),
              Editor(
                tabService: widget.tabService,
                fileService: widget.fileService,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
