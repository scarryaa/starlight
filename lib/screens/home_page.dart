import 'dart:async';
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
import 'package:starlight/features/tabs/tab.dart';
import 'package:starlight/screens/search_all_files.dart';
import 'package:starlight/themes/theme_provider.dart';
import 'package:starlight/utils/widgets/resizable_widget.dart';
import 'package:window_manager/window_manager.dart';

class EditorWidget extends StatefulWidget {
  final FileMenuActions fileMenuActions;
  final ValueNotifier<String?> rootDirectory;

  const EditorWidget({
    super.key,
    required this.fileMenuActions,
    required this.rootDirectory,
  });

  @override
  _EditorWidgetState createState() => _EditorWidgetState();
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _EditorWidgetState extends State<EditorWidget> {
  final List<FileTab> _tabs = [];
  final ValueNotifier<int> _selectedTabIndex = ValueNotifier<int>(-1);
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isReplaceVisible = false;
  final TextEditingController _replaceController = TextEditingController();
  String _searchTerm = '';
  String _replaceTerm = '';
  List<int> _matchPositions = [];
  int _currentMatchIndex = -1;
  Timer? _debounceTimer;
  bool _matchCase = false;
  bool _matchWholeWord = false;
  bool _useRegex = false;

  void addEmptyTab() {
    setState(() {
      _tabs.add(FileTab(filePath: 'Untitled', content: ''));
      _selectedTabIndex.value = _tabs.length - 1;
    });
  }

  addSearchAllFilesTab() {
    setState(() {
      _tabs.add(FileTab(
        filePath: 'Project Search',
        content: '',
        customWidget: SearchAllFilesTab(
          rootDirectory: widget.rootDirectory.value ?? '',
          onFileSelected: openFile,
        ),
      ));
      _selectedTabIndex.value = _tabs.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _selectedTabIndex,
      builder: (context, selectedIndex, _) {
        final bool isSearchAllFilesTabOpen = _isSearchAllFilesTabOpen();
        return Column(
          children: [
            _buildTabBar(),
            if (_tabs.isNotEmpty && !isSearchAllFilesTabOpen)
              _buildSearchToggleButton(),
            if (_isSearchVisible &&
                _tabs.isNotEmpty &&
                !isSearchAllFilesTabOpen)
              _buildCompactSearchBar(),
            Expanded(child: _buildEditor()),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.fileMenuActions.newFile = addEmptyTab;
    widget.fileMenuActions.openFile = openFile;
    widget.fileMenuActions.save = saveCurrentFile;
    widget.fileMenuActions.saveAs = saveFileAs;
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

  Widget _buildCodeEditor(int selectedIndex) {
    final currentTab = _tabs[selectedIndex];
    if (currentTab.customWidget != null) {
      return currentTab.customWidget!;
    }

    return CodeEditor(
      key: ValueKey(currentTab.content),
      initialCode: currentTab.content,
      filePath: currentTab.filePath,
      onModified: (isModified) => _onFileModified(selectedIndex, isModified),
      matchPositions: _matchPositions,
      searchTerm: _searchTerm,
      currentMatchIndex: _currentMatchIndex,
      onSelectPreviousMatch: _selectPreviousMatch,
      onSelectNextMatch: _selectNextMatch,
      onReplace: _replaceNext,
      onReplaceAll: _replaceAll,
      onUpdateSearchTerm: _updateSearchTerm,
      onUpdateReplaceTerm: _updateReplaceTerm,
      selectionStart: currentTab.selectionStart,
      selectionEnd: currentTab.selectionEnd,
      cursorPosition: currentTab.cursorPosition,
    );
  }

  Widget _buildCompactSearchBar() {
    if (_isSearchAllFilesTabOpen()) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final Color defaultTextColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: _isReplaceVisible
            ? null
            : Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      color: _matchPositions.isEmpty && _searchTerm.isNotEmpty
                          ? Colors.red
                          : Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.white, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildToggleButton('Aa', _matchCase, () {
                            setState(() {
                              _matchCase = !_matchCase;
                              _updateSearchTerm(_searchTerm);
                            });
                          }, 'Match case'),
                          _buildToggleButton('W', _matchWholeWord, () {
                            setState(() {
                              _matchWholeWord = !_matchWholeWord;
                              _updateSearchTerm(_searchTerm);
                            });
                          }, 'Match whole word'),
                          _buildToggleButton('.*', _useRegex, () {
                            setState(() {
                              _useRegex = !_useRegex;
                              _updateSearchTerm(_searchTerm);
                            });
                          }, 'Use regular expression'),
                        ],
                      ),
                    ),
                    onChanged: _updateSearchTerm,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.find_replace,
                    color: _isReplaceVisible
                        ? theme.colorScheme.primary
                        : defaultTextColor,
                  ),
                  onPressed: () =>
                      setState(() => _isReplaceVisible = !_isReplaceVisible),
                  tooltip: _isReplaceVisible ? 'Hide replace' : 'Show replace',
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: Colors.white, size: 20),
                  onPressed: _selectPreviousMatch,
                  tooltip: 'Previous match',
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: Colors.white, size: 20),
                  onPressed: _selectNextMatch,
                  tooltip: 'Next match',
                ),
                _buildMatchCountDisplay(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => setState(() => _isSearchVisible = false),
                  tooltip: 'Close search',
                ),
              ],
            ),
          ),
          if (_isReplaceVisible)
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replaceController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Replace...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.find_replace,
                            color: Colors.white, size: 20),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: _updateReplaceTerm,
                    ),
                  ),
                  TextButton(
                    onPressed: _replaceNext,
                    child: const Text('Replace',
                        style: TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: _replaceAll,
                    child: const Text('Replace All',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentFilePath() {
    if (_selectedTabIndex.value == -1 || _tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentTab = _tabs[_selectedTabIndex.value];
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
    // Remove the leading slash if it exists
    if (relativeFilePath.startsWith('/')) {
      relativeFilePath = relativeFilePath.substring(1);
    }

    return Text(
      relativeFilePath,
      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
      overflow: TextOverflow.ellipsis,
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

  Widget _buildMatchCountDisplay() {
    return Container(
      width: 60,
      alignment: Alignment.center,
      child: Text(
        '${_currentMatchIndex + 1}/${_matchPositions.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSearchToggleButton() {
    if (_isSearchAllFilesTabOpen()) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final Color defaultIconColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: _isSearchVisible
            ? null
            : Border(
                bottom: BorderSide(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCurrentFilePath(),
          ),
          IconButton(
            icon: Icon(
              Icons.search,
              color: _isSearchVisible
                  ? theme.colorScheme.primary
                  : defaultIconColor,
            ),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
              });
            },
            tooltip: _isSearchVisible ? 'Close Search' : 'Open Search',
          ),
        ],
      ),
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
              onCloseOtherTabs: _closeOtherTabs,
              onCloseAllTabs: _closeAllTabs,
              onCloseTabsToRight: _closeTabsToRight,
            ),
          );
        } else {
          return Container();
        }
      },
    );
  }

  Widget _buildToggleButton(
      String label, bool isActive, VoidCallback onPressed, String tooltip) {
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
              color: isActive ? Colors.white : Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ),
      ),
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

  void _closeAllTabs() {
    setState(() {
      _tabs.clear();
      _selectedTabIndex.value = -1;
    });
  }

  void _closeOtherTabs(int index) {
    setState(() {
      final currentTab = _tabs[index];
      _tabs.clear();
      _tabs.add(currentTab);
      _selectedTabIndex.value = 0;
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

  void _closeTabsToRight(int index) {
    setState(() {
      // Get the selected tab
      FileTab selectedTab = _tabs[index];

      // Find the index of the selected tab in the sorted _tabs list
      int selectedTabIndexInTabs = _tabs.indexOf(selectedTab);

      // Remove unpinned tabs to the right of the selected tab
      for (int i = _tabs.length - 1; i > selectedTabIndexInTabs; i--) {
        if (!_tabs[i].isPinned) {
          _tabs.removeAt(i);
        }
      }

      // Adjust the selected index if necessary
      if (_selectedTabIndex.value >= _tabs.length) {
        _selectedTabIndex.value = _tabs.length - 1;
      }
    });
  }

  List<int> _findAllOccurrences(String text, String searchTerm) {
    List<int> positions = [];
    if (_useRegex) {
      try {
        RegExp regExp = RegExp(
          searchTerm,
          caseSensitive: _matchCase,
          multiLine: true,
        );
        for (Match match in regExp.allMatches(text)) {
          positions.add(match.start);
        }
      } catch (e) {
        // Handle invalid regex
        print('Invalid regex: $e');
      }
    } else {
      String pattern =
          _matchWholeWord ? r'\b' + searchTerm + r'\b' : searchTerm;
      RegExp regExp = RegExp(
        pattern,
        caseSensitive: _matchCase,
        multiLine: true,
      );
      for (Match match in regExp.allMatches(text)) {
        positions.add(match.start);
      }
    }
    return positions;
  }

  bool _isSearchAllFilesTabOpen() {
    return _selectedTabIndex.value != -1 &&
        _tabs[_selectedTabIndex.value].filePath == 'Project Search';
  }

  void _onFileModified(int index, bool isModified) {
    _tabs[index].isModified = isModified;
  }

  void _onTabsReordered(int oldIndex, int newIndex) {
    setState(() {
      if (_tabs[oldIndex].isPinned != _tabs[newIndex].isPinned) {
        // Prevent moving between pinned and unpinned tabs
        return;
      }
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final FileTab movedTab = _tabs.removeAt(oldIndex);
      _tabs.insert(newIndex, movedTab);

      // Update selected index if necessary
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

  void _replaceAll() {
    if (_matchPositions.isNotEmpty) {
      final currentTab = _tabs[_selectedTabIndex.value];
      setState(() {
        String newContent = currentTab.content;
        for (int i = _matchPositions.length - 1; i >= 0; i--) {
          int start = _matchPositions[i];
          newContent = newContent.replaceRange(
              start, start + _searchTerm.length, _replaceTerm);
        }
        currentTab.content = newContent;
        _updateMatchesAfterReplace();
      });
    }
  }

  void _replaceNext() {
    if (_matchPositions.isNotEmpty && _currentMatchIndex != -1) {
      final currentTab = _tabs[_selectedTabIndex.value];
      setState(() {
        int start = _matchPositions[_currentMatchIndex];
        String newContent = currentTab.content
            .replaceRange(start, start + _searchTerm.length, _replaceTerm);
        currentTab.content = newContent;
        _updateMatchesAfterReplace();
      });
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

  void _selectNextMatch() {
    if (_matchPositions.isNotEmpty) {
      setState(() {
        _currentMatchIndex = (_currentMatchIndex + 1) % _matchPositions.length;
        _updateCodeEditorSelection(true);
      });
    }
  }

  void _selectPreviousMatch() {
    if (_matchPositions.isNotEmpty) {
      setState(() {
        _currentMatchIndex = (_currentMatchIndex - 1 + _matchPositions.length) %
            _matchPositions.length;
        _updateCodeEditorSelection(true);
      });
    }
  }

  void _selectTab(int index) {
    _selectedTabIndex.value = index;
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

  void _updateCodeEditorHighlights() {
    // Only update if there's an active tab
    if (_selectedTabIndex.value != -1) {
      setState(() {});
    }
  }

  void _updateCodeEditorSelection(bool moveCursorToEnd) {
    if (_matchPositions.isNotEmpty && _currentMatchIndex != -1) {
      int start = _matchPositions[_currentMatchIndex];
      int end = start + _searchTerm.length;
      setState(() {
        if (_selectedTabIndex.value != -1) {
          final currentTab = _tabs[_selectedTabIndex.value];
          currentTab.selectionStart = start + 1;
          currentTab.selectionEnd = end + 1;
          currentTab.cursorPosition = moveCursorToEnd ? end : start;
        }
      });
    }
  }

  void _updateMatchesAfterReplace() {
    _selectAllMatches();
    _updateCodeEditorHighlights();
  }

  void _updateReplaceTerm(String term) {
    setState(() {
      _replaceTerm = term;
    });
  }

  void _updateSearchTerm(String term) {
    setState(() {
      _searchTerm = term;
      if (term.isEmpty) {
        _matchPositions = [];
        _currentMatchIndex = -1;
      } else {
        _selectAllMatches();
      }
    });
    _updateCodeEditorHighlights();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  late final FileExplorerController _fileExplorerController;
  late final FileMenuActions _fileMenuActions;
  final ValueNotifier<String?> _selectedDirectory =
      ValueNotifier<String?>(null);
  final GlobalKey<_EditorWidgetState> _editorKey =
      GlobalKey<_EditorWidgetState>();

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
                  child: RepaintBoundary(
                    child: FileExplorerWidget(
                      onFileSelected: _handleOpenFile,
                      onDirectorySelected: _handleDirectorySelected,
                      controller: _fileExplorerController,
                    ),
                  ),
                ),
                Expanded(
                  child: EditorWidget(
                    key: _editorKey,
                    fileMenuActions: _fileMenuActions,
                    rootDirectory: _selectedDirectory,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusBar()
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeKeyboardShortcuts();
    _fileExplorerController = FileExplorerController();
    _fileMenuActions = FileMenuActions(
      newFile: _handleNewFile,
      openFile: _handleOpenFile,
      save: _handleSaveCurrentFile,
      saveAs: _handleSaveFileAs,
      exit: _handleExit,
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

  void _handleExit(BuildContext context) {
    SystemNavigator.pop();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      bool isCommandOrControlPressed = Platform.isMacOS
          ? HardwareKeyboard.instance.isMetaPressed
          : HardwareKeyboard.instance.isControlPressed;

      if (isCommandOrControlPressed &&
          HardwareKeyboard.instance.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyF) {
        _editorKey.currentState?.addSearchAllFilesTab();
        return true;
      }
    }
    return false;
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

  void _initializeKeyboardShortcuts() {
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  Future<void> _pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      _handleDirectorySelected(selectedDirectory);
    }
  }
}
