import 'dart:math';

import 'package:flutter/material.dart' hide VerticalDirection, Tab;
import 'package:provider/provider.dart';
import 'package:starlight/features/editor/editor_hotbar.dart';
import 'package:starlight/features/editor/models/cursor_position.dart';
import 'package:starlight/features/editor/services/editor_scroll_manager.dart';
import 'package:starlight/features/editor/services/editor_selection_manager.dart';
import 'package:starlight/services/caret_position_notifier.dart';
import 'package:starlight/services/config_service.dart';
import 'package:starlight/services/hotkey_service.dart';
import 'package:starlight/widgets/tab/tab.dart' as CustomTab;
import 'package:starlight/services/file_service.dart';
import 'package:starlight/services/tab_service.dart';
import 'package:starlight/features/editor/editor_content.dart';
import 'package:starlight/features/editor/models/rope.dart';
import 'package:starlight/widgets/tab/tab.dart';

class Editor extends StatefulWidget {
  final TabService tabService;
  final FileService fileService;
  final HotkeyService hotkeyService;
  final EditorSelectionManager editorSelectionManager;
  final double lineHeight;
  final String fontFamily;
  final double fontSize;
  final int tabSize;
  final ConfigService configService;

  Editor({
    super.key,
    required this.tabService,
    required this.fileService,
    required this.hotkeyService,
    required this.configService,
    this.lineHeight = 1.5,
    this.fontFamily = "ZedMono Nerd Font",
    this.fontSize = 16,
    this.tabSize = 4,
  }) : editorSelectionManager = EditorSelectionManager(Rope(''));

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> with TickerProviderStateMixin {
  final EditorScrollManager _scrollManager = EditorScrollManager();
  final Map<String, ScrollController> _verticalControllers = {};
  final Map<String, ScrollController> _horizontalControllers = {};
  List<Widget> _editorInstances = [];
  late TabController tabController;
  late CaretPositionNotifier _caretPositionNotifier;
  late EditorContent currentEditorContent;

  // Search-related state
  bool isSearchVisible = false;
  String searchQuery = '';
  String replaceQuery = '';
  int currentMatch = 0;
  int totalMatches = 0;
  List<int> matchPositions = [];
  List<int> selectedMatches = [];
  bool showReplace = false;
  bool matchCase = false;
  bool matchWholeWord = false;
  bool useRegex = false;

  @override
  void initState() {
    super.initState();
    _caretPositionNotifier =
        Provider.of<CaretPositionNotifier>(context, listen: false);
    _caretPositionNotifier.addListener(_handleCaretPositionChange);
    _initScrollControllers();
    tabController = TabController(
      length: widget.tabService.tabs.length,
      vsync: this,
      animationDuration: Duration.zero,
    );
    _updateEditorInstances();
    widget.tabService.addListener(_handleTabsChanged);
  }

  void _initScrollControllers() {
    for (var tab in widget.tabService.tabs) {
      _verticalControllers[tab.path] = ScrollController();
      _horizontalControllers[tab.path] = ScrollController();
    }
  }

  void _handleTabsChanged() {
    if (!mounted) return;

    setState(() {
      // Add controllers for new tabs
      for (var tab in widget.tabService.tabs) {
        if (!_verticalControllers.containsKey(tab.path)) {
          _verticalControllers[tab.path] = ScrollController();
          _horizontalControllers[tab.path] = ScrollController();
        }
      }

      // Remove controllers for closed tabs
      _verticalControllers.removeWhere(
          (key, _) => !widget.tabService.tabs.any((tab) => tab.path == key));
      _horizontalControllers.removeWhere(
          (key, _) => !widget.tabService.tabs.any((tab) => tab.path == key));

      // Recreate TabController
      tabController.dispose();
      tabController = TabController(
        length: widget.tabService.tabs.length,
        vsync: this,
        animationDuration: Duration.zero,
      );

      _updateEditorInstances();

      if (widget.tabService.tabs.isNotEmpty) {
        int newIndex = widget.tabService.currentTabIndexNotifier.value ?? 0;
        if (newIndex != tabController.index) {
          tabController.animateTo(newIndex);
        }
      }
    });
  }

  Widget _buildEditor(Tab tab) {
    currentEditorContent = EditorContent(
      key: GlobalKey<EditorContentState>(),
      searchQuery: searchQuery,
      matchPositions: matchPositions,
      currentMatch: currentMatch,
      isSearchVisible: isSearchVisible,
      selectedMatches: selectedMatches,
      caretPositionNotifier: _caretPositionNotifier,
      editorSelectionManager: widget.editorSelectionManager,
      configService: widget.configService,
      hotkeyService: widget.hotkeyService,
      verticalController: _verticalControllers[tab.path]!,
      horizontalController: _horizontalControllers[tab.path]!,
      scrollManager: _scrollManager,
      tab: tab,
      fileService: widget.fileService,
      tabService: widget.tabService,
      lineHeight: widget.lineHeight,
      fontFamily: widget.fontFamily,
      fontSize: widget.fontSize,
      tabSize: widget.tabSize,
    );

    return currentEditorContent;
  }

  void _updateEditorInstances() {
    _editorInstances =
        widget.tabService.tabs.map((tab) => _buildEditor(tab)).toList();
  }

  void _toggleSearch() {
    setState(() {
      isSearchVisible = !isSearchVisible;
      if (!isSearchVisible) {
        _clearSearch();
      }
      _updateEditorInstances();
    });
  }

  void _closeSearch() {
    _clearSearch();
  }

  void _handleSearchChanged(String query) {
    setState(() {
      searchQuery = query;
      _performSearch();
      _updateEditorInstances();
    });
  }

  void _handleReplaceChanged(String query) {
    setState(() {
      replaceQuery = query;
    });
  }

  void _toggleReplace() {
    setState(() {
      showReplace = !showReplace;
    });
  }

  void _replace() {
    if (widget.tabService.currentTab == null || currentMatch == 0) return;

    setState(() {
      int position = matchPositions[currentMatch - 1];
      String content = widget.tabService.currentTab!.content;

      RegExp regExp = _createSearchRegExp();
      String newContent = content.replaceAllMapped(regExp, (match) {
        if (match.start == position) {
          return replaceQuery;
        }
        return match.group(0)!;
      });

      widget.tabService.updateTabContent(
          widget.tabService.currentTab!.path, newContent,
          isModified: true);

      // Update the EditorContent
      EditorContent editorContent =
          _editorInstances[tabController.index] as EditorContent;
      editorContent.updateContent(newContent);

      // Re-run search to update matches
      _performSearch();
    });
  }

  void _replaceAll() {
    if (widget.tabService.currentTab == null || totalMatches == 0) return;

    setState(() {
      String content = widget.tabService.currentTab!.content;
      RegExp regExp = _createSearchRegExp();
      String newContent = content.replaceAll(regExp, replaceQuery);
      widget.tabService.updateTabContent(
          widget.tabService.currentTab!.path, newContent,
          isModified: true);

      // Update the EditorContent
      EditorContent editorContent =
          _editorInstances[tabController.index] as EditorContent;
      editorContent.updateContent(newContent);

      _performSearch(); // Re-run search to update matches
    });
  }

  void _selectAllMatches() {
    if (widget.tabService.currentTab == null || totalMatches == 0) return;

    setState(() {
      selectedMatches = List.from(matchPositions);
      widget.editorSelectionManager.clearSelection();
      for (int position in matchPositions) {
        widget.editorSelectionManager
            .addToSelection(position, position + searchQuery.length);
      }
      _updateEditorInstances();
    });
  }

  void _nextMatch() {
    if (totalMatches > 0) {
      setState(() {
        currentMatch = (currentMatch % totalMatches) + 1;
        _updateEditorInstances();
      });
      _scrollToCurrentMatch();
    }
  }

  void _previousMatch() {
    if (totalMatches > 0) {
      setState(() {
        currentMatch = (currentMatch - 2 + totalMatches) % totalMatches + 1;
        _updateEditorInstances();
      });
      _scrollToCurrentMatch();
    }
  }

  void _toggleMatchCase(bool value) {
    setState(() {
      matchCase = value;
      _performSearch();
    });
  }

  void _toggleMatchWholeWord(bool value) {
    setState(() {
      matchWholeWord = value;
      _performSearch();
    });
  }

  void _toggleUseRegex(bool value) {
    setState(() {
      useRegex = value;
      _performSearch();
    });
  }

  RegExp _createSearchRegExp() {
    if (useRegex) {
      return RegExp(searchQuery, caseSensitive: matchCase, multiLine: true);
    } else {
      String escapedQuery = RegExp.escape(searchQuery);
      if (matchWholeWord) {
        escapedQuery = '\\b$escapedQuery\\b';
      }
      return RegExp(escapedQuery, caseSensitive: matchCase, multiLine: true);
    }
  }

  void _performSearch() {
    if (widget.tabService.currentTab == null || searchQuery.isEmpty) {
      setState(() {
        totalMatches = 0;
        currentMatch = 0;
        matchPositions.clear();
        selectedMatches.clear();
      });
      return;
    }

    String content = widget.tabService.currentTab!.content;
    RegExp regExp = _createSearchRegExp();
    Iterable<Match> matches = regExp.allMatches(content);

    setState(() {
      matchPositions = matches.map((m) => m.start).toList();
      totalMatches = matchPositions.length;
      currentMatch = totalMatches > 0 ? 1 : 0;
      selectedMatches.clear();
      _updateEditorInstances();
    });

    if (totalMatches > 0) {
      _scrollToCurrentMatch();
    }
  }

  void _scrollToCurrentMatch() {
    if (currentMatch > 0 && currentMatch <= matchPositions.length) {
      int position = matchPositions[currentMatch - 1];
      String content = widget.tabService.currentTab!.content;

      // Calculate line and column of the match
      int line = content.substring(0, position).split('\n').length - 1;
      int column = position - content.lastIndexOf('\n', position) - 1;

      // Calculate scroll offsets
      double verticalScrollOffset =
          line * currentEditorContent.actualLineHeight;
      double horizontalScrollOffset = column * currentEditorContent.charWidth;

      // Get the current scroll controllers
      ScrollController? verticalController =
          _verticalControllers[widget.tabService.currentTab!.path];
      ScrollController? horizontalController =
          _horizontalControllers[widget.tabService.currentTab!.path];

      if (verticalController != null && horizontalController != null) {
        // Ensure we're not scrolling beyond the content
        verticalScrollOffset = min(
            verticalScrollOffset, verticalController.position.maxScrollExtent);
        horizontalScrollOffset = min(horizontalScrollOffset,
            horizontalController.position.maxScrollExtent);

        // Animate to the new vertical position
        verticalController.animateTo(
          verticalScrollOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );

        // Animate to the new horizontal position
        horizontalController.animateTo(
          horizontalScrollOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    } else {
      print('Invalid currentMatch: $currentMatch');
    }
  }

  void _clearSearch() {
    setState(() {
      isSearchVisible = false;
      searchQuery = '';
      replaceQuery = '';
      currentMatch = 0;
      totalMatches = 0;
      matchPositions.clear();
      selectedMatches.clear();
      _updateEditorInstances();
    });
  }

  void _handleCaretPositionChange() {
    if (widget.tabService.currentTab != null) {
      final newPosition = _caretPositionNotifier.position;
      widget.tabService.updateCursorPosition(
        widget.tabService.currentTab!.path,
        CursorPosition(line: newPosition.line, column: newPosition.column),
      );
      // Force a rebuild of the current editor instance
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 35,
          child: ReorderableListView(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                widget.tabService.reorderTabs(oldIndex, newIndex);
                tabController.index =
                    widget.tabService.currentTabIndexNotifier.value ?? 0;
              });
            },
            children: widget.tabService.tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              return ReorderableDragStartListener(
                key: ValueKey(tab.path),
                index: index,
                child: CustomTab.Tab(
                  onCloseRequest: widget.tabService.onCloseRequest,
                  fullAbsolutePath: tab.fullAbsolutePath,
                  fullPath: tab.fullPath,
                  path: tab.path,
                  content: tab.content,
                  isSelected: tab == widget.tabService.currentTab,
                  onCloseTap: () => widget.tabService.removeTab(tab.path),
                  onCloseOthers: () =>
                      widget.tabService.closeOtherTabs(context, index),
                  closeLeft: () => widget.tabService.closeLeft(context, index),
                  closeRight: () =>
                      widget.tabService.closeRight(context, index),
                  onCloseAll: () => widget.tabService.closeAllTabs(context),
                  onTap: () {
                    widget.tabService.setCurrentTab(index);
                  },
                  onCopyPath: () => widget.tabService.copyPath(index),
                  onCopyRelativePath: () =>
                      widget.tabService.copyRelativePath(index),
                  isModified: tab.isModified,
                  isPinned: tab.isPinned,
                  onPinTap: () => widget.tabService.pinTab(index),
                  onUnpinTap: () => widget.tabService.unpinTab(index),
                ),
              );
            }).toList(),
          ),
        ),
        if (widget.tabService.tabs.isNotEmpty)
          EditorHotbar(
            currentTab: widget.tabService.currentTab,
            isSearchVisible: isSearchVisible,
            onSearch: _toggleSearch,
            onCloseSearch: _closeSearch,
            onSearchChanged: _handleSearchChanged,
            onReplaceChanged: _handleReplaceChanged,
            onNextMatch: _nextMatch,
            onPreviousMatch: _previousMatch,
            onReplace: _replace,
            onReplaceAll: _replaceAll,
            onSelectAllMatches: _selectAllMatches,
            currentMatch: currentMatch,
            totalMatches: totalMatches,
            showReplace: showReplace,
            onToggleReplace: _toggleReplace,
            matchCase: matchCase,
            matchWholeWord: matchWholeWord,
            useRegex: useRegex,
            onMatchCaseChanged: _toggleMatchCase,
            onMatchWholeWordChanged: _toggleMatchWholeWord,
            onUseRegexChanged: _toggleUseRegex,
          ),
        Expanded(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: tabController,
            children: _editorInstances,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _caretPositionNotifier.removeListener(_handleCaretPositionChange);
    for (var controller in _verticalControllers.values) {
      controller.dispose();
    }
    for (var controller in _horizontalControllers.values) {
      controller.dispose();
    }
    tabController.dispose();
    widget.tabService.removeListener(_handleTabsChanged);
    super.dispose();
  }
}

class ScrollInfo {
  final double vertical;
  final double horizontal;

  ScrollInfo({required this.vertical, required this.horizontal});
}
