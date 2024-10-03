import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/command_palette/command_palette.dart';
import 'package:starlight/features/editor/domain/models/lsp_config.dart';
import 'package:starlight/features/editor/presentation/editor_widget.dart';
import 'package:starlight/features/editor/services/lsp_path_resolver.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';
import 'package:starlight/features/file_explorer/presentation/file_explorer.dart';
import 'package:starlight/features/file_menu/presentation/file_menu_actions.dart';
import 'package:starlight/features/terminal/terminal.dart';
import 'package:starlight/services/editor_service.dart';
import 'package:starlight/services/file_explorer_service.dart';
import 'package:starlight/services/keyboard_shortcut_service.dart';
import 'package:starlight/services/settings_service.dart';
import 'package:starlight/services/ui_service.dart';
import 'package:starlight/themes/theme_provider.dart';
import 'package:starlight/utils/widgets/resizable_widget.dart';
import 'package:window_manager/window_manager.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  MainLayoutState createState() => MainLayoutState();
}

class MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  String? _terminalDirectory;
  final FocusNode _mainFocusNode = FocusNode();
  late final SettingsService _settingsService;
  late final FileExplorerService _fileExplorerService;
  late final EditorService _editorService;
  late final KeyboardShortcutService _keyboardShortcutService;
  bool _showCommandPalette = false;
  late final List<Command> _commands;
  bool _dragging = false;
  late Future<Map<String, LspConfig>> _lspConfigsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _initializeCommands();
    _lspConfigsFuture = _initializeLspConfigs();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _mainFocusNode.requestFocus());
  }

  void _initializeServices() {
    _settingsService = context.read<SettingsService>();
    _fileExplorerService = context.read<FileExplorerService>();
    _editorService = context.read<EditorService>();
    _keyboardShortcutService = context.read<KeyboardShortcutService>();
    _keyboardShortcutService
      ..setToggleCommandPalette(_toggleCommandPalette)
      ..setToggleFileExplorer(_toggleFileExplorer)
      ..setToggleTerminal(_toggleTerminal);
  }

  Future<Map<String, LspConfig>> _initializeLspConfigs() async {
    await LspPathResolver.initialize();

    return {
      'dart': LspConfig(
        command: LspPathResolver.resolveLspPath('dart') ?? 'dart',
        arguments: ['language-server', '--protocol=lsp'],
      ),
      'python': LspConfig(
        command: LspPathResolver.resolveLspPath('python') ?? 'pyls',
        arguments: [],
      ),
      'javascript': LspConfig(
        command: LspPathResolver.resolveLspPath('javascript') ??
            'typescript-language-server',
        arguments: ['--stdio'],
      ),
      'typescript': LspConfig(
        command: LspPathResolver.resolveLspPath('typescript') ??
            'typescript-language-server',
        arguments: ['--stdio'],
      ),
      'html': LspConfig(
        command: LspPathResolver.resolveLspPath('html') ??
            'vscode-html-language-server',
        arguments: ['--stdio'],
      ),
      'css': LspConfig(
        command: LspPathResolver.resolveLspPath('css') ??
            'vscode-css-language-server',
        arguments: ['--stdio'],
      ),
      'json': LspConfig(
        command: LspPathResolver.resolveLspPath('json') ??
            'vscode-json-language-server',
        arguments: ['--stdio'],
      ),
      'yaml': LspConfig(
        command:
            LspPathResolver.resolveLspPath('yaml') ?? 'yaml-language-server',
        arguments: ['--stdio'],
      ),
      'markdown': LspConfig(
        command: LspPathResolver.resolveLspPath('markdown') ??
            'remark-language-server',
        arguments: ['--stdio'],
      ),
      'plaintext': LspConfig(
        command: 'simple-language-server',
        arguments: ['--stdio'],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, LspConfig>>(
      future: _lspConfigsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          return _buildMainLayout(snapshot.data!);
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _buildMainLayout(Map<String, LspConfig> lspConfigs) {
    return Consumer<SettingsService>(
      builder: (context, settingsService, child) {
        return Focus(
          focusNode: _mainFocusNode,
          autofocus: true,
          onKeyEvent: (FocusNode node, KeyEvent event) {
            final result = _keyboardShortcutService.handleKeyEvent(event);
            return result;
          },
          child: GestureDetector(
            onTap: () => _mainFocusNode.requestFocus(),
            behavior: HitTestBehavior.translucent,
            child: _buildScaffold(context, settingsService, lspConfigs),
          ),
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context, SettingsService settingsService,
      Map<String, LspConfig> lspConfigs) {
    return Consumer<UIService>(
      builder: (context, uiService, child) {
        return Stack(children: [
          DropTarget(
            onDragDone: (detail) => _handleFileDrop(detail.files),
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            child: Scaffold(
              body: Column(
                children: [
                  _buildAppBar(context, uiService, settingsService),
                  Expanded(
                      child: _buildMainContent(settingsService, lspConfigs)),
                  uiService.buildStatusBar(context),
                ],
              ),
            ),
          ),
          if (_showCommandPalette)
            CommandPalette(
              commands: _commands,
              onClose: _toggleCommandPalette,
              onCommandSelected: (command) {
                command.action();
                _toggleCommandPalette();
              },
            ),
        ]);
      },
    );
  }

  Widget _buildAppBar(BuildContext context, UIService uiService,
      SettingsService settingsService) {
    return uiService.buildAppBar(
      context,
      Provider.of<ThemeProvider>(context),
      Theme.of(context).brightness == Brightness.dark,
      settingsService.isFullscreen,
    );
  }

  Widget _buildMainContent(
      SettingsService settingsService, Map<String, LspConfig> lspConfigs) {
    return Row(
      children: [
        if (settingsService.showFileExplorer) _buildFileExplorer(),
        Expanded(
          child: Column(
            children: [
              Expanded(child: _buildEditor(lspConfigs)),
              if (settingsService.showTerminal) _buildTerminal(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileExplorer() {
    return ResizableWidget(
      maxSizePercentage: 0.9,
      child: RepaintBoundary(
        child: FileExplorer(
          onFileSelected: _editorService.handleOpenFile,
          onDirectorySelected: _fileExplorerService.handleDirectorySelected,
          controller: _fileExplorerService.controller,
          onOpenInTerminal: _openInIntegratedTerminal,
        ),
      ),
    );
  }

  Widget _buildEditor(Map<String, LspConfig> lspConfigs) {
    return DragTarget<List<FileTreeItem>>(
      onAcceptWithDetails: (DragTargetDetails<List<FileTreeItem>> details) {
        _handleDraggedFiles(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return EditorWidget(
          key: _editorService.editorKey,
          onContentChanged: _editorService.handleContentChanged,
          fileMenuActions: _buildFileMenuActions(),
          rootDirectory: _fileExplorerService.selectedDirectory,
          keyboardShortcutService: _keyboardShortcutService,
          lspConfigs: lspConfigs,
        );
      },
    );
  }

  FileMenuActions _buildFileMenuActions() {
    return FileMenuActions(
      newFile: _editorService.handleNewFile,
      openFile: _editorService.handleOpenFile,
      save: _editorService.handleSaveCurrentFile,
      saveAs: _editorService.handleSaveFileAs,
      exit: (context) => SystemNavigator.pop(),
    );
  }

  Widget _buildTerminal() {
    return ResizableWidget(
      isTopResizable: true,
      isHorizontal: false,
      maxSizePercentage: 0.5,
      child: IntegratedTerminal(initialDirectory: _terminalDirectory),
    );
  }

  void _handleDraggedFiles(List<FileTreeItem> data) {
    for (var item in data) {
      if (!item.isDirectory) {
        _editorService.handleOpenFile(item.entity as File);
      }
    }
  }

  void _handleFileDrop(List<XFile> files) {
    setState(() {
      _dragging = false;
    });
    for (var file in files) {
      _editorService.handleOpenFile(File(file.path));
    }
  }

  void _openInIntegratedTerminal(String directory) {
    setState(() {
      _terminalDirectory = directory;
      if (!_settingsService.showTerminal) {
        _settingsService.setShowTerminal(true);
      }
    });
  }

  @override
  void dispose() {
    _mainFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _updateWindowSize();
  }

  void _updateWindowSize() async {
    final size = await windowManager.getSize();
    final isFullscreen = await windowManager.isFullScreen();
    _settingsService.setWindowSize(size);
    _settingsService.setFullscreen(isFullscreen);
  }

  void _initializeCommands() {
    _commands = [
      Command(
        name: 'New File',
        icon: Icons.note_add,
        action: _editorService.handleNewFile,
      ),
      Command(
        name: 'Open File',
        icon: Icons.folder_open,
        action: _openFile,
      ),
      Command(
        name: 'Save',
        icon: Icons.save,
        action: _editorService.handleSaveCurrentFile,
      ),
      Command(
        name: 'Save As',
        icon: Icons.save_as,
        action: _editorService.handleSaveFileAs,
      ),
      Command(
        name: 'Close File',
        icon: Icons.close,
        action: _editorService.closeCurrentFile,
      ),
      Command(
        name: 'Pick Directory',
        icon: Icons.folder,
        action: _fileExplorerService.pickDirectory,
      ),
      Command(
        name: 'Toggle File Explorer',
        icon: Icons.folder_open,
        action: _toggleFileExplorer,
      ),
      Command(
        name: 'Toggle Terminal',
        icon: Icons.terminal,
        action: _toggleTerminal,
      ),
      Command(
        name: 'Open in Integrated Terminal',
        icon: Icons.terminal,
        action: () => _openInIntegratedTerminal(
            _fileExplorerService.selectedDirectory.value ?? ''),
      ),
      Command(
        name: 'Search All Files',
        icon: Icons.search,
        action: _editorService.addSearchAllFilesTab,
      ),
      Command(
        name: 'Find in File',
        icon: Icons.find_in_page,
        action: _editorService.showFindDialog,
      ),
      Command(
        name: 'Replace in File',
        icon: Icons.find_replace,
        action: _editorService.showReplaceDialog,
      ),
      Command(
        name: 'Undo',
        icon: Icons.undo,
        action: _editorService.undo,
      ),
      Command(
        name: 'Redo',
        icon: Icons.redo,
        action: _editorService.redo,
      ),
      Command(
        name: 'Zoom In',
        icon: Icons.zoom_in,
        action: _editorService.zoomIn,
      ),
      Command(
        name: 'Zoom Out',
        icon: Icons.zoom_out,
        action: _editorService.zoomOut,
      ),
      Command(
        name: 'Reset Zoom',
        icon: Icons.zoom_out_map,
        action: _editorService.resetZoom,
      ),
      Command(
        name: 'Light Theme',
        icon: Icons.light_mode,
        action: () => Provider.of<ThemeProvider>(context, listen: false)
            .setTheme('light'),
      ),
      Command(
        name: 'Dark Theme',
        icon: Icons.dark_mode,
        action: () =>
            Provider.of<ThemeProvider>(context, listen: false).setTheme('dark'),
      ),
      Command(
        name: 'Retro Terminal Theme',
        icon: Icons.terminal,
        action: () => Provider.of<ThemeProvider>(context, listen: false)
            .setTheme('retro'),
      ),
      Command(
        name: 'Solarized Light Theme',
        icon: Icons.wb_sunny,
        action: () => Provider.of<ThemeProvider>(context, listen: false)
            .setTheme('solarized_light'),
      ),
      Command(
        name: 'Solarized Dark Theme',
        icon: Icons.wb_sunny,
        action: () => Provider.of<ThemeProvider>(context, listen: false)
            .setTheme('solarized_dark'),
      ),
    ];
  }

  void _toggleTerminal() {
    _settingsService.setShowTerminal(!_settingsService.showTerminal);
  }

  void _openFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      _editorService.handleOpenFile(file);
    }
  }

  void _toggleFileExplorer() {
    _settingsService.setShowFileExplorer(!_settingsService.showFileExplorer);
  }

  void _toggleCommandPalette() {
    setState(() {
      _showCommandPalette = !_showCommandPalette;
    });
  }
}
