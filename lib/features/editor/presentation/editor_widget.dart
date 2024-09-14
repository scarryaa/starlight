import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide TabBar;
import 'package:starlight/features/editor/presentation/editor.dart';
import 'package:starlight/features/file_menu/presentation/file_menu_actions.dart';
import 'package:starlight/features/tabs/presentation/tab.dart';
import 'package:starlight/features/toasts/error_toast.dart';
import 'package:starlight/presentation/screens/search_all_files.dart';
import 'package:starlight/services/keyboard_shortcut_service.dart';

class EditorWidget extends StatefulWidget {
  final KeyboardShortcutService keyboardShortcutService;
  final FileMenuActions fileMenuActions;
  final ValueNotifier<String?> rootDirectory;

  const EditorWidget(
      {super.key,
      required this.fileMenuActions,
      required this.rootDirectory,
      required this.keyboardShortcutService});

  @override
  EditorWidgetState createState() => EditorWidgetState();
}

class EditorWidgetState extends State<EditorWidget> {
  late ErrorToastManager _toastManager;
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
  String _lastSearchTerm = '';

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
    _toastManager = ErrorToastManager(context);
    widget.fileMenuActions.newFile = addEmptyTab;
    widget.fileMenuActions.openFile = openFile;
    widget.fileMenuActions.save = saveCurrentFile;
    widget.fileMenuActions.saveAs = saveFileAs;
  }

  void openFile(File file) {
    try {
      // Check if the file is already open in a tab
      int existingTabIndex =
          _tabs.indexWhere((tab) => tab.filePath == file.path);

      if (existingTabIndex != -1) {
        // If the file is already open, switch to that tab
        setState(() {
          _selectedTabIndex.value = existingTabIndex;
        });
      } else {
        // If the file is not open, create a new tab
        String content = file.readAsStringSync();
        setState(() {
          _tabs.add(FileTab(filePath: file.path, content: content));
          _selectedTabIndex.value = _tabs.length - 1;
        });
      }
    } catch (e) {
      print('Error reading file: $e');
      _toastManager.showErrorToast(file.path, e.toString());
    }
  }

  void saveCurrentFile() {
    if (_selectedTabIndex.value != -1) {
      _saveTab(_selectedTabIndex.value);
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
        setState(() {
          currentTab.filePath = outputFile;
          currentTab.markAsSaved();
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
      key: ValueKey(currentTab.filePath),
      initialCode: currentTab.content,
      filePath: currentTab.filePath,
      onContentChanged: _onCodeEditorContentChanged,
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
      keyboardShortcutService: widget.keyboardShortcutService,
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
                  onPressed: () => setState(() {
                    _isSearchVisible = false;
                    _lastSearchTerm = _searchTerm;

                    _searchTerm = '';
                    _matchPositions = [];
                    _currentMatchIndex = -1;

                    _updateCodeEditorHighlights();
                  }),
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
                  ? Theme.of(context).colorScheme.primary
                  : defaultIconColor,
            ),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;

                if (_isSearchVisible) {
                  // If search bar is becoming visible, restore the last search term if it exists
                  if (_lastSearchTerm.isNotEmpty) {
                    _searchTerm = _lastSearchTerm;
                    _searchController.text = _lastSearchTerm;
                    _selectAllMatches();
                  }
                  // Ensure editor highlights are updated
                  _updateCodeEditorHighlights();
                } else {
                  // If search bar is being closed, save the last search term and clear highlights
                  _lastSearchTerm = _searchTerm;
                  _searchTerm = '';
                  _matchPositions = [];
                  _currentMatchIndex = -1;
                  _updateCodeEditorHighlights();
                }
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
              onTabSaved: _saveTab,
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

  bool _isCurrentTabModified() {
    if (_selectedTabIndex.value != -1) {
      return _tabs[_selectedTabIndex.value].isModified;
    }
    return false;
  }

  bool _isSearchAllFilesTabOpen() {
    return _selectedTabIndex.value != -1 &&
        _tabs[_selectedTabIndex.value].filePath == 'Project Search';
  }

  void _onCodeEditorContentChanged(String newContent) {
    if (_selectedTabIndex.value != -1) {
      final currentTab = _tabs[_selectedTabIndex.value];
      if (currentTab.content != newContent) {
        setState(() {
          currentTab.updateContent(newContent.replaceFirst('\n', ''));
        });
      }
    }
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
        currentTab.updateContent(newContent);
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
        currentTab.updateContent(newContent);
        _updateMatchesAfterReplace();
      });
    }
  }

  Future<void> _saveTab(int index) async {
    if (index >= 0 && index < _tabs.length) {
      final currentTab = _tabs[index];
      if (currentTab.filePath != 'Untitled') {
        await File(currentTab.filePath).writeAsString(currentTab.content);
        setState(() {
          currentTab.markAsSaved();
        });
      } else {
        await saveFileAs();
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

  void _showErrorToast(File file, dynamic error) {
    final overlay = Overlay.of(context);
    OverlayEntry? entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 50,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red[700],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Error',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        entry?.remove();
                      },
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Failed to open file:',
                  style: TextStyle(color: Colors.white),
                ),
                Text(
                  file.path,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // Automatically remove the toast after 6 seconds if not closed manually
    Future.delayed(const Duration(seconds: 6), () {
      entry?.remove();
    });
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
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchTerm = term;
        if (term.isEmpty) {
          _matchPositions = [];
          _currentMatchIndex = -1;
        } else {
          _selectAllMatches();
        }
        _updateCodeEditorHighlights();
      });
    });
  }
}
