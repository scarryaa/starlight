import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/services/theme_manager.dart';

class EditorGutter extends StatefulWidget {
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
  late double _gutterWidth;

  @override
  void initState() {
    super.initState();
    _gutterScrollController = ScrollController();
    _setupScrollListeners();
    _calculateWidth();
  }

  void _setupScrollListeners() {
    widget.editorVerticalScrollController.addListener(_syncGutterScroll);
    _gutterScrollController.addListener(_syncEditorScroll);
  }

  void _syncEditorScroll() {
    if (!_isScrolling &&
        widget.editorVerticalScrollController.hasClients &&
        widget.editorVerticalScrollController.position.maxScrollExtent > 0) {
      _isScrolling = true;
      widget.editorVerticalScrollController
          .jumpTo(_gutterScrollController.offset);
      _isScrolling = false;
    }
  }

  void _syncGutterScroll() {
    if (!_isScrolling &&
        _gutterScrollController.hasClients &&
        _gutterScrollController.position.maxScrollExtent > 0) {
      _isScrolling = true;
      _gutterScrollController
          .jumpTo(widget.editorVerticalScrollController.offset);
      _isScrolling = false;
    }
  }

  void _calculateWidth() {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: widget.lineCount.toString(),
        style: TextStyle(
          fontFamily: widget.fontFamily,
          fontSize: widget.fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    setState(() {
      _gutterWidth = textPainter.width + 35;
    });
  }

  @override
  void didUpdateWidget(EditorGutter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lineCount != widget.lineCount ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.fontFamily != widget.fontFamily) {
      _calculateWidth();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncGutterScroll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final theme = Theme.of(context);
    final isDarkMode = themeManager.themeMode == ThemeMode.dark ||
        (themeManager.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final regularTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final currentLineTextColor = theme.colorScheme.primary;
    final currentLineBackgroundColor =
        theme.colorScheme.primary.withOpacity(0.1);

    return SizedBox(
      width: _gutterWidth,
      height: widget.height + widget.viewPadding * 2,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.builder(
          controller: _gutterScrollController,
          itemCount: widget.lineCount,
          itemExtent: widget.lineHeight,
          padding: EdgeInsets.only(
            bottom: widget.viewPadding - 35,
          ),
          itemBuilder: (context, index) {
            final isCurrentLine = index == widget.currentLine;
            return Container(
              color: isCurrentLine
                  ? currentLineBackgroundColor
                  : Colors.transparent,
              padding: const EdgeInsets.only(right: 8.0),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  (index + 1).toString(),
                  style: TextStyle(
                    fontFamily: widget.fontFamily,
                    fontSize: widget.fontSize,
                    height: 1.5,
                    color:
                        isCurrentLine ? currentLineTextColor : regularTextColor,
                    fontWeight:
                        isCurrentLine ? FontWeight.bold : FontWeight.normal,
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
