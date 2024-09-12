import 'package:flutter/material.dart';

class ResizableWidget extends StatefulWidget {
  final Widget child;
  final double initialWidth;
  final double minWidth;
  final double maxWidthPercentage;

  const ResizableWidget({
    super.key,
    required this.child,
    this.initialWidth = 250,
    this.minWidth = 200,
    this.maxWidthPercentage = 0.9,
  });

  @override
  ResizableWidgetState createState() => ResizableWidgetState();
}

class ResizableWidgetState extends State<ResizableWidget> {
  late double _width;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
  }

  void _handleDrag(DragUpdateDetails details) {
    setState(() {
      _width += details.delta.dx;
      double maxWidth =
          MediaQuery.of(context).size.width * widget.maxWidthPercentage;
      _width = _width.clamp(widget.minWidth, maxWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor;
    double maxWidth =
        MediaQuery.of(context).size.width * widget.maxWidthPercentage;
    final dividerWidth = theme.dividerTheme.thickness ?? 1;

    return Row(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.minWidth,
            maxWidth: maxWidth,
          ),
          child: SizedBox(
            width: _width,
            child: widget.child,
          ),
        ),
        GestureDetector(
          onHorizontalDragUpdate: _handleDrag,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: Container(
              width: dividerWidth,
              color: dividerColor,
              child: VerticalDivider(
                width: dividerWidth,
                thickness: dividerWidth,
                color: dividerColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
