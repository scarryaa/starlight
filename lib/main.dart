import 'package:flutter/material.dart' hide TabBar;
import 'package:provider/provider.dart';
import 'package:starlight/features/editor/editor.dart';
import 'package:starlight/features/file_explorer/file_explorer.dart';
import 'package:starlight/features/tabs/tab.dart';
import 'package:starlight/themes/dark.dart';
import 'package:starlight/themes/light.dart';
import 'dart:io';
import 'package:starlight/utils/widgets/resizable_widget.dart';
import 'package:window_manager/window_manager.dart';

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
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
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

class _MyHomePageState extends State<MyHomePage> {
  final List<FileTab> _tabs = [];
  final ValueNotifier<int> _selectedTabIndex = ValueNotifier<int>(-1);

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

  void _openFile(File file) {
    try {
      String content = file.readAsStringSync();
      _addNewTab(file.path, content.isEmpty ? '\n' : content);
    } catch (e) {
      print('Error reading file: $e');
      _showErrorDialog(file, e);
    }
  }

  void _addNewTab(String filePath, String content) {
    setState(() {
      _tabs.add(FileTab(filePath: filePath, content: content));
      _selectedTabIndex.value = _tabs.length - 1;
    });
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 30,
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: Row(
              children: [
                const SizedBox(width: 70), // Space for traffic lights
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
          ),
          // Main content
          Expanded(
            child: Row(
              children: [
                ResizableWidget(
                  maxWidthPercentage: 0.9,
                  child: FileExplorer(
                    key: const ValueKey('file_explorer'),
                    onFileSelected: _openFile,
                  ),
                ),
                Expanded(
                  child: Column(
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
                            if (selectedIndex != -1) {
                              return CodeEditor(
                                key: ValueKey(_tabs[selectedIndex].filePath),
                                initialCode: _tabs[selectedIndex].content,
                                filePath: _tabs[selectedIndex].filePath,
                                onModified: (isModified) =>
                                    _onFileModified(selectedIndex, isModified),
                              );
                            } else {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image(
                                      image: AssetImage(
                                        isDarkMode
                                            ? 'assets/starlight_logo_white.png'
                                            : 'assets/starlight_logo_grey.png',
                                      ),
                                      height: 500,
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
