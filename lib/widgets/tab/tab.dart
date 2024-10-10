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
  final VoidCallback? onSecondaryTap;
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
    this.onSecondaryTap,
    this.onCloseTap,
    required this.isModified,
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
  }) {
    return Tab(
      fullPath: fullPath ?? this.fullPath,
      fullAbsolutePath: fullAbsolutePath ?? this.fullAbsolutePath,
      path: path ?? this.path,
      content: content ?? this.content,
      isSelected: isSelected ?? this.isSelected,
      isModified: isModified ?? this.isModified,
      cursorPosition: cursorPosition ?? this.cursorPosition,
    );
  }
}

class _TabState extends State<Tab> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTap: widget.onSecondaryTap,
        child: Listener(
          onPointerDown: (PointerDownEvent event) {
            if (event.buttons == kMiddleMouseButton) {
              widget.onCloseTap?.call();
            }
          },
          child: CustomTooltip(
            theme: TooltipTheme.light,
            waitDuration: const Duration(milliseconds: 500),
            message: widget.fullAbsolutePath,
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
                            onPressed: widget.onCloseTap,
                            child: Text(
                              "×",
                              style: TextStyle(
                                color: widget.isSelected
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
