import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide TabBar, Tab;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/editor/editor.dart';
import 'package:starlight/features/file_explorer/file_Explorer_controller.dart';
import 'package:starlight/features/file_explorer/file_explorer.dart';
import 'package:starlight/features/file_menu/file_menu_actions.dart';
import 'package:starlight/features/file_menu/menu_actions.dart';
import 'package:starlight/features/sidebar_switcher/sidebar_switcher.dart';
import 'package:starlight/features/tabs/tab.dart';
import 'package:starlight/themes/theme_provider.dart';
import 'package:starlight/utils/widgets/resizable_widget.dart';
import 'package:window_manager/window_manager.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final FileExplorerController _fileExplorerController;
  late final FileMenuActions _fileMenuActions;
  final ValueNotifier<String?> _selectedDirectory =
      ValueNotifier<String?>(null);
  final GlobalKey<_EditorWidgetState> _editorKey =
      GlobalKey<_EditorWidgetState>();

  @override
  void initState() {
    super.initState();
    _fileExplorerController = FileExplorerController();
    _fileMenuActions = FileMenuActions(
      newFile: _handleNewFile,
      openFile: _handleOpenFile,
      save: _handleSaveCurrentFile,
      saveAs: _handleSaveFileAs,
      exit: _handleExit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
        body: Column(children: [
      _buildAppBar(context, themeProvider, isDarkMode),
      _buildDesktopMenu(context),
      Expanded(
          child: Row(children: [
        ResizableWidget(
          maxWidthPercentage: 0.9,
          child: RepaintBoundary(
            child: SidebarSwitcher(
              onFileSelected: _handleOpenFile,
              onDirectorySelected: _handleDirectorySelected,
              fileExplorerController: _fileExplorerController,
            ),
          ),
        ),
        Expanded(
            child: EditorWidget(
          key: _editorKey,
          fileMenuActions: _fileMenuActions,
        )),
      ])),
      _buildStatusBar()
    ]));
  }

  Widget _buildAppBar(
      BuildContext context, ThemeProvider themeProvider, bool isDarkMode) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 70),
              const SizedBox(width: 8),
              ValueListenableBuilder<String?>(
                valueListenable: _selectedDirectory,
                builder: (context, directory, _) {
                  return directory != null
                      ? TextButton(
                          onPressed: _pickDirectory,
                          child: Text(
                            directory.split('/').last,
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                },
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: Theme.of(context).appBarTheme.iconTheme?.color,
                  size: 14,
                ),
                onPressed: () => themeProvider.toggleTheme(),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMenu(BuildContext context) {
    if (Platform.isMacOS) return Container();

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color:
            Theme.of(context).menuTheme.style?.backgroundColor?.resolve({}) ??
                Theme.of(context).canvasColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildMenuBarButton(context, 'File', [
            _buildMenuItem(
                'New File', Icons.add, () => _fileMenuActions.newFile()),
            _buildMenuItem('Open File', Icons.folder_open,
                () => _fileMenuActions.openFileDialog()),
            _buildMenuItem('Save', Icons.save, () => _fileMenuActions.save()),
            _buildMenuItem(
                'Save As...', Icons.save_as, () => _fileMenuActions.saveAs()),
            const PopupMenuDivider(),
            _buildMenuItem('Exit', Icons.exit_to_app,
                () => _fileMenuActions.exit(context)),
          ]),
          _buildMenuBarButton(context, 'Edit', [
            _buildMenuItem('Undo', Icons.undo, () => MenuActions.undo(context)),
            _buildMenuItem('Redo', Icons.redo, () => MenuActions.redo(context)),
            const PopupMenuDivider(),
            _buildMenuItem(
                'Cut', Icons.content_cut, () => MenuActions.cut(context)),
            _buildMenuItem(
                'Copy', Icons.content_copy, () => MenuActions.copy(context)),
            _buildMenuItem(
                'Paste', Icons.content_paste, () => MenuActions.paste(context)),
          ]),
          _buildMenuBarButton(context, 'Help', [
            _buildMenuItem('About Starlight', Icons.info_outline,
                () => MenuActions.about(context)),
          ]),
        ],
      ),
    );
  }

  Widget _buildMenuBarButton(BuildContext context, String title,
      List<PopupMenuEntry<Function>> items) {
    return PopupMenuButton<Function>(
      position: PopupMenuPosition.under,
      tooltip: "",
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(title, style: const TextStyle(fontSize: 13)),
      ),
      itemBuilder: (BuildContext context) => items,
      onSelected: (Function action) => action(),
    );
  }

  PopupMenuItem<Function> _buildMenuItem(
      String title, IconData icon, Function action) {
    return PopupMenuItem<Function>(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
    );
  }

  void _handleDirectorySelected(String? directory) {
    _selectedDirectory.value = directory;
    if (directory != null) {
      _fileExplorerController.setDirectory(Directory(directory));
    }
  }

  void _handleNewFile() {
    _editorKey.currentState?.addEmptyTab();
  }

  void _handleOpenFile(File file) {
    _editorKey.currentState?.openFile(file);
  }

  void _handleSaveCurrentFile() {
    _editorKey.currentState?.saveCurrentFile();
  }

  void _handleSaveFileAs() {
    _editorKey.currentState?.saveFileAs();
  }

  void _handleExit(BuildContext context) {
    SystemNavigator.pop();
  }

  Future<void> _pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      _handleDirectorySelected(selectedDirectory);
    }
  }
}

class FileExplorerWidget extends StatelessWidget {
  final FileExplorerController controller;
  final Function(File) onFileSelected;
  final Function(String?) onDirectorySelected;

  const FileExplorerWidget({
    super.key,
    required this.controller,
    required this.onFileSelected,
    required this.onDirectorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: FileExplorer(
        controller: controller,
        onFileSelected: onFileSelected,
        onDirectorySelected: onDirectorySelected,
      ),
    );
  }
}

class EditorWidget extends StatefulWidget {
  final FileMenuActions fileMenuActions;

  const EditorWidget({Key? key, required this.fileMenuActions})
      : super(key: key);

  @override
  _EditorWidgetState createState() => _EditorWidgetState();
}

class _EditorWidgetState extends State<EditorWidget> {
  final List<FileTab> _tabs = [];
  final ValueNotifier<int> _selectedTabIndex = ValueNotifier<int>(-1);

  @override
  void initState() {
    super.initState();
    widget.fileMenuActions.newFile = addEmptyTab;
    widget.fileMenuActions.openFile = openFile;
    widget.fileMenuActions.save = saveCurrentFile;
    widget.fileMenuActions.saveAs = saveFileAs;
  }

  void addEmptyTab() {
    setState(() {
      _tabs.add(FileTab(filePath: 'Untitled', content: ''));
      _selectedTabIndex.value = _tabs.length - 1;
    });
  }

  void openFile(File file) {
    try {
      String content = file.readAsStringSync();
      setState(() {
        _tabs.add(FileTab(filePath: file.path, content: content));
        _selectedTabIndex.value = _tabs.length - 1;
      });
    } catch (e) {
      print('Error reading file: $e');
      _showErrorDialog(file, e);
    }
  }

  void saveCurrentFile() {
    if (_selectedTabIndex.value != -1) {
      final currentTab = _tabs[_selectedTabIndex.value];
      if (currentTab.filePath != 'Untitled') {
        File(currentTab.filePath).writeAsStringSync(currentTab.content);
        currentTab.isModified = false;
      } else {
        saveFileAs();
      }
    }
  }

  Future<void> saveFileAs() async {
    if (_selectedTabIndex.value != -1) {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save file as:',
        fileName: 'Untitled.txt',
      );

      if (outputFile != null) {
        final currentTab = _tabs[_selectedTabIndex.value];
        File(outputFile).writeAsStringSync(currentTab.content);
        setState(() {
          currentTab.filePath = outputFile;
          currentTab.isModified = false;
        });
      }
    }
  }

  void _onTabsReordered(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final FileTab movedTab = _tabs.removeAt(oldIndex);
      _tabs.insert(newIndex, movedTab);

      if (_selectedTabIndex.value == oldIndex) {
        _selectedTabIndex.value = newIndex;
      } else if (_selectedTabIndex.value > oldIndex &&
          _selectedTabIndex.value <= newIndex) {
        _selectedTabIndex.value -= 1;
      } else if (_selectedTabIndex.value < oldIndex &&
          _selectedTabIndex.value >= newIndex) {
        _selectedTabIndex.value += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabBar(),
        Expanded(child: _buildEditor()),
      ],
    );
  }

  Widget _buildTabBar() {
    return ValueListenableBuilder<int>(
      valueListenable: _selectedTabIndex,
      builder: (context, selectedIndex, _) {
        if (_tabs.isNotEmpty) {
          return RepaintBoundary(
            child: TabBar(
              tabs: _tabs,
              selectedIndex: selectedIndex,
              onTabSelected: _selectTab,
              onTabClosed: _closeTab,
              onTabsReordered: _onTabsReordered,
            ),
          );
        } else {
          return Container();
        }
      },
    );
  }

  Widget _buildEditor() {
    return ValueListenableBuilder<int>(
      valueListenable: _selectedTabIndex,
      builder: (context, selectedIndex, _) {
        if (_tabs.isEmpty) {
          return _buildWelcomeScreen();
        }
        return _buildCodeEditor(selectedIndex);
      },
    );
  }

  Widget _buildWelcomeScreen() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Image(
        image: AssetImage(
          isDarkMode
              ? 'assets/starlight_logo_grey.png'
              : 'assets/starlight_logo_grey.png',
        ),
        height: 500,
      ),
    );
  }

  Widget _buildCodeEditor(int selectedIndex) {
    return CodeEditor(
      key: ValueKey(_tabs[selectedIndex].filePath),
      initialCode: _tabs[selectedIndex].content,
      filePath: _tabs[selectedIndex].filePath,
      onModified: (isModified) => _onFileModified(selectedIndex, isModified),
    );
  }

  void _selectTab(int index) {
    _selectedTabIndex.value = index;
  }

  void _closeTab(int index) {
    setState(() {
      _tabs.removeAt(index);
      if (_selectedTabIndex.value >= _tabs.length) {
        _selectedTabIndex.value = _tabs.isEmpty ? -1 : _tabs.length - 1;
      }
    });
  }

  void _onFileModified(int index, bool isModified) {
    _tabs[index].isModified = isModified;
  }

  void _showErrorDialog(File file, dynamic error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to open file: ${file.path}\n\nError: $error'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
