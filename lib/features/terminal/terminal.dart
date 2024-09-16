import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:path_provider/path_provider.dart';

class IntegratedTerminal extends StatefulWidget {
  const IntegratedTerminal({super.key});

  @override
  IntegratedTerminalState createState() => IntegratedTerminalState();
}

class IntegratedTerminalState extends State<IntegratedTerminal> {
  late Terminal terminal;
  late TerminalController terminalController;
  Process? process;
  final FocusNode _focusNode = FocusNode();
  String _currentInput = '';
  String _currentDirectory = '';

  @override
  void initState() {
    super.initState();
    terminal = Terminal();
    terminalController = TerminalController();
    _startProcess();
  }

  @override
  void dispose() {
    process?.kill();
    _focusNode.dispose();
    terminalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyPress,
      child: TerminalView(
        terminal,
        controller: terminalController,
        autofocus: true,
      ),
    );
  }

  void _handleKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _sendCommand(_currentInput);
        _currentInput = '';
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_currentInput.isNotEmpty) {
          setState(() {
            _currentInput =
                _currentInput.substring(0, _currentInput.length - 1);
            terminal.write('\b \b');
          });
        }
      } else if (event.character != null && event.character!.isNotEmpty) {
        setState(() {
          _currentInput += event.character!;
          terminal.write(event.character!);
        });
      }
    }
  }

  void _sendCommand(String command) async {
    terminal.write('\r\n');
    if (command == 'clear') {
      _clearTerminal();
      _writePrompt();
    } else if (command.startsWith('cd ')) {
      String newDir = command.substring(3).trim();
      _updateCurrentDirectory(newDir);
      process?.stdin.writeln(command);
      _writePrompt();
    } else {
      process?.stdin.writeln(command);
    }
  }

  void _clearTerminal() {
    terminal.write('\x1B[2J\x1B[0;0H');
  }

  void _updateCurrentDirectory(String newDir) {
    setState(() {
      if (newDir.startsWith('/')) {
        _currentDirectory = newDir;
      } else if (newDir == '..') {
        _currentDirectory =
            _currentDirectory.substring(0, _currentDirectory.lastIndexOf('/'));
        if (_currentDirectory.isEmpty) _currentDirectory = '/';
      } else {
        _currentDirectory = '$_currentDirectory/$newDir';
      }
      _currentDirectory = _currentDirectory.replaceAll('//', '/');
    });
  }

  void _writePrompt() {
    terminal
        .write('${_currentDirectory.isEmpty ? '/' : _currentDirectory} \$ ');
  }

  Future<void> _startProcess() async {
    final directory = await getApplicationDocumentsDirectory();
    final homeDir = directory.path;
    _currentDirectory = homeDir;

    String command;
    List<String> args;

    if (Platform.isWindows) {
      command = 'powershell.exe';
      args = ['/K'];
    } else if (Platform.isMacOS || Platform.isLinux) {
      command = '/bin/sh';
      args = ['-i'];
    } else {
      terminal.write('Unsupported platform\r\n');
      return;
    }

    await startProcess(
      command: command,
      args: args,
      workingDirectory: homeDir,
      onOutput: (output) {
        setState(() {
          terminal.write(output);
        });
      },
      onError: (errorOutput) {
        setState(() {
          terminal.write(errorOutput);
        });
      },
      onExit: (exitCode) {
        terminal.write('Process exited with code: $exitCode\r\n');
      },
    );

    _writePrompt();
  }

  Future<void> startProcess({
    required String command,
    required List<String> args,
    required String workingDirectory,
    required void Function(String) onOutput,
    required void Function(String) onError,
    required void Function(int) onExit,
  }) async {
    try {
      String systemPath = Platform.environment['PATH']!;

      final env = {
        'HOME': workingDirectory,
        'TERM': 'xterm-256color',
        'PATH': systemPath,
        'LANG': 'en_US.UTF-8',
      };

      process = await Process.start(
        command,
        args,
        environment: env,
        workingDirectory: workingDirectory,
      );

      // Handle stdout
      process!.stdout
          .transform(const SystemEncoding().decoder)
          .listen((output) {
        onOutput(output);
      });

      // Handle stderr
      process!.stderr
          .transform(const SystemEncoding().decoder)
          .listen((errorOutput) {
        onError(errorOutput);
      });

      // Handle exit code
      process!.exitCode.then((exitCode) {
        onExit(exitCode);
      });
    } catch (e) {
      terminal.write('Error starting process: $e\r\n');
    }
  }
}
