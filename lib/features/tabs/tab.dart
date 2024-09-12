import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:io';

class FileTab {
  String filePath;
  String content;
  bool isModified;

  FileTab({
    required this.filePath,
    required this.content,
    this.isModified = false,
  });

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

  const TabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onTabClosed,
  });

  @override
  State<TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<TabBar> {
  late ScrollController _scrollController;

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
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            _scrollController.jumpTo(
              (_scrollController.offset + pointerSignal.scrollDelta.dy)
                  .clamp(0.0, _scrollController.position.maxScrollExtent),
            );
          }
        },
        child: Scrollbar(
            controller: _scrollController,
            thickness: 5,
            radius: const Radius.circular(0),
            child: Center(
                child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: widget.tabs.length,
              itemBuilder: (context, index) => Tab(
                text: widget.tabs[index].fileName,
                isSelected: widget.selectedIndex == index,
                isModified: widget.tabs[index].isModified,
                onTap: () => widget.onTabSelected(index),
                onClose: () => widget.onTabClosed(index),
              ),
            ))),
      ),
    );
  }
}

class Tab extends StatefulWidget {
  final String text;
  final bool isSelected;
  final bool isModified;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const Tab({
    super.key,
    required this.text,
    required this.isSelected,
    required this.isModified,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<Tab> createState() => _TabState();
}

class _TabState extends State<Tab> {
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
        child: Listener(
            onPointerDown: (PointerDownEvent event) {
              if (event.buttons == kMiddleMouseButton) {
                widget.onClose();
              }
            },
            child: Container(
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
                      textAlign: TextAlign.center,
                      widget.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (_isHovered)
                      _CloseButton(
                          onTap: widget.onClose, color: theme.iconTheme.color)
                    else
                      Container(width: 18)
                  ],
                ),
              ),
            )),
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
