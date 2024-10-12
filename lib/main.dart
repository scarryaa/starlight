import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'package:starlight/widgets/tab/command_palette/command_palette.dart';

// Conditionally import desktop-specific packages
import 'desktop_config.dart' if (dart.library.html) 'desktop_config_stub.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final caretPositionNotifier = CaretPositionNotifier();
  final fileService = FileService('');
  final tabService = TabService(
      fileService: fileService, caretPositionNotifier: caretPositionNotifier);
  final configService =
      ConfigService(fileService: fileService, tabService: tabService);

  configService.loadConfig();

  final initialDirectory = configService.config['initialDirectory'] ?? '';
  fileService.setCurrentDirectory(initialDirectory);

  final themeManager = ThemeManager(
    initialThemeMode: configService.config['theme'] ?? 'system',
    configService: configService,
  );

  // Conditionally initialize desktop-specific configuration
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await initializeDesktopConfig(configService);
  }

  runApp(MyApp(
    caretPositionNotifier: caretPositionNotifier,
    themeManager: themeManager,
    configService: configService,
    fileService: fileService,
    tabService: tabService,
  ));
}

class MyApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeManager),
        Provider.value(value: configService),
        ChangeNotifierProvider.value(value: fileService),
        ChangeNotifierProvider.value(value: tabService),
        ChangeNotifierProvider.value(value: caretPositionNotifier),
      ],
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, child) {
          return MaterialApp(
            title: 'starlight',
            debugShowCheckedModeBanner: false,
            theme: themeManager.lightTheme,
            darkTheme: themeManager.darkTheme,
            themeMode: themeManager.themeMode,
            home: MyHomePage(
              title: 'starlight',
              configService: configService,
              fileService: fileService,
              tabService: tabService,
            ),
          );
        },
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
  final FocusNode _rootFocusNode = FocusNode();
  bool isCommandPaletteVisible = false;
  final FocusNode _mainLayoutFocusNode = FocusNode();
  late List<CommandItem> _commands;

  @override
  void initState() {
    super.initState();
    hotkeyService = HotkeyService();
    _mainLayoutFocusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerHotkeys();
    });
    _initializeCommands();
    _mainLayoutFocusNode.requestFocus();
  }

  void _toggleCommandPalette() {
    setState(() {
      isCommandPaletteVisible = !isCommandPaletteVisible;
      if (!isCommandPaletteVisible) {
        _mainLayoutFocusNode.requestFocus();
      }
    });
  }

  void _initializeCommands() {
    _commands = [
      CommandItem(
        icon: Icons.save,
        label: 'Save File',
        category: 'File',
      ),
      CommandItem(
        icon: Icons.add,
        label: 'New File',
        category: 'File',
      ),
      CommandItem(
        icon: Icons.folder_open,
        label: 'Open File',
        category: 'File',
      ),
      CommandItem(
        icon: Icons.settings,
        label: 'Open Settings',
        category: 'Editor',
      ),
      CommandItem(
        icon: Icons.folder,
        label: 'Toggle File Explorer',
        category: 'View',
      ),
      CommandItem(
        icon: Icons.color_lens,
        label: 'Toggle Dark Mode',
        category: 'View',
      ),
      CommandItem(
        icon: Icons.zoom_in,
        label: 'Increase Font Size',
        category: 'Editor',
      ),
      CommandItem(
        icon: Icons.zoom_out,
        label: 'Decrease Font Size',
        category: 'Editor',
      ),
      CommandItem(
        icon: Icons.undo,
        label: 'Undo',
        category: 'Edit',
      ),
      CommandItem(
        icon: Icons.redo,
        label: 'Redo',
        category: 'Edit',
      ),
    ];
  }

  void _handleCommandSelection(String command) {
    switch (command) {
      case 'Save File':
        _saveCurrentFile();
        break;
      case 'New File':
        _createNewFile();
        break;
      case 'Open File':
        _openFile();
        break;
      case 'Open Settings':
        _openSettings();
        break;
      case 'Toggle File Explorer':
        _toggleFileExplorer();
        break;
      case 'Toggle Dark Mode':
        _toggleDarkMode();
        break;
      case 'Increase Font Size':
        _increaseFontSize();
        break;
      case 'Decrease Font Size':
        _decreaseFontSize();
        break;
      case 'Undo':
        _undo();
        break;
      case 'Redo':
        _redo();
        break;
    }
    _toggleCommandPalette();
  }

  void _saveCurrentFile() {
    if (widget.tabService.currentTabIndexNotifier.value != null) {
      widget.tabService.updateTabContent(
        widget.tabService.currentTab!.path,
        widget.tabService.tabs[widget.tabService.currentTabIndexNotifier.value!]
            .content,
        isModified: false,
      );
      widget.fileService.writeFile(
        widget.tabService.tabs[widget.tabService.currentTabIndexNotifier.value!]
            .fullPath,
        widget.tabService.tabs[widget.tabService.currentTabIndexNotifier.value!]
            .content,
      );
    } else {
      print("Could not save: currentTabIndexNotifier.value is null.");
    }
  }

  void _openFile() {
    // Implement file opening logic
    print("Opening a file");
  }

  void _toggleDarkMode() {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    themeManager.toggleTheme();
  }

  void _increaseFontSize() {
    widget.configService.updateConfig(
        'fontSize', (widget.configService.config['fontSize'] ?? 16) + 1);
  }

  void _decreaseFontSize() {
    widget.configService.updateConfig(
        'fontSize', (widget.configService.config['fontSize'] ?? 16) - 1);
  }

  void _undo() {
    // Implement undo logic
    print("Undoing last action");
  }

  void _redo() {
    // Implement redo logic
    print("Redoing last undone action");
  }

  void _createNewFile() {
    // Implement new file creation logic
    print("Creating a new file");
  }

  void _openSettings() {
    widget.configService.openConfig();
  }

  void _toggleFileExplorer() {
    widget.configService.toggleFileExplorerVisibility();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return FocusableActionDetector(
      focusNode: _rootFocusNode,
      autofocus: true,
      actions: const {},
      child: Focus(
        focusNode: _mainLayoutFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          appBar: isDesktop ? null : AppBar(title: Text(widget.title)),
          drawer: isDesktop
              ? null
              : Drawer(
                  child: FileExplorer(
                    fileService: widget.fileService,
                    initialDirectory:
                        widget.configService.config['initialDirectory'] ?? '',
                    tabService: widget.tabService,
                  ),
                ),
          body: Stack(
            children: [
              isDesktop
                  ? DesktopLayout(
                      configService: widget.configService,
                      fileService: widget.fileService,
                      tabService: widget.tabService,
                      hotkeyService: hotkeyService,
                    )
                  : MobileLayout(
                      configService: widget.configService,
                      fileService: widget.fileService,
                      tabService: widget.tabService,
                      hotkeyService: hotkeyService,
                    ),
              if (isCommandPaletteVisible)
                GestureDetector(
                  onTap: _toggleCommandPalette,
                  child: Container(
                    color: Colors.black.withOpacity(0.25),
                    child: Focus(
                      canRequestFocus: isCommandPaletteVisible,
                      child: CommandPalette(
                        onCommandSelected: _handleCommandSelection,
                        onClose: _toggleCommandPalette,
                        commands: _commands,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final bool isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
      if (event.logicalKey == LogicalKeyboardKey.keyP &&
          (isMacOS
              ? HardwareKeyboard.instance.isMetaPressed
              : HardwareKeyboard.instance.isControlPressed)) {
        _toggleCommandPalette();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
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

    hotkeyService.registerGlobalHotkey(
      SingleActivator(LogicalKeyboardKey.keyP,
          meta: isMacOS, control: !isMacOS),
      _toggleCommandPalette,
    );
  }
}

class DesktopLayout extends StatelessWidget {
  final ConfigService configService;
  final FileService fileService;
  final TabService tabService;
  final HotkeyService hotkeyService;

  const DesktopLayout({
    super.key,
    required this.configService,
    required this.fileService,
    required this.tabService,
    required this.hotkeyService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomTitleBar(
          themeManager: Provider.of<ThemeManager>(context),
          configService: configService,
          fileService: fileService,
        ),
        Expanded(
          child: Row(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: configService.fileExplorerVisibilityNotifier,
                builder: (context, isVisible, child) {
                  return Visibility(
                    visible: isVisible,
                    child: FileExplorer(
                      fileService: fileService,
                      initialDirectory:
                          configService.config['initialDirectory'] ?? '',
                      tabService: tabService,
                    ),
                  );
                },
              ),
              Expanded(
                child: Editor(
                  configService: configService,
                  hotkeyService: hotkeyService,
                  tabService: tabService,
                  fileService: fileService,
                  lineHeight: configService.config['lineHeight'] ?? 1.5,
                  fontFamily:
                      configService.config['fontFamily'] ?? 'ZedMono Nerd Font',
                  fontSize: configService.config['fontSize'].toDouble() ?? 16,
                  tabSize: configService.config['tabSize'] ?? 4,
                ),
              ),
            ],
          ),
        ),
        StatusBar(
          tabService: tabService,
          configService: configService,
        ),
      ],
    );
  }
}

class MobileLayout extends StatelessWidget {
  final ConfigService configService;
  final FileService fileService;
  final TabService tabService;
  final HotkeyService hotkeyService;

  const MobileLayout({
    super.key,
    required this.configService,
    required this.fileService,
    required this.tabService,
    required this.hotkeyService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: tabService.tabs.isEmpty
              ? Center(
                  child: Text(
                    'No open files. Debug Info:\n'
                    'Config: ${configService.config}',
                    textAlign: TextAlign.center,
                  ),
                )
              : Editor(
                  configService: configService,
                  hotkeyService: hotkeyService,
                  tabService: tabService,
                  fileService: fileService,
                  lineHeight: configService.config['lineHeight'] ?? 1.5,
                  fontFamily:
                      configService.config['fontFamily'] ?? 'ZedMono Nerd Font',
                  fontSize: configService.config['fontSize'].toDouble() ?? 16,
                  tabSize: configService.config['tabSize'] ?? 4,
                ),
        ),
        StatusBar(
          tabService: tabService,
          configService: configService,
        ),
      ],
    );
  }
}
