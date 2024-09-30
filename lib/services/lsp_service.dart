import 'package:flutter/foundation.dart';
import 'package:starlight/features/editor/services/lsp_client.dart';

class LspService extends ChangeNotifier {
  LspClient? _lspClient;
  String _currentLanguage = 'plaintext';
  final ValueNotifier<bool> isLspRunningNotifier = ValueNotifier<bool>(false);

  final List<String> supportedLanguages = [
    'plaintext',
    'javascript',
    'python',
    'dart',
  ];

  String get currentLanguage => _currentLanguage;
  bool get isLspRunning => isLspRunningNotifier.value;

  Future<void> setLanguage(String language) async {
    if (_currentLanguage != language) {
      _currentLanguage = language;
      await _restartLsp();
      notifyListeners();
    }
  }

  void updateForFile(String filePath) {
    final newLanguage = _getLanguageFromFilePath(filePath);
    if (newLanguage != _currentLanguage) {
      setLanguage(newLanguage);
    }
  }

  String _getLanguageFromFilePath(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'js':
        return 'javascript';
      case 'py':
        return 'python';
      case 'dart':
        return 'dart';
      default:
        return 'plaintext';
    }
  }

  Future<void> _restartLsp() async {
    await stopLsp();
    await startLsp();
  }

  Future<void> startLsp() async {
    if (_lspClient != null) return;

    String command;
    List<String> arguments;

    switch (_currentLanguage) {
      case 'javascript':
        command = 'javascript-typescript-langserver';
        arguments = ['--stdio'];
        break;
      case 'python':
        command = 'pyls';
        arguments = [];
        break;
      case 'dart':
        command = 'dart';
        arguments = ['language-server'];
        break;
      default:
        // For unsupported languages or plaintext, don't start an LSP
        isLspRunningNotifier.value = false;
        notifyListeners();
        return;
    }

    _lspClient = LspClient();
    try {
      await _lspClient!.start(command, arguments);
      isLspRunningNotifier.value = true;
    } catch (e) {
      print('Failed to start LSP: $e');
      isLspRunningNotifier.value = false;
    }
    notifyListeners();
  }

  Future<void> stopLsp() async {
    if (_lspClient != null) {
      await _lspClient!.stop();
      _lspClient = null;
      isLspRunningNotifier.value = false;
      notifyListeners();
    }
  }
}
