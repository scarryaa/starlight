import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide TabBar;
import 'package:provider/provider.dart';
import 'package:starlight/features/editor/domain/editor_controller.dart';
import 'package:starlight/features/editor/domain/models/lsp_config.dart';
import 'package:starlight/features/editor/presentation/editor.dart';
import 'package:starlight/features/file_menu/presentation/file_menu_actions.dart';
import 'package:starlight/features/tabs/presentation/tab.dart';
import 'package:starlight/features/toasts/error_toast.dart';
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
  final Map<String, LspConfig> lspConfigs;

  const EditorWidget({
    super.key,
    required this.fileMenuActions,
    required this.rootDirectory,
    required this.keyboardShortcutService,
    required this.lspConfigs,
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
  final _cursorPositionController = StreamController<String>.broadcast();

  Stream<String> get cursorPositionStream => _cursorPositionController.stream;

  void updateCursorPosition(int line, int column) {
    _cursorPositionController.add('Ln $line, Col $column');
  }

  @override
  void initState() {
    super.initState();
    _fileExplorerService = context.read<FileExplorerService>();
    _editorController = EditorController(
      fileExplorerService: _fileExplorerService,
      keyboardShortcutService: widget.keyboardShortcutService,
      onContentChanged: widget.onContentChanged,
    );
    _editorFocusNode = FocusNode();
    _toastManager = ErrorToastManager(context);
    _initializeFileMenuActions();
    Timer.periodic(
        const Duration(seconds: 30), (_) => refreshCurrentFileDiff());
  }

  void refreshCurrentFileDiff() {
    if (_editorController.hasOpenTabs) {
      _editorController.updateGitDiff(_editorController.selectedTabIndex.value);
    }
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
    if (cursorPosition != null) {
      _editorController.updateCursorPosition(cursorPosition);
    }
    if (selectionStart != null && selectionEnd != null) {
      _editorController.updateSelection(selectionStart, selectionEnd);
    }
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

    final String languageId = _getLanguageIdFromFilePath(currentTab.filePath);

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
      languageId: languageId,
      lspConfigs: widget.lspConfigs,
      gitDiff: currentTab.gitDiff,
    );
  }

  String _getLanguageIdFromFilePath(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'dart':
        return 'dart';
      case 'py':
        return 'python';
      case 'js':
        return 'javascript';
      default:
        return 'plaintext';
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
