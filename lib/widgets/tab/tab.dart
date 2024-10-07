import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class Tab extends StatefulWidget {
  final String path;
  String content;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onCloseTap;

  Tab({
    super.key,
    required this.path,
    required this.content,
    required this.isSelected,
    this.onTap,
    this.onCloseTap,
  });

  @override
  State<Tab> createState() => _TabState();
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
          child: Listener(
            onPointerDown: (PointerDownEvent event) {
              if (event.buttons == kMiddleMouseButton) {
                widget.onCloseTap?.call();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                    right: BorderSide(width: 1, color: Colors.blue[200]!)),
                color: widget.isSelected
                    ? Colors.blue[200]
                    : (_isHovering ? Colors.blue[200] : Colors.blue[50]),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        widget.path,
                        style: const TextStyle(color: Colors.black),
                      )),
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
                              padding:
                                  const WidgetStatePropertyAll(EdgeInsets.zero),
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
        ));
  }
}
