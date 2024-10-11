import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    hotkeyService = HotkeyService();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return Scaffold(
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
      body: isDesktop
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
