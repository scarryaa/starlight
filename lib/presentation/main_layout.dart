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
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settingsService, child) {
        return Focus(
          focusNode: _mainFocusNode,
          autofocus: true,
          onKeyEvent: (FocusNode node, KeyEvent event) {
            return _keyboardShortcutService.handleKeyEvent(event);
          },
          child: GestureDetector(
            onTap: () {
              _mainFocusNode.requestFocus();
            },
            behavior: HitTestBehavior.translucent,
            child: Consumer<UIService>(
              builder: (context, uiService, child) {
                return DropTarget(
                  onDragDone: (detail) {
                    _handleFileDrop(detail.files);
                  },
                  onDragEntered: (detail) {
                    setState(() {
                      _dragging = true;
                    });
                  },
                  onDragExited: (detail) {
                    setState(() {
                      _dragging = false;
                    });
                  },
                  child: Scaffold(
                    body: Column(
                      children: [
                        uiService.buildAppBar(
                          context,
                          Provider.of<ThemeProvider>(context),
                          Theme.of(context).brightness == Brightness.dark,
                          settingsService.isFullscreen,
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              if (settingsService.showFileExplorer)
                                ResizableWidget(
                                  maxSizePercentage: 0.9,
                                  child: RepaintBoundary(
                                    child: FileExplorer(
                                      onFileSelected:
                                          _editorService.handleOpenFile,
                                      onDirectorySelected: _fileExplorerService
                                          .handleDirectorySelected,
                                      controller:
                                          _fileExplorerService.controller,
                                      onOpenInTerminal:
                                          _openInIntegratedTerminal,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: DragTarget<List<FileTreeItem>>(
                                        onAccept: (List<FileTreeItem> data) {
                                          for (var item in data) {
                                            if (!item.isDirectory) {
                                              _editorService.handleOpenFile(
                                                  item.entity as File);
                                            }
                                          }
                                        },
                                        builder: (context, candidateData,
                                            rejectedData) {
                                          return EditorWidget(
                                            key: _editorService.editorKey,
                                            onContentChanged:
                                                (String newContent) =>
                                                    _editorService
                                                        .handleContentChanged(
                                                            newContent),
                                            fileMenuActions: FileMenuActions(
                                              newFile:
                                                  _editorService.handleNewFile,
                                              openFile:
                                                  _editorService.handleOpenFile,
                                              save: _editorService
                                                  .handleSaveCurrentFile,
                                              saveAs: _editorService
                                                  .handleSaveFileAs,
                                              exit: (context) =>
                                                  SystemNavigator.pop(),
                                            ),
                                            rootDirectory: _fileExplorerService
                                                .selectedDirectory,
                                            keyboardShortcutService:
                                                _keyboardShortcutService,
                                          );
                                        },
                                      ),
                                    ),
                                    if (settingsService.showTerminal)
                                      ResizableWidget(
                                        isTopResizable: true,
                                        isHorizontal: false,
                                        maxSizePercentage: 0.5,
                                        child: IntegratedTerminal(
                                          initialDirectory: _terminalDirectory,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        uiService.buildStatusBar(context),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _handleFileDrop(List<XFile> files) {
    setState(() {
      _dragging = false;
    });
    for (var file in files) {
      _editorService.handleOpenFile(File(file.path));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsService = context.read<SettingsService>();
    _fileExplorerService = context.read<FileExplorerService>();
    _editorService = context.read<EditorService>();
    _keyboardShortcutService = context.read<KeyboardShortcutService>();
    _keyboardShortcutService.setToggleCommandPalette(_toggleCommandPalette);
    _keyboardShortcutService.setToggleFileExplorer(_toggleFileExplorer);
    _keyboardShortcutService.setToggleTerminal(_toggleTerminal);

    _initializeCommands();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mainFocusNode.requestFocus();
    });
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
