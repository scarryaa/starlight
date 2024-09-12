import 'package:flutter/material.dart' hide TabBar;
import 'package:starlight/features/editor/editor.dart';
import 'package:starlight/features/file_explorer/file_explorer.dart';
import 'package:starlight/features/tabs/tab.dart';
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
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        dividerTheme: const DividerThemeData(
          color: Colors.grey,
          thickness: 1,
        ),
      ),
      home: const MyHomePage(),
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
    return Scaffold(
      body: Row(
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
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image(
                                image: AssetImage(
                                    'assets/starlight_logo_grey.png'),
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
    );
  }
}
