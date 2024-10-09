import 'package:flutter/material.dart' hide VerticalDirection;
import 'package:starlight/features/editor/services/editor_scroll_manager.dart';
import 'package:starlight/services/hotkey_service.dart';
import 'package:starlight/widgets/tab/tab.dart' as CustomTab;
import 'package:starlight/services/file_service.dart';
import 'package:starlight/services/tab_service.dart';
import 'package:starlight/features/editor/editor_content.dart';

class Editor extends StatefulWidget {
  final TabService tabService;
  final FileService fileService;
  final HotkeyService hotkeyService;
  final double lineHeight;
  final String fontFamily;
  final double fontSize;
  final int tabSize;

  const Editor({
    super.key,
    required this.tabService,
    required this.fileService,
    required this.hotkeyService,
    this.lineHeight = 1.5,
    this.fontFamily = "ZedMono Nerd Font",
    this.fontSize = 16,
    this.tabSize = 4,
  });

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> with TickerProviderStateMixin {
  final EditorScrollManager _scrollManager = EditorScrollManager();
  late List<ScrollController> _verticalControllers;
  late List<ScrollController> _horizontalControllers;
  List<Widget> _editorInstances = [];
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    _initScrollControllers();
    tabController = TabController(
        length: widget.tabService.tabs.length,
        vsync: this,
        animationDuration: Duration.zero);
    _updateEditorInstances();
    widget.tabService.addListener(_handleTabsChanged);
  }

  void _initScrollControllers() {
    _verticalControllers = List.generate(
      widget.tabService.tabs.length,
      (_) => ScrollController(),
    );
    _horizontalControllers = List.generate(
      widget.tabService.tabs.length,
      (_) => ScrollController(),
    );
  }

  void _handleTabsChanged() {
    setState(() {
      _disposeScrollControllers();
      _initScrollControllers();
      tabController.dispose();
      tabController = TabController(
          length: widget.tabService.tabs.length,
          vsync: this,
          animationDuration: Duration.zero);
      _updateEditorInstances();

      if (widget.tabService.tabs.isNotEmpty) {
        tabController.animateTo(
            widget.tabService.tabs.lastIndexOf(widget.tabService.tabs.last));
      }
    });
  }

  void _updateEditorInstances() {
    _editorInstances = List.generate(
      widget.tabService.tabs.length,
      (index) => _buildEditor(index),
    );
  }

  void _disposeScrollControllers() {
    for (var controller in _verticalControllers) {
      controller.dispose();
    }
    for (var controller in _horizontalControllers) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _disposeScrollControllers();
    tabController.dispose();
    widget.tabService.removeListener(_handleTabsChanged);
    super.dispose();
  }

  Widget _buildEditor(int index) {
    return EditorContent(
      hotkeyService: widget.hotkeyService,
      verticalController: _verticalControllers[index],
      horizontalController: _horizontalControllers[index],
      scrollManager: _scrollManager,
      tab: widget.tabService.tabs[index],
      fileService: widget.fileService,
      tabService: widget.tabService,
      lineHeight: widget.lineHeight,
      fontFamily: widget.fontFamily,
      fontSize: widget.fontSize,
      tabSize: widget.tabSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            height: 35,
            child: ReorderableListView(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  widget.tabService.reorderTabs(oldIndex, newIndex);
                  // Update tabController to reflect the new order
                  tabController.index = widget.tabService.currentTabIndex ?? 0;
                });
              },
              children: widget.tabService.tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final tab = entry.value;
                return ReorderableDragStartListener(
                    key: ValueKey(tab.path),
                    index: index,
                    child: CustomTab.Tab(
                        path: tab.path.split('/').last,
                        content: tab.content,
                        isSelected: tab.isSelected,
                        onTap: () {
                          setState(() {
                            widget.tabService.setCurrentTab(index);
                            tabController.index = index;
                          });
                        },
                        isModified: false,
                        onSecondaryTap: () {},
                        onCloseTap: () {
                          widget.tabService.removeTab(tab.path);
                          if (widget.tabService.currentTabIndex != null) {
                            tabController.index =
                                widget.tabService.currentTabIndex!;
                          }
                        }));
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
      ),
    );
  }
}
