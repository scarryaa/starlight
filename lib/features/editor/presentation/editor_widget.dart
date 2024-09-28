import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide TabBar;
import 'package:provider/provider.dart';
import 'package:starlight/features/editor/presentation/editor.dart';
import 'package:starlight/features/file_menu/presentation/file_menu_actions.dart';
import 'package:starlight/features/tabs/presentation/tab.dart';
import 'package:starlight/features/toasts/error_toast.dart';
import 'package:starlight/presentation/screens/search_all_files.dart';
import 'package:starlight/services/file_explorer_service.dart';
import 'package:starlight/services/keyboard_shortcut_service.dart';

class EditorContentKey extends ValueKey<String> {
  const EditorContentKey(super.value);
}

class EditorWidget extends StatefulWidget {
  final KeyboardShortcutService keyboardShortcutService;
  final FileMenuActions fileMenuActions;
  final ValueNotifier<String?> rootDirectory;
  final Function(String)? onContentChanged;

  const EditorWidget({
    super.key,
    required this.fileMenuActions,
    required this.rootDirectory,
    required this.keyboardShortcutService,
    this.onContentChanged,
  });

  @override
  EditorWidgetState createState() => EditorWidgetState();
}

class EditorWidgetState extends State<EditorWidget> {
  late final EditorController _editorController;
  late final ErrorToastManager _toastManager;
  late final FocusNode _editorFocusNode;
  late final FileExplorerService _fileExplorerService;

  @override
  void initState() {
    super.initState();
    _editorController = EditorController(
      keyboardShortcutService: widget.keyboardShortcutService,
      onContentChanged: widget.onContentChanged,
    );
    _editorFocusNode = FocusNode();
    _toastManager = ErrorToastManager(context);
    _fileExplorerService = context.read<FileExplorerService>();
    _initializeFileMenuActions();
  }

  void _initializeFileMenuActions() {
    widget.fileMenuActions
      ..newFile = addEmptyTab
      ..openFile = openFile
      ..save = saveCurrentFile
      ..saveAs = saveFileAs;
  }

  void addSearchAllFilesTab() => _editorController.addSearchAllFilesTab(
      widget.rootDirectory.value ?? '', openFile);
  void closeCurrentFile() =>
      _editorController.closeTab(_editorController.selectedTabIndex.value);
  void updateContent(String newContent,
      [int? cursorPosition, int? selectionStart, int? selectionEnd]) {
    _editorController.onCodeEditorContentChanged(newContent);
    if (cursorPosition != null)
      _editorController.updateCursorPosition(cursorPosition);
    if (selectionStart != null && selectionEnd != null)
      _editorController.updateSelection(selectionStart, selectionEnd);
  }

  void maintainFocus() => _editorFocusNode.requestFocus();
  void addEmptyTab() => _editorController.addEmptyTab();
  void openFile(File file) => _editorController.openFile(file);
  void saveCurrentFile() => _editorController.saveCurrentFile();
  void saveFileAs() => _editorController.saveFileAs();
  void resetZoom() => _editorController.resetZoom();
  void showFindDialog() => _editorController.toggleSearchVisibility();
  void showReplaceDialog() {
    _editorController.toggleSearchVisibility();
    _editorController.toggleReplaceVisibility();
  }

  void zoomIn() => _editorController.zoomIn();
  void zoomOut() => _editorController.zoomOut();

  @override
  void dispose() {
    _editorController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _editorController.selectedTabIndex,
      builder: (context, selectedIndex, _) {
        return Column(
          children: [
            _buildTabBar(),
            if (_editorController.hasOpenTabs &&
                !_editorController.isSearchAllFilesTabOpen)
              _buildSearchToggleButton(),
            if (_editorController.isSearchVisible &&
                _editorController.hasOpenTabs &&
                !_editorController.isSearchAllFilesTabOpen)
              _buildCompactSearchBar(),
            Expanded(child: _buildEditor()),
          ],
        );
      },
    );
  }

  Widget _buildTabBar() {
    return ValueListenableBuilder<int>(
      valueListenable: _editorController.selectedTabIndex,
      builder: (context, selectedIndex, _) {
        if (_editorController.hasOpenTabs) {
          return RepaintBoundary(
            child: TabBar(
              tabs: _editorController.tabs,
              selectedIndex: selectedIndex,
              onTabSelected: _editorController.selectTab,
              onTabClosed: _editorController.closeTab,
              onTabsReordered: _editorController.reorderTabs,
              onCloseOtherTabs: _editorController.closeOtherTabs,
              onCloseAllTabs: _editorController.closeAllTabs,
              onCloseTabsToRight: _editorController.closeTabsToRight,
              onTabSaved: _editorController.saveTab,
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildSearchToggleButton() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final defaultIconColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: _editorController.isSearchVisible
            ? null
            : Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildCurrentFilePath()),
          IconButton(
            iconSize: 20,
            icon: Icon(Icons.folder_open, color: defaultIconColor),
            onPressed: _revealInAppFileExplorer,
            tooltip: 'Reveal in File Explorer',
          ),
          IconButton(
            iconSize: 20,
            icon: Icon(
              Icons.search,
              color: _editorController.isSearchVisible
                  ? theme.colorScheme.primary
                  : defaultIconColor,
            ),
            onPressed: _editorController.toggleSearchVisibility,
            tooltip: _editorController.isSearchVisible
                ? 'Close Search'
                : 'Open Search',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentFilePath() {
    if (!_editorController.hasOpenTabs) return const SizedBox.shrink();

    final currentTab = _editorController.currentTab;
    final rootDirectory = widget.rootDirectory.value;

    if (rootDirectory == null ||
        !currentTab.filePath.startsWith(rootDirectory)) {
      return Text(
        currentTab.filePath,
        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        overflow: TextOverflow.ellipsis,
      );
    }

    String relativeFilePath =
        currentTab.filePath.substring(rootDirectory.length);
    if (relativeFilePath.startsWith('/')) {
      relativeFilePath = relativeFilePath.substring(1);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        relativeFilePath,
        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCompactSearchBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: _editorController.isReplaceVisible
            ? null
            : Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          _buildSearchRow(theme, colorScheme, textTheme),
          if (_editorController.isReplaceVisible)
            _buildReplaceRow(theme, colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildSearchRow(
      ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _editorController.searchController,
              style: textTheme.bodyMedium?.copyWith(
                color: _editorController.hasNoMatches
                    ? colorScheme.error
                    : colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurface.withOpacity(0.6)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleButton('Aa', _editorController.matchCase,
                        _editorController.toggleMatchCase, 'Match case'),
                    _buildToggleButton(
                        'W',
                        _editorController.matchWholeWord,
                        _editorController.toggleMatchWholeWord,
                        'Match whole word'),
                    _buildToggleButton(
                        '.*',
                        _editorController.useRegex,
                        _editorController.toggleUseRegex,
                        'Use regular expression'),
                  ],
                ),
              ),
              onChanged: _editorController.updateSearchTerm,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.find_replace,
              color: _editorController.isReplaceVisible
                  ? colorScheme.primary
                  : colorScheme.onSurface,
            ),
            onPressed: _editorController.toggleReplaceVisibility,
            tooltip: _editorController.isReplaceVisible
                ? 'Hide replace'
                : 'Show replace',
          ),
          IconButton(
            icon: Icon(Icons.chevron_left,
                color: colorScheme.onSurface, size: 20),
            onPressed: _editorController.selectPreviousMatch,
            tooltip: 'Previous match',
          ),
          IconButton(
            icon: Icon(Icons.chevron_right,
                color: colorScheme.onSurface, size: 20),
            onPressed: _editorController.selectNextMatch,
            tooltip: 'Next match',
          ),
          _buildMatchCountDisplay(textTheme, colorScheme),
          IconButton(
            icon: Icon(Icons.close, color: colorScheme.onSurface, size: 20),
            onPressed: _editorController.closeSearch,
            tooltip: 'Close search',
          ),
        ],
      ),
    );
  }

  Widget _buildReplaceRow(
      ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _editorController.replaceController,
              style:
                  textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Replace...',
                hintStyle: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurface.withOpacity(0.6)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              ),
              onChanged: _editorController.updateReplaceTerm,
            ),
          ),
          IconButton(
            onPressed: _editorController.replaceNext,
            icon: const Icon(Icons.arrow_forward),
            color: colorScheme.onSurface,
            tooltip: 'Replace Next',
            iconSize: 20,
          ),
          IconButton(
            onPressed: _editorController.replaceAll,
            icon: const Icon(Icons.sync),
            color: colorScheme.onSurface,
            tooltip: 'Replace All',
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
      String label, bool isActive, VoidCallback onPressed, String tooltip) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchCountDisplay(TextTheme textTheme, ColorScheme colorScheme) {
    return Container(
      width: 60,
      alignment: Alignment.center,
      child: Text(
        '${_editorController.currentMatchIndex + 1}/${_editorController.matchPositions.length}',
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return ValueListenableBuilder<int>(
      valueListenable: _editorController.selectedTabIndex,
      builder: (context, selectedIndex, _) {
        if (!_editorController.hasOpenTabs) {
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
    final currentTab = _editorController.tabs[selectedIndex];
    if (currentTab.customWidget != null) {
      return currentTab.customWidget!;
    }
    return CodeEditor(
      key: _editorController.currentEditorKey,
      initialCode: currentTab.content,
      filePath: currentTab.filePath,
      onContentChanged: _editorController.onCodeEditorContentChanged,
      matchPositions: _editorController.matchPositions,
      searchTerm: _editorController.searchTerm,
      currentMatchIndex: _editorController.currentMatchIndex,
      onSelectPreviousMatch: _editorController.selectPreviousMatch,
      onSelectNextMatch: _editorController.selectNextMatch,
      onReplace: _editorController.replaceNext,
      onReplaceAll: _editorController.replaceAll,
      onUpdateSearchTerm: _editorController.updateSearchTerm,
      onUpdateReplaceTerm: _editorController.updateReplaceTerm,
      selectionStart: currentTab.selectionStart,
      selectionEnd: currentTab.selectionEnd,
      onZoomChanged: (recalculateFunc) {
        currentTab.triggerRecalculation = recalculateFunc;
      },
      cursorPosition: currentTab.cursorPosition,
      keyboardShortcutService: widget.keyboardShortcutService,
      zoomLevel: _editorController.zoomLevel,
      focusNode: _editorFocusNode,
    );
  }

  void _openFile(File file) {
    try {
      _editorController.openFile(file);
    } catch (e) {
      print('Error reading file: $e');
      _toastManager.showErrorToast(file.path, e.toString());
    }
  }

  void _revealInAppFileExplorer() {
    if (_editorController.hasOpenTabs) {
      final currentTab = _editorController.currentTab;
      if (currentTab.filePath != 'Untitled' &&
          currentTab.filePath != 'Project Search') {
        _fileExplorerService.revealAndExpandToFile(currentTab.filePath);
      } else {
        _toastManager.showErrorToast('Reveal in File Explorer',
            'Cannot reveal unsaved or search files.');
      }
    }
  }
}

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
    _tabs.removeAt(index);
    if (_selectedTabIndex.value >= _tabs.length) {
      _selectedTabIndex.value = _tabs.isEmpty ? -1 : _tabs.length - 1;
    }
    _updateCurrentEditorKey();
  }

  void closeTabsToRight(int index) {
    FileTab selectedTab = _tabs[index];
    int selectedTabIndexInTabs = _tabs.indexOf(selectedTab);
    for (int i = _tabs.length - 1; i > selectedTabIndexInTabs; i--) {
      if (!_tabs[i].isPinned) {
        _tabs.removeAt(i);
      }
    }
    if (_selectedTabIndex.value >= _tabs.length) {
      _selectedTabIndex.value = _tabs.length - 1;
    }
    _updateCurrentEditorKey();
  }

  void openFile(File file) {
    int existingTabIndex = _tabs.indexWhere((tab) => tab.filePath == file.path);
    if (existingTabIndex != -1) {
      _selectedTabIndex.value = existingTabIndex;
      _currentEditorKey = EditorContentKey(_tabs[existingTabIndex].content);
    } else {
      String content = file.readAsStringSync();
      _tabs.add(FileTab(filePath: file.path, content: content));
      _selectedTabIndex.value = _tabs.length - 1;
      _currentEditorKey = EditorContentKey(content);
    }
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
        await File(currentTab.filePath)
            .writeAsString(currentTab.content.replaceFirst('\n', ''));
        currentTab.markAsSaved();
      } else {
        await saveFileAs();
      }
    }
  }

  void selectTab(int index) {
    _selectedTabIndex.value = index;
    _currentEditorKey = EditorContentKey(_tabs[index].content);
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
