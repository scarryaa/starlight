import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/command_palette/command_palette.dart';
import 'package:starlight/features/editor/presentation/editor_widget.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _initializeCommands();
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

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settingsService, child) {
        return Focus(
          focusNode: _mainFocusNode,
          autofocus: true,
          onKeyEvent: (FocusNode node, KeyEvent event) {
            final result = _keyboardShortcutService.handleKeyEvent(event);
            // Assuming handleKeyEvent returns KeyEventResult
            return result;
          },
          child: GestureDetector(
            onTap: () => _mainFocusNode.requestFocus(),
            behavior: HitTestBehavior.translucent,
            child: _buildScaffold(context, settingsService),
          ),
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context, SettingsService settingsService) {
    return Consumer<UIService>(
      builder: (context, uiService, child) {
        var showCommandPalette = _showCommandPalette;
        return Stack(children: [
          DropTarget(
            onDragDone: (detail) => _handleFileDrop(detail.files),
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            child: Scaffold(
              body: Column(
                children: [
                  _buildAppBar(context, uiService, settingsService),
                  Expanded(child: _buildMainContent(settingsService)),
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

  Widget _buildMainContent(SettingsService settingsService) {
    return Row(
      children: [
        if (settingsService.showFileExplorer) _buildFileExplorer(),
        Expanded(
          child: Column(
            children: [
              Expanded(child: _buildEditor()),
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

  Widget _buildEditor() {
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
        description: 'Create a new file',
        icon: Icons.note_add,
        action: _editorService.handleNewFile,
      ),
      Command(
        name: 'Open File',
        description: 'Open an existing file',
        icon: Icons.folder_open,
        action: _openFile,
      ),
      Command(
        name: 'Save',
        description: 'Save the current file',
        icon: Icons.save,
        action: _editorService.handleSaveCurrentFile,
      ),
      Command(
        name: 'Save As',
        description: 'Save the current file with a new name',
        icon: Icons.save_as,
        action: _editorService.handleSaveFileAs,
      ),
      Command(
        name: 'Close File',
        description: 'Close the current file',
        icon: Icons.close,
        action: _editorService.closeCurrentFile,
      ),
      Command(
        name: 'Pick Directory',
        description: 'Choose a new root directory for the file explorer',
        icon: Icons.folder,
        action: _fileExplorerService.pickDirectory,
      ),
      Command(
        name: 'Toggle File Explorer',
        description: 'Show or hide the file explorer',
        icon: Icons.folder_open,
        action: _toggleFileExplorer,
      ),
      Command(
        name: 'Toggle Terminal',
        description: 'Show or hide the integrated terminal',
        icon: Icons.terminal,
        action: _toggleTerminal,
      ),
      Command(
        name: 'Open in Integrated Terminal',
        description: 'Open the current directory in the integrated terminal',
        icon: Icons.terminal,
        action: () => _openInIntegratedTerminal(
            _fileExplorerService.selectedDirectory.value ?? ''),
      ),
      Command(
        name: 'Search All Files',
        description: 'Search for a string in all files',
        icon: Icons.search,
        action: _editorService.addSearchAllFilesTab,
      ),
      Command(
        name: 'Find in File',
        description: 'Find text in the current file',
        icon: Icons.find_in_page,
        action: _editorService.showFindDialog,
      ),
      Command(
        name: 'Replace in File',
        description: 'Find and replace text in the current file',
        icon: Icons.find_replace,
        action: _editorService.showReplaceDialog,
      ),
      Command(
        name: 'Undo',
        description: 'Undo the last action',
        icon: Icons.undo,
        action: _editorService.undo,
      ),
      Command(
        name: 'Redo',
        description: 'Redo the last undone action',
        icon: Icons.redo,
        action: _editorService.redo,
      ),
      Command(
        name: 'Zoom In',
        description: 'Increase the font size',
        icon: Icons.zoom_in,
        action: _editorService.zoomIn,
      ),
      Command(
        name: 'Zoom Out',
        description: 'Decrease the font size',
        icon: Icons.zoom_out,
        action: _editorService.zoomOut,
      ),
      Command(
        name: 'Reset Zoom',
        description: 'Reset the font size to default',
        icon: Icons.zoom_out_map,
        action: _editorService.resetZoom,
      ),
      Command(
        name: 'Toggle Dark Mode',
        description: 'Switch between light and dark themes',
        icon: Icons.brightness_6,
        action: () =>
            Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
      ),
      Command(
        name: 'Light Theme',
        description: 'Switch to light theme',
        icon: Icons.light_mode,
        action: () => Provider.of<ThemeProvider>(context, listen: false)
            .setTheme('light'),
      ),
      Command(
        name: 'Dark Theme',
        description: 'Switch to dark theme',
        icon: Icons.dark_mode,
        action: () =>
            Provider.of<ThemeProvider>(context, listen: false).setTheme('dark'),
      ),
      Command(
        name: 'Retro Terminal Theme',
        description: 'Switch to retro terminal theme',
        icon: Icons.terminal,
        action: () => Provider.of<ThemeProvider>(context, listen: false)
            .setTheme('retro'),
      ),
      Command(
        name: 'Solarized Light Theme',
        description: 'Switch to solarized light theme',
        icon: Icons.wb_sunny,
        action: () => Provider.of<ThemeProvider>(context, listen: false)
            .setTheme('solarized'),
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
