import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _fileExplorerService = context.read<FileExplorerService>();
    _editorService = context.read<EditorService>();
    _uiService = context.read<UIService>();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final keyboardShortcutService =
        Provider.of<KeyboardShortcutService>(context, listen: false);

    return Scaffold(
      body: Column(
        children: [
          _uiService.buildAppBar(context, themeProvider, isDarkMode),
          Expanded(
            child: Row(
              children: [
                ResizableWidget(
                  maxWidthPercentage: 0.9,
                  child: RepaintBoundary(
                    child: FileExplorerWidget(
                      onFileSelected: _editorService.handleOpenFile,
                      onDirectorySelected:
                          _fileExplorerService.handleDirectorySelected,
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
                    rootDirectory: _fileExplorerService.selectedDirectory,
                    keyboardShortcutService: keyboardShortcutService,
                  ),
                ),
              ],
            ),
          ),
          _uiService.buildStatusBar(context),
        ],
      ),
    );
  }
}
