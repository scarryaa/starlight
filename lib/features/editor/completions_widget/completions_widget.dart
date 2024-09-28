import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double kCompletionItemHeight = 24.0;

class CompletionItem {
  final String label;
  final String? detail;
  final String? insertText;

  CompletionItem({required this.label, this.detail, this.insertText});

  factory CompletionItem.fromJson(Map<String, dynamic> json) {
    return CompletionItem(
      label: json['label'] as String,
      detail: json['detail'] as String?,
      insertText: json['insertText'] as String? ?? json['label'] as String,
    );
  }
}

class CompletionsWidget extends StatefulWidget {
  final List<CompletionItem> completions;
  final Function(CompletionItem) onSelected;
  final Offset position;
  final FocusNode editorFocusNode;
  final VoidCallback onDismiss;

  const CompletionsWidget({
    super.key,
    required this.completions,
    required this.onSelected,
    required this.position,
    required this.editorFocusNode,
    required this.onDismiss,
  });

  @override
  _CompletionsWidgetState createState() => _CompletionsWidgetState();
}

class _CompletionsWidgetState extends State<CompletionsWidget> {
  int _selectedIndex = 0;
  final FocusNode _listFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _listFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _listFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectPrevious() {
    setState(() {
      _selectedIndex = (_selectedIndex - 1) % widget.completions.length;
    });
    _scrollToSelectedItem();
  }

  void _selectNext() {
    setState(() {
      _selectedIndex = (_selectedIndex + 1) % widget.completions.length;
    });
    _scrollToSelectedItem();
  }

  void _scrollToSelectedItem() {
    final double scrollOffset = _scrollController.offset;
    final double visibleHeight = context.size?.height ?? 0;
    final int visibleItemCount =
        (visibleHeight / kCompletionItemHeight).floor();

    double targetOffset;
    if (_selectedIndex < scrollOffset / kCompletionItemHeight) {
      // Keep the selected item at the top, showing one item above it if possible
      targetOffset = (_selectedIndex - 1) * kCompletionItemHeight;
      targetOffset = targetOffset.clamp(0.0, double.infinity);
    } else if (_selectedIndex < widget.completions.length - 1 &&
        _selectedIndex > visibleItemCount - 2) {
      // Keep only the next item visible at the bottom
      targetOffset =
          (_selectedIndex + 1) * kCompletionItemHeight - visibleHeight;
    } else {
      // No change in scroll position
      return;
    }

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 1),
      curve: Curves.easeInOut,
    );
  }

  void _confirmSelection() {
    widget.onSelected(widget.completions[_selectedIndex]);
    widget.editorFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToSelectedItem());

    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 150,
            maxWidth: 300,
            minWidth: 200,
          ),
          child: Focus(
            focusNode: _listFocusNode,
            onKey: (node, event) {
              if (event is RawKeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _selectPrevious();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _selectNext();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                  _confirmSelection();
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                  widget.onDismiss();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: ListView.builder(
                controller: _scrollController,
                itemCount: widget.completions.length,
                itemExtent: kCompletionItemHeight,
                itemBuilder: (context, index) {
                  final completion = widget.completions[index];
                  final isSelected = index == _selectedIndex;
                  return SizedBox(
                    height: kCompletionItemHeight,
                    child: InkWell(
                      onTap: () => widget.onSelected(completion),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surface,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            completion.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
          ),
        ),
      ),
    );
  }
}
