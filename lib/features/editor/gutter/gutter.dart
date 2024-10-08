import 'package:flutter/material.dart';

class EditorGutter extends StatefulWidget {
  static const double width = 40;
  final double height;
  final double lineHeight;
  final ScrollController editorVerticalScrollController;
  final int lineCount;
  final double editorPadding;

  final double viewPadding;

  const EditorGutter({
    super.key,
    required this.height,
    required this.lineHeight,
    required this.editorVerticalScrollController,
    required this.lineCount,
    required this.editorPadding,
    required this.viewPadding,
  });

  @override
  State<EditorGutter> createState() => _EditorGutterState();
}

class _EditorGutterState extends State<EditorGutter> {
  late ScrollController _gutterScrollController;

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
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    (index + 1).toString(),
                    style: const TextStyle(
                      fontFamily: "ZedMono Nerd Font",
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                ),
              );
            },
          ),
        ));
  }

  @override
  void dispose() {
    widget.editorVerticalScrollController.removeListener(_syncGutterScroll);
    _gutterScrollController.removeListener(_syncEditorScroll);
    _gutterScrollController.dispose();
    super.dispose();
  }

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
    if (widget.editorVerticalScrollController.position.maxScrollExtent > 0 &&
        widget.editorVerticalScrollController.offset !=
            _gutterScrollController.offset) {
      widget.editorVerticalScrollController
          .jumpTo(_gutterScrollController.offset);
    }
  }

  void _syncGutterScroll() {
    if (_gutterScrollController.position.maxScrollExtent > 0 &&
        _gutterScrollController.offset !=
            widget.editorVerticalScrollController.offset) {
      _gutterScrollController
          .jumpTo(widget.editorVerticalScrollController.offset);
    }
  }
}
