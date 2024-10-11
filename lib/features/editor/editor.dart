import 'package:flutter/material.dart' hide VerticalDirection, Tab;
import 'package:provider/provider.dart';
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
    return EditorContent(
      caretPositionNotifier: _caretPositionNotifier,
      key: ValueKey(tab.path),
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
  }

  void _updateEditorInstances() {
    _editorInstances =
        widget.tabService.tabs.map((tab) => _buildEditor(tab)).toList();
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
