import 'dart:io';

import 'package:flutter/material.dart' hide TabBar;
import 'package:provider/provider.dart';
import 'package:starlight/features/editor/editor.dart';
import 'package:starlight/features/file_explorer/file_Explorer_controller.dart';
import 'package:starlight/features/file_explorer/file_explorer.dart';
import 'package:starlight/features/tabs/tab.dart';
import 'package:starlight/themes/dark.dart';
import 'package:starlight/themes/light.dart';
import 'package:starlight/utils/widgets/resizable_widget.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(700, 600),
    minimumSize: Size(700, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => FileExplorerController()),
      ],
      child: const MyApp(),
    ),
  );
}

class FileMenuActions {
  final Function(String, String) addNewTab;
  final Function(File) openFile;
  final Function() saveCurrentFile;
  final Function() saveFileAs;

  FileMenuActions({
    required this.addNewTab,
    required this.openFile,
    required this.saveCurrentFile,
    required this.saveFileAs,
  });

  void newFile() {
    addNewTab('Untitled', '');
  }

  void openFileDialog() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      openFile(file);
    }
  }

  void save() {
    saveCurrentFile();
  }

  void saveAs() {
    saveFileAs();
  }

  void exit(BuildContext context) {
    windowManager.close();
  }
}

class MenuActions {
  static void about(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Starlight',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2024 Starlight Team',
    );
  }

  static void copy(BuildContext context) {
    // CodeEditor.of(context).copySelection();
  }

  static void cut(BuildContext context) {
    // CodeEditor.of(context).cutSelection();
  }

  static void paste(BuildContext context) {
    // CodeEditor.of(context).pasteAtCursor();
  }

  static void redo(BuildContext context) {
    // CodeEditor.of(context).redo();
  }

  static void undo(BuildContext context) {
    // CodeEditor.of(context).undo();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          home: const MyHomePage(),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final List<FileTab> _tabs = [];
  final ValueNotifier<int> _selectedTabIndex = ValueNotifier<int>(-1);
  late final FileExplorer _fileExplorer;
  late final FileMenuActions _fileMenuActions;

  @override
  void initState() {
    super.initState();
    _fileExplorer = FileExplorer(
      key: const ValueKey('file_explorer'),
      onFileSelected: _openFile,
    );
    _fileMenuActions = FileMenuActions(
      addNewTab: _addNewTab,
      openFile: _openFile,
      saveCurrentFile: _saveCurrentFile,
      saveFileAs: _saveFileAs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          _buildAppBar(context, themeProvider, isDarkMode),
          _buildDesktopMenu(context),
          Expanded(
            child: Row(
              children: [
                ResizableWidget(
                  maxWidthPercentage: 0.9,
                  child: _fileExplorer,
                ),
                Expanded(
                  child: _buildMainContent(isDarkMode),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      child: Row(
        children: [
          const SizedBox(width: 70),
          Expanded(
            child: GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
              child: Center(
                child: Text(
                  'starlight',
                  style: Theme.of(context).appBarTheme.titleTextStyle,
                ),
              ),
            ),
          ),
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

  Widget _buildMainContent(bool isDarkMode) {
    return Column(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: _selectedTabIndex,
          builder: (context, selectedIndex, child) {
            return TabBar(
              tabs: _tabs,
              selectedIndex: selectedIndex,
              onTabSelected: _selectTab,
              onTabClosed: _closeTab,
            );
          },
        ),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: _selectedTabIndex,
            builder: (context, selectedIndex, child) {
              return selectedIndex != -1
                  ? _buildCodeEditor(selectedIndex)
                  : _buildWelcomeScreen(isDarkMode);
            },
          ),
        ),
      ],
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

  Widget _buildWelcomeScreen(bool isDarkMode) {
    return Center(
      child: Image(
        image: AssetImage(
          isDarkMode
              ? 'assets/starlight_logo_white.png'
              : 'assets/starlight_logo_grey.png',
        ),
        height: 500,
      ),
    );
  }

  void _addNewTab(String filePath, String content) {
    setState(() {
      _tabs.add(FileTab(filePath: filePath, content: content));
      _selectedTabIndex.value = _tabs.length - 1;
    });
  }

  void _openFile(File file) {
    try {
      String content = file.readAsStringSync();
      _addNewTab(file.path, content.isEmpty ? '\n' : content);
    } catch (e) {
      print('Error reading file: $e');
      _showErrorDialog(file, e);
    }
  }

  void _saveCurrentFile() {
    if (_selectedTabIndex.value != -1) {
      final currentTab = _tabs[_selectedTabIndex.value];
      if (currentTab.filePath != 'Untitled') {
        File(currentTab.filePath).writeAsStringSync(currentTab.content);
        currentTab.isModified = false;
      } else {
        _saveFileAs();
      }
    }
  }

  void _saveFileAs() async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: 'Untitled.txt',
    );

    if (outputFile != null) {
      final currentTab = _tabs[_selectedTabIndex.value];
      File(outputFile).writeAsStringSync(currentTab.content);
      currentTab.filePath = outputFile;
      currentTab.isModified = false;
    }
  }

  void _closeTab(int index) {
    setState(() {
      _tabs.removeAt(index);
      if (_selectedTabIndex.value >= _tabs.length) {
        _selectedTabIndex.value = _tabs.isEmpty ? -1 : _tabs.length - 1;
      }
    });
  }

  void _selectTab(int index) {
    _selectedTabIndex.value = index;
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
