import 'package:flutter/material.dart';

class EditorGutter extends StatefulWidget {
  double height = 0;
  int lineCount = 0;
  ScrollController gutterScrollController = ScrollController();
  ScrollController editorVerticalScrollController;
  double editorPadding = 0;
  Color? lineNumberColor;

  EditorGutter(
      {super.key,
      required this.height,
      required this.editorPadding,
      required this.editorVerticalScrollController,
      required this.lineCount,
      this.lineNumberColor = Colors.grey});

  @override
  State<StatefulWidget> createState() => _EditorGutterState();
}

class _EditorGutterState extends State<EditorGutter> {
  @override
  void initState() {
    super.initState();

    widget.editorVerticalScrollController.addListener(() {
      if (widget.editorVerticalScrollController.offset !=
          widget.gutterScrollController.offset) {
        widget.gutterScrollController
            .jumpTo(widget.editorVerticalScrollController.offset);
      }
    });

    widget.gutterScrollController.addListener(
      () {
        if (widget.editorVerticalScrollController.offset !=
            widget.gutterScrollController.offset) {
          widget.editorVerticalScrollController
              .jumpTo(widget.gutterScrollController.offset);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: Alignment.topCenter,
        child: ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
                controller: widget.gutterScrollController,
                child: SizedBox(
                    width: 40,
                    height: widget.height,
                    child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            widget.editorPadding, widget.editorPadding, 0, 0),
                        child: ListView.builder(
                            itemCount: widget.lineCount,
                            itemBuilder: (buildContext, index) {
                              if (index < widget.lineCount) {
                                return Center(
                                    child: Text(
                                        style: TextStyle(
                                            height: 1.4,
                                            color: widget.lineNumberColor),
                                        (index + 1).toString()));
                              }
                              return null;
                            }))))));
  }
}
