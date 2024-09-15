import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/command_palette/command_palette.dart';
import 'package:starlight/features/editor/presentation/editor_widget.dart';
import 'package:starlight/features/file_explorer/presentation/file_explorer_widget.dart';
import 'package:starlight/features/file_menu/presentation/file_menu_actions.dart';
import 'package:starlight/services/editor_service.dart';
import 'package:starlight/services/file_explorer_service.dart';
import 'package:starlight/services/keyboard_shortcut_service.dart';
import 'package:starlight/services/ui_service.dart';
import 'package:starlight/themes/theme_provider.dart';
import 'package:starlight/utils/widgets/resizable_widget.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  MainLayoutState createState() => MainLayoutState();
}

class MainLayoutState extends State<MainLayout> {
  late final FileExplorerService _fileExplorerService;
  late final EditorService _editorService;
  late final UIService _uiService;
  late final KeyboardShortcutService _keyboardShortcutService;
  bool _showCommandPalette = false;
  late final List<Command> _commands;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _keyboardShortcutService.focusNode,
      onKeyEvent: (_, event) => _keyboardShortcutService.handleKeyEvent(event),
      child: Consumer<UIService>(
        builder: (context, uiService, child) {
          return Scaffold(
            body: Stack(
              children: [
                Column(
                  children: [
                    uiService.buildAppBar(
                        context,
                        Provider.of<ThemeProvider>(context),
                        Theme.of(context).brightness == Brightness.dark),
                    Expanded(
                      child: Row(
                        children: [
                          if (uiService.showFileExplorer)
                            ResizableWidget(
                              maxWidthPercentage: 0.9,
                              child: RepaintBoundary(
                                child: FileExplorerWidget(
                                  onFileSelected: _editorService.handleOpenFile,
                                  onDirectorySelected: _fileExplorerService
                                      .handleDirectorySelected,
                                  controller: _fileExplorerService.controller,
                                ),
                              ),
                            ),
                          Expanded(
                            child: EditorWidget(
                              key: _editorService.editorKey,
                              fileMenuActions: FileMenuActions(
                                newFile: _editorService.handleNewFile,
                                openFile: _editorService.handleOpenFile,
                                save: _editorService.handleSaveCurrentFile,
                                saveAs: _editorService.handleSaveFileAs,
                                exit: (context) => SystemNavigator.pop(),
                              ),
                              rootDirectory:
                                  _fileExplorerService.selectedDirectory,
                              keyboardShortcutService: _keyboardShortcutService,
                            ),
                          ),
                        ],
                      ),
                    ),
                    uiService.buildStatusBar(context),
                  ],
                ),
                if (_showCommandPalette)
                  CommandPalette(
                    commands: _commands,
                    onCommandSelected: (command) {
                      command.action();
                      _toggleCommandPalette();
                    },
                    onClose: _toggleCommandPalette,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fileExplorerService = context.read<FileExplorerService>();
    _editorService = context.read<EditorService>();
    _uiService = context.read<UIService>();
    _keyboardShortcutService = context.read<KeyboardShortcutService>();
    _keyboardShortcutService.setToggleCommandPalette(_toggleCommandPalette);

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

  void _openFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      _editorService.handleOpenFile(file);
    }
  }

  void _toggleFileExplorer() {
    _uiService.toggleFileExplorer();
  }

  void _toggleCommandPalette() {
    setState(() {
      _showCommandPalette = !_showCommandPalette;
    });
  }
}
