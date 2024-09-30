import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide TabBar;
import 'package:starlight/features/editor/domain/enums/git_diff_type.dart';
import 'package:starlight/features/editor/presentation/editor_widget.dart';
import 'package:starlight/features/tabs/presentation/tab.dart';
import 'package:starlight/presentation/screens/search_all_files.dart';
import 'package:starlight/services/keyboard_shortcut_service.dart';

class EditorController {
  final KeyboardShortcutService keyboardShortcutService;
  final Function(String)? onContentChanged;

  final List<FileTab> _tabs = [];
  final ValueNotifier<int> _selectedTabIndex = ValueNotifier<int>(-1);
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();

  EditorContentKey _currentEditorKey = const EditorContentKey('');
  bool _isSearchVisible = false;
  bool _isReplaceVisible = false;
  String _searchTerm = '';
  String _replaceTerm = '';
  List<int> _matchPositions = [];
  int _currentMatchIndex = -1;
  Timer? _debounceTimer;
  bool _matchCase = false;
  bool _matchWholeWord = false;
  bool _useRegex = false;
  String _lastSearchTerm = '';
  double _zoomLevel = 1.0;
  final double _zoomStep = 0.1;
  final double _minZoom = 0.5;
  final double _maxZoom = 2.0;

  EditorController({
    required this.keyboardShortcutService,
    this.onContentChanged,
  });

  bool get hasOpenTabs => _tabs.isNotEmpty;
  bool get isSearchVisible => _isSearchVisible;
  bool get isReplaceVisible => _isReplaceVisible;
  bool get isSearchAllFilesTabOpen =>
      _selectedTabIndex.value != -1 &&
      _tabs[_selectedTabIndex.value].filePath == 'Project Search';
  bool get hasNoMatches => _matchPositions.isEmpty && _searchTerm.isNotEmpty;
  List<FileTab> get tabs => _tabs;
  FileTab get currentTab => _tabs[_selectedTabIndex.value];
  ValueNotifier<int> get selectedTabIndex => _selectedTabIndex;
  TextEditingController get searchController => _searchController;
  TextEditingController get replaceController => _replaceController;
  EditorContentKey get currentEditorKey => _currentEditorKey;
  List<int> get matchPositions => _matchPositions;
  int get currentMatchIndex => _currentMatchIndex;
  String get searchTerm => _searchTerm;
  bool get matchCase => _matchCase;
  bool get matchWholeWord => _matchWholeWord;
  bool get useRegex => _useRegex;
  double get zoomLevel => _zoomLevel;

  void addSearchAllFilesTab(
      String rootDirectory, Function(File) onFileSelected) {
    _tabs.add(FileTab(
      filePath: 'Project Search',
      content: '',
      customWidget: SearchAllFilesTab(
        rootDirectory: rootDirectory,
        onFileSelected: onFileSelected,
      ),
    ));
    _selectedTabIndex.value = _tabs.length - 1;
  }

  Future<void> updateGitDiff(int tabIndex) async {
    if (tabIndex >= 0 && tabIndex < _tabs.length) {
      final tab = _tabs[tabIndex];
      if (tab.filePath != 'Untitled' && tab.filePath != 'Project Search') {
        final gitDiff = await _getGitDiff(tab.filePath);
        tab.gitDiff = gitDiff;
        print(
            'Updated git diff for tab $tabIndex: ${tab.gitDiff}'); // Debug print
      }
    }
  }

  Future<Map<int, GitDiffType>> _getGitDiff(String filePath) async {
    final result = await Process.run('git', ['diff', '--unified=0', filePath]);
    if (result.exitCode == 0) {
      final diffOutput = result.stdout as String;
      final gitDiff = _parseGitDiff(diffOutput);
      print('Generated git diff: $gitDiff'); // Debug print
      return gitDiff;
    }
    return {};
  }

  Map<int, GitDiffType> _parseGitDiff(String diffOutput) {
    final Map<int, GitDiffType> gitDiff = {};
    final lines = diffOutput.split('\n');
    int currentLine = 0;
    for (final line in lines) {
      if (line.startsWith('+')) {
        gitDiff[currentLine] = GitDiffType.added;
        currentLine++;
      } else if (line.startsWith('-')) {
        gitDiff[currentLine] = GitDiffType.deleted;
      } else if (line.startsWith('@@ ')) {
        final match = RegExp(r'@@ -\d+(?:,\d+)? \+(\d+)').firstMatch(line);
        if (match != null) {
          currentLine = int.parse(match.group(1)!) - 1;
        }
      } else {
        currentLine++;
      }
    }
    return gitDiff;
  }

  void updateCursorPosition(int position) {
    if (_selectedTabIndex.value != -1) {
      _tabs[_selectedTabIndex.value].cursorPosition = position;
    }
  }

  void updateSelection(int start, int end) {
    if (_selectedTabIndex.value != -1) {
      final currentTab = _tabs[_selectedTabIndex.value];
      currentTab.selectionStart = start;
      currentTab.selectionEnd = end;
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _replaceController.dispose();
    _selectedTabIndex.dispose();
  }

  void addEmptyTab() {
    _tabs.add(FileTab(filePath: 'Untitled', content: ''));
    _selectedTabIndex.value = _tabs.length - 1;
  }

  void closeAllTabs() {
    _tabs.clear();
    _selectedTabIndex.value = -1;
    _currentEditorKey = const EditorContentKey('');
  }

  void closeOtherTabs(int index) {
    final currentTab = _tabs[index];
    _tabs.clear();
    _tabs.add(currentTab);
    _selectedTabIndex.value = 0;
    _currentEditorKey = EditorContentKey(currentTab.content);
  }

  void closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;

    // Remove the tab at the specified index
    _tabs.removeAt(index);

    if (_tabs.isEmpty) {
      _selectedTabIndex.value = -1;
      _currentEditorKey = const EditorContentKey('');
      return;
    }

    // Adjust selected index: select the next tab if possible
    if (index == _tabs.length) {
      _selectedTabIndex.value = index - 1; // Last tab closed, select previous
    } else {
      _selectedTabIndex.value = index; // Select the next tab
    }

    _updateCurrentEditorKey();
  }

  void closeTabsToRight(int index) {
    final tabsToClose = _tabs.where((tab) => !tab.isPinned).toList();

    // Keep all pinned tabs and tabs to the left of the current tab
    _tabs.removeWhere((tab) => tabsToClose.indexOf(tab) > index);

    if (_selectedTabIndex.value >= _tabs.length) {
      _selectedTabIndex.value = _tabs.length - 1;
    }
    _updateCurrentEditorKey();
  }

  Future<void> openFile(File file) async {
    int existingTabIndex = _tabs.indexWhere((tab) => tab.filePath == file.path);
    if (existingTabIndex != -1) {
      _selectedTabIndex.value = existingTabIndex;
      _currentEditorKey = EditorContentKey(_tabs[existingTabIndex].content);
    } else {
      String content = await file.readAsString();
      _tabs.add(FileTab(filePath: file.path, content: content));
      _selectedTabIndex.value = _tabs.length - 1;
      _currentEditorKey = EditorContentKey(content);
    }
    await updateGitDiff(_selectedTabIndex.value);
  }

  void reorderTabs(int oldIndex, int newIndex) {
    if (_tabs[oldIndex].isPinned != _tabs[newIndex].isPinned) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final FileTab movedTab = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, movedTab);
    _updateSelectedIndexAfterReorder(oldIndex, newIndex);
  }

  Future<void> saveCurrentFile() async {
    if (_selectedTabIndex.value != -1) {
      await saveTab(_selectedTabIndex.value);
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
        await File(outputFile).writeAsString(currentTab.content);
        currentTab.filePath = outputFile;
        currentTab.markAsSaved();
      }
    }
  }

  Future<void> saveTab(int index) async {
    if (index >= 0 && index < _tabs.length) {
      final currentTab = _tabs[index];
      if (currentTab.filePath != 'Untitled') {
        await File(currentTab.filePath).writeAsString(currentTab.content);
        currentTab.markAsSaved();
        await updateGitDiff(index);
      } else {
        await saveFileAs();
      }
    }
  }

  void selectTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _selectedTabIndex.value = index;
      _currentEditorKey = EditorContentKey(_tabs[index].content);
    }
  }

  void toggleSearchVisibility() {
    _isSearchVisible = !_isSearchVisible;
    if (_isSearchVisible) {
      if (_lastSearchTerm.isNotEmpty) {
        _searchTerm = _lastSearchTerm;
        _searchController.text = _lastSearchTerm;
        _selectAllMatches();
      }
    } else {
      _lastSearchTerm = _searchTerm;
      _searchTerm = '';
      _matchPositions = [];
      _currentMatchIndex = -1;
    }
  }

  void toggleReplaceVisibility() {
    _isReplaceVisible = !_isReplaceVisible;
  }

  void toggleMatchCase() {
    _matchCase = !_matchCase;
    updateSearchTerm(_searchTerm);
  }

  void toggleMatchWholeWord() {
    _matchWholeWord = !_matchWholeWord;
    updateSearchTerm(_searchTerm);
  }

  void toggleUseRegex() {
    _useRegex = !_useRegex;
    updateSearchTerm(_searchTerm);
  }

  void updateSearchTerm(String term) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchTerm = term;
      if (term.isEmpty) {
        _matchPositions = [];
        _currentMatchIndex = -1;
      } else {
        _selectAllMatches();
      }
    });
  }

  void updateReplaceTerm(String term) {
    _replaceTerm = term;
  }

  void selectNextMatch() {
    if (_matchPositions.isNotEmpty) {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchPositions.length;
      _updateCodeEditorSelection(true);
    }
  }

  void selectPreviousMatch() {
    if (_matchPositions.isNotEmpty) {
      _currentMatchIndex = (_currentMatchIndex - 1 + _matchPositions.length) %
          _matchPositions.length;
      _updateCodeEditorSelection(true);
    }
  }

  void replaceNext() {
    if (_matchPositions.isNotEmpty && _currentMatchIndex != -1) {
      final currentTab = _tabs[_selectedTabIndex.value];
      int start = _matchPositions[_currentMatchIndex];
      String newContent = currentTab.content
          .replaceRange(start, start + _searchTerm.length, _replaceTerm);
      currentTab.updateContent(newContent);
      _updateMatchesAfterReplace();
    }
  }

  void replaceAll() {
    if (_matchPositions.isNotEmpty) {
      final currentTab = _tabs[_selectedTabIndex.value];
      String newContent = currentTab.content;
      for (int i = _matchPositions.length - 1; i >= 0; i--) {
        int start = _matchPositions[i];
        newContent = newContent.replaceRange(
            start, start + _searchTerm.length, _replaceTerm);
      }
      currentTab.updateContent(newContent);
      _updateMatchesAfterReplace();
    }
  }

  void closeSearch() {
    _isSearchVisible = false;
    _lastSearchTerm = _searchTerm;
    _searchTerm = '';
    _matchPositions = [];
    _currentMatchIndex = -1;
  }

  void onCodeEditorContentChanged(String newContent) {
    if (_selectedTabIndex.value != -1) {
      final currentTab = _tabs[_selectedTabIndex.value];
      if (currentTab.content != newContent) {
        currentTab.updateContent(newContent);
        onContentChanged?.call(newContent);
        keyboardShortcutService.editorService.handleContentChanged(
          newContent,
          cursorPosition: currentTab.cursorPosition,
          selectionStart: currentTab.selectionStart,
          selectionEnd: currentTab.selectionEnd,
        );
      }
    }
  }

  void _selectAllMatches() {
    if (_selectedTabIndex.value != -1) {
      final currentTab = _tabs[_selectedTabIndex.value];
      final content = currentTab.content;
      _matchPositions = _findAllOccurrences(content, _searchTerm);
      _currentMatchIndex = _matchPositions.isNotEmpty ? 0 : -1;
    }
  }

  List<int> _findAllOccurrences(String text, String searchTerm) {
    List<int> positions = [];
    if (_useRegex) {
      try {
        RegExp regExp =
            RegExp(searchTerm, caseSensitive: _matchCase, multiLine: true);
        for (Match match in regExp.allMatches(text)) {
          positions.add(match.start);
        }
      } catch (e) {
        print('Invalid regex: $e');
      }
    } else {
      String pattern =
          _matchWholeWord ? r'\b' + searchTerm + r'\b' : searchTerm;
      RegExp regExp =
          RegExp(pattern, caseSensitive: _matchCase, multiLine: true);
      for (Match match in regExp.allMatches(text)) {
        positions.add(match.start);
      }
    }
    return positions;
  }

  void _updateCodeEditorSelection(bool moveCursorToEnd) {
    if (_matchPositions.isNotEmpty && _currentMatchIndex != -1) {
      int start = _matchPositions[_currentMatchIndex];
      int end = start + _searchTerm.length;
      if (_selectedTabIndex.value != -1) {
        final currentTab = _tabs[_selectedTabIndex.value];
        currentTab.selectionStart = start + 1;
        currentTab.selectionEnd = end + 1;
        currentTab.cursorPosition = moveCursorToEnd ? end : start;
      }
    }
  }

  void _updateMatchesAfterReplace() {
    _selectAllMatches();
  }

  void _updateCurrentEditorKey() {
    if (_selectedTabIndex.value != -1) {
      _currentEditorKey =
          EditorContentKey(_tabs[_selectedTabIndex.value].content);
    } else {
      _currentEditorKey = const EditorContentKey('');
    }
  }

  void _updateSelectedIndexAfterReorder(int oldIndex, int newIndex) {
    if (_selectedTabIndex.value == oldIndex) {
      _selectedTabIndex.value = newIndex;
    } else if (_selectedTabIndex.value > oldIndex &&
        _selectedTabIndex.value <= newIndex) {
      _selectedTabIndex.value -= 1;
    } else if (_selectedTabIndex.value < oldIndex &&
        _selectedTabIndex.value >= newIndex) {
      _selectedTabIndex.value += 1;
    }
  }

  void handleZoomChange(double newZoomLevel) {
    _zoomLevel = newZoomLevel.clamp(_minZoom, _maxZoom);
    if (_selectedTabIndex.value != -1) {
      final currentTab = _tabs[_selectedTabIndex.value];
      currentTab.triggerRecalculation?.call(_zoomLevel);
    }
  }

  void zoomIn() => handleZoomChange(_zoomLevel + _zoomStep);
  void zoomOut() => handleZoomChange(_zoomLevel - _zoomStep);
  void resetZoom() => handleZoomChange(1.0);
}
