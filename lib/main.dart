import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/editor.dart';
import 'package:starlight/features/file_explorer/file_explorer.dart';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChannels.platform.invokeMethod<void>('setPreferredOrientations', []);
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
  String currentFilePath = '';
  String currentFileContent = '';

  void _openFile(File file) {
    setState(() {
      currentFilePath = file.path;
      currentFileContent = file.readAsStringSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          FileExplorer(
            onFileSelected: _openFile,
          ),
          Expanded(
            child: CodeEditor(
              initialCode: currentFileContent,
              filePath: currentFilePath,
            ),
          ),
        ],
      ),
    );
  }
}
