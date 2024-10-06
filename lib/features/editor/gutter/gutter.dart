import 'package:flutter/material.dart';

class EditorGutter extends StatefulWidget {
  double height = 0;
  int lineCount = 0;
  ScrollController gutterScrollController = ScrollController();
  ScrollController editorVerticalScrollController;
  double editorPadding = 0;
  Color? lineNumberColor;

  static double get width => 40;

  EditorGutter(
      {super.key,
      required this.height,
      required this.editorPadding,
      required this.editorVerticalScrollController,
      required this.lineCount,
      this.lineNumberColor = Colors.grey}) {
    gutterScrollController.addListener(
      () {
        if (editorVerticalScrollController.offset !=
            gutterScrollController.offset) {
          editorVerticalScrollController.jumpTo(gutterScrollController.offset);
        }
      },
    );
  }

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
                    width: EditorGutter.width,
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
                                            fontFamily: "Spot Mono",
                                            fontSize: 14,
                                            height: 1.4,
                                            color: widget.lineNumberColor),
                                        (index + 1).toString()));
                              }
                              return null;
                            }))))));
  }
}
