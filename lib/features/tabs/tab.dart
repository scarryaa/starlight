import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

class FileTab {
  static const Uuid _uuid = Uuid();
  final String id;
  String filePath;
  String content;
  bool isModified;

  FileTab({
    required this.filePath,
    required this.content,
    this.isModified = false,
  }) : id = _uuid.v4();

  String get fileName => filePath.split(Platform.pathSeparator).last;

  void updateContent(String newContent) {
    if (content != newContent) {
      content = newContent;
      isModified = true;
    }
  }
}

class TabBar extends StatefulWidget {
  final List<FileTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<int> onTabClosed;
  final void Function(int oldIndex, int newIndex) onTabsReordered;

  const TabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.onTabsReordered,
  });

  @override
  State<TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<TabBar> {
  late ScrollController _scrollController;
  final Map<String, GlobalKey> _tabKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent pointerSignal) {
    if (pointerSignal is PointerScrollEvent) {
      // Check if Shift key is pressed
      bool isShiftPressed = RawKeyboard.instance.keysPressed.any((key) =>
          key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight);

      if (isShiftPressed) {
        // Switch tabs instead of scrolling
        if (pointerSignal.scrollDelta.dy > 0) {
          // Scroll down, move to the next tab
          int newIndex = (widget.selectedIndex + 1) % widget.tabs.length;
          widget.onTabSelected(newIndex);
        } else if (pointerSignal.scrollDelta.dy < 0) {
          // Scroll up, move to the previous tab
          int newIndex = (widget.selectedIndex - 1 + widget.tabs.length) %
              widget.tabs.length;
          widget.onTabSelected(newIndex);
        }
        // Ensure the selected tab is visible
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureSelectedTabVisible();
        });
      } else {
        // Scroll the TabBar horizontally
        _scrollController.jumpTo(
          (_scrollController.offset + pointerSignal.scrollDelta.dy).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
    }
  }

  void _ensureSelectedTabVisible() {
    final tabId = widget.tabs[widget.selectedIndex].id;
    final tabKey = _tabKeys[tabId];
    if (tabKey != null && tabKey.currentContext != null) {
      RenderBox tabRenderBox =
          tabKey.currentContext!.findRenderObject() as RenderBox;
      RenderBox listViewRenderBox = context.findRenderObject() as RenderBox;

      final tabPosition =
          tabRenderBox.localToGlobal(Offset.zero, ancestor: listViewRenderBox);
      final tabLeft = tabPosition.dx;
      final tabRight = tabLeft + tabRenderBox.size.width;

      final scrollOffset = _scrollController.offset;
      final viewportWidth = _scrollController.position.viewportDimension;

      if (tabLeft < scrollOffset) {
        // Tab is to the left of the viewport, scroll to it
        _scrollController.animateTo(
          tabLeft,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      } else if (tabRight > scrollOffset + viewportWidth) {
        // Tab is to the right of the viewport, scroll to it
        _scrollController.animateTo(
          tabRight - viewportWidth,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollNotification) {
            bool isShiftPressed = RawKeyboard.instance.keysPressed.any((key) =>
                key == LogicalKeyboardKey.shiftLeft ||
                key == LogicalKeyboardKey.shiftRight);
            if (isShiftPressed) {
              // Prevent the scroll
              return true;
            }
            return false;
          },
          child: Scrollbar(
            controller: _scrollController,
            thickness: 5,
            radius: const Radius.circular(0),
            child: ReorderableListView(
              physics: const ClampingScrollPhysics(),
              scrollController: _scrollController,
              scrollDirection: Axis.horizontal,
              onReorder: widget.onTabsReordered,
              buildDefaultDragHandles: false,
              children: [
                for (int index = 0; index < widget.tabs.length; index++)
                  KeyedSubtree(
                    key: ValueKey(widget.tabs[index].id),
                    child: Tab(
                      tabKey: _tabKeys.putIfAbsent(
                          widget.tabs[index].id, () => GlobalKey()),
                      index: index,
                      text: widget.tabs[index].fileName,
                      isSelected: widget.selectedIndex == index,
                      isModified: widget.tabs[index].isModified,
                      onTap: () => widget.onTabSelected(index),
                      onClose: () => widget.onTabClosed(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Tab extends StatefulWidget {
  final int index;
  final String text;
  final bool isSelected;
  final bool isModified;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final GlobalKey tabKey;

  const Tab({
    Key? key,
    required this.tabKey,
    required this.index,
    required this.text,
    required this.isSelected,
    required this.isModified,
    required this.onTap,
    required this.onClose,
  }) : super(key: key);

  @override
  State<Tab> createState() => _TabState();
}

class _TabState extends State<Tab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReorderableDragStartListener(
      index: widget.index,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Listener(
            onPointerDown: (PointerDownEvent event) {
              if (event.buttons == kMiddleMouseButton) {
                widget.onClose();
              }
            },
            child: Container(
              key: widget.tabKey,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : Colors.transparent,
                border: Border(
                  right: BorderSide(color: theme.dividerColor, width: 2),
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      child: widget.isModified
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.text,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (_isHovered)
                      _CloseButton(
                        onTap: widget.onClose,
                        color: theme.iconTheme.color,
                      )
                    else
                      Container(width: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color? color;

  const _CloseButton({required this.onTap, this.color});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: _isHovered ? theme.hoverColor : Colors.transparent,
            shape: BoxShape.rectangle,
          ),
          child: Icon(
            Icons.close,
            size: 14,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
