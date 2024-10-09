import 'package:flutter/material.dart';

class EditorGutter extends StatefulWidget {
  static const double width = 40;
  final double height;
  final double lineHeight;
  final ScrollController editorVerticalScrollController;
  final int lineCount;
  final double editorPadding;
  final double fontSize;
  final String fontFamily;
  final double viewPadding;
  final int currentLine;

  const EditorGutter({
    super.key,
    required this.height,
    required this.lineHeight,
    required this.editorVerticalScrollController,
    required this.lineCount,
    required this.editorPadding,
    required this.viewPadding,
    required this.fontSize,
    required this.fontFamily,
    required this.currentLine,   
    });

  @override
  State<EditorGutter> createState() => _EditorGutterState();
}

class _EditorGutterState extends State<EditorGutter> {
  late ScrollController _gutterScrollController;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _gutterScrollController = ScrollController();
    _setupScrollListeners();
  }

  void _setupScrollListeners() {
    widget.editorVerticalScrollController.addListener(_syncGutterScroll);
    _gutterScrollController.addListener(_syncEditorScroll);
  }

  void _syncEditorScroll() {
    if (!_isScrolling &&
        widget.editorVerticalScrollController.position.maxScrollExtent > 0 &&
        widget.editorVerticalScrollController.offset !=
            _gutterScrollController.offset) {
      _isScrolling = true;
      widget.editorVerticalScrollController
          .jumpTo(_gutterScrollController.offset);
      _isScrolling = false;
    }
  }

  void _syncGutterScroll() {
    if (!_isScrolling &&
        _gutterScrollController.position.maxScrollExtent > 0 &&
        _gutterScrollController.offset !=
            widget.editorVerticalScrollController.offset) {
      _isScrolling = true;
      _gutterScrollController
          .jumpTo(widget.editorVerticalScrollController.offset);
      _isScrolling = false;
    }
  }

  @override
  void didUpdateWidget(EditorGutter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lineCount != widget.lineCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncGutterScroll();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: EditorGutter.width,
      height: widget.height + widget.viewPadding * 2,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.builder(
          controller: _gutterScrollController,
          itemCount: widget.lineCount,
          itemExtent: widget.lineHeight,
          padding: EdgeInsets.only(
            bottom: widget.viewPadding,
          ),
          itemBuilder: (context, index) {
            final isCurrentLine = index == widget.currentLine;
            return Container(
              color: isCurrentLine ? Colors.grey.withOpacity(0.1) : Colors.transparent,
              padding: const EdgeInsets.only(right: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  (index + 1).toString(),
                  style: TextStyle(
                    fontFamily: widget.fontFamily,
                    fontSize: widget.fontSize,
                    height: 1.5,
                    color: isCurrentLine ? Colors.black : Colors.grey,
                    fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.editorVerticalScrollController.removeListener(_syncGutterScroll);
    _gutterScrollController.removeListener(_syncEditorScroll);
    _gutterScrollController.dispose();
    super.dispose();
  }
}
