import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide TooltipTheme;
import 'package:starlight/features/editor/models/cursor_position.dart';
import 'package:starlight/features/tooltip/tooltip.dart';

class Tab extends StatefulWidget {
  final String fullPath;
  final String fullAbsolutePath;
  final String path;
  String content;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onCloseTap;
  final VoidCallback? onCloseOthers;
  final VoidCallback? onCloseAll;
  final VoidCallback? onCopyPath;
  final VoidCallback? onCopyRelativePath;
  final VoidCallback? closeLeft;
  final VoidCallback? closeRight;
  final bool isPinned;
  final VoidCallback? onPinTap;
  final VoidCallback? onUnpinTap;
  bool isModified;
  CursorPosition cursorPosition;

  Tab({
    super.key,
    required this.fullPath,
    required this.fullAbsolutePath,
    required this.path,
    required this.content,
    required this.isSelected,
    this.onTap,
    this.onCloseTap,
    this.onCloseOthers,
    this.onCloseAll,
    this.onCopyPath,
    this.onCopyRelativePath,
    this.closeLeft,
    this.closeRight,
    required this.isModified,
    this.isPinned = false,
    this.onPinTap,
    this.onUnpinTap,
    this.cursorPosition = const CursorPosition(line: 0, column: 0),
  });

  @override
  State<Tab> createState() => _TabState();

  Tab copyWith({
    String? fullPath,
    String? fullAbsolutePath,
    String? path,
    String? content,
    bool? isSelected,
    bool? isModified,
    CursorPosition? cursorPosition,
    bool? isPinned,
  }) {
    return Tab(
      fullPath: fullPath ?? this.fullPath,
      fullAbsolutePath: fullAbsolutePath ?? this.fullAbsolutePath,
      path: path ?? this.path,
      content: content ?? this.content,
      isSelected: isSelected ?? this.isSelected,
      isModified: isModified ?? this.isModified,
      cursorPosition: cursorPosition ?? this.cursorPosition,
      onCloseTap: onCloseTap,
      onCloseOthers: onCloseOthers,
      onCloseAll: onCloseAll,
      onCopyPath: onCopyPath,
      isPinned: isPinned ?? this.isPinned,
      onPinTap: onPinTap,
      onUnpinTap: onUnpinTap,
    );
  }
}

class _TabState extends State<Tab> {
  bool _isHovering = false;

  void _showContextMenu(BuildContext context, TapDownDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(details.localPosition);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        offset.dx + 1,
        offset.dy + 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      constraints: const BoxConstraints(
        minWidth: 120,
        maxWidth: 150,
      ),
      popUpAnimationStyle:
          AnimationStyle(duration: const Duration(milliseconds: 0)),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          value: 'close',
          onTap: widget.onCloseTap,
          child: const Text('Close', style: TextStyle(fontSize: 13)),
        ),
        PopupMenuItem<String>(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          value: 'closeOthers',
          onTap: widget.onCloseOthers,
          child: const Text('Close Others', style: TextStyle(fontSize: 13)),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem<String>(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          value: 'closeLeft',
          onTap: widget.closeLeft,
          child: const Text('Close Left', style: TextStyle(fontSize: 13)),
        ),
        PopupMenuItem<String>(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          value: 'closeRight',
          onTap: widget.closeRight,
          child: const Text('Close Right', style: TextStyle(fontSize: 13)),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem<String>(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          value: 'closeAll',
          onTap: widget.onCloseAll,
          child: const Text('Close All', style: TextStyle(fontSize: 13)),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem<String>(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          value: 'copyPath',
          onTap: widget.onCopyPath,
          child: const Text('Copy Path', style: TextStyle(fontSize: 13)),
        ),
        PopupMenuItem<String>(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          value: 'copyRelativePath',
          onTap: widget.onCopyRelativePath,
          child:
              const Text('Copy Relative Path', style: TextStyle(fontSize: 13)),
        ),
        const PopupMenuDivider(height: 8),
        if (!widget.isPinned)
          PopupMenuItem<String>(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            value: 'pinTab',
            onTap: widget.onPinTap,
            child: const Text('Pin Tab', style: TextStyle(fontSize: 13)),
          ),
        if (widget.isPinned)
          PopupMenuItem<String>(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            value: 'unpinTab',
            onTap: widget.onUnpinTap,
            child: const Text('Unpin Tab', style: TextStyle(fontSize: 13)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (details) => _showContextMenu(context, details),
        child: Listener(
          onPointerDown: (PointerDownEvent event) {
            if (event.buttons == kMiddleMouseButton && !widget.isPinned) {
              widget.onCloseTap?.call();
            }
          },
          child: CustomTooltip(
            theme: TooltipTheme.light,
            waitDuration: const Duration(milliseconds: 500),
            message: widget.fullAbsolutePath,
            textStyle: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(width: 1, color: Colors.blue[200]!),
                ),
                color: widget.isSelected
                    ? Colors.blue[200]
                    : (_isHovering ? Colors.blue[200] : Colors.blue[50]),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: ShapeDecoration(
                      shape: const CircleBorder(),
                      color: widget.isModified
                          ? Colors.blue[700]
                          : Colors.transparent,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      widget.path,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                  SizedBox(
                    width: 20,
                    child: _isHovering
                        ? TextButton(
                            style: ButtonStyle(
                              shape: WidgetStateProperty.all<
                                  RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                              ),
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.zero,
                              ),
                              overlayColor:
                                  WidgetStateProperty.resolveWith<Color?>(
                                (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.hovered)) {
                                    return Colors.black.withOpacity(0.2);
                                  }
                                  return null;
                                },
                              ),
                            ),
                            onPressed: widget.isPinned
                                ? widget.onUnpinTap
                                : (widget.isModified ? null : widget.onPinTap),
                            child: Icon(
                              widget.isPinned ? Icons.push_pin : Icons.close,
                              size: 16,
                              color: Colors.black,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
