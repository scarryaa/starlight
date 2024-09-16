import 'package:flutter/material.dart';

class ResizableWidget extends StatefulWidget {
  final Widget child;
  final double initialSize;
  final double minSize;
  final double maxSizePercentage;
  final bool isHorizontal;

  const ResizableWidget({
    super.key,
    required this.child,
    this.initialSize = 250,
    this.minSize = 200,
    this.maxSizePercentage = 0.9,
    this.isHorizontal = true,
  });

  @override
  ResizableWidgetState createState() => ResizableWidgetState();
}

class ResizableWidgetState extends State<ResizableWidget> {
  late double _size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor;
    final dividerThickness = theme.dividerTheme.thickness ?? 1;

    return widget.isHorizontal
        ? _buildHorizontal(context, dividerColor, dividerThickness)
        : _buildVertical(context, dividerColor, dividerThickness);
  }

  @override
  void initState() {
    super.initState();
    _size = widget.initialSize;
  }

  Widget _buildHorizontal(
      BuildContext context, Color dividerColor, double dividerThickness) {
    double maxSize =
        MediaQuery.of(context).size.width * widget.maxSizePercentage;
    return Row(
      children: [
        ConstrainedBox(
          constraints:
              BoxConstraints(minWidth: widget.minSize, maxWidth: maxSize),
          child: SizedBox(width: _size, child: widget.child),
        ),
        GestureDetector(
          onHorizontalDragUpdate: _handleDrag,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: Container(
              width: dividerThickness,
              color: dividerColor,
              child: VerticalDivider(
                  width: dividerThickness,
                  thickness: dividerThickness,
                  color: dividerColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVertical(
      BuildContext context, Color dividerColor, double dividerThickness) {
    double maxSize =
        MediaQuery.of(context).size.height * widget.maxSizePercentage;
    return Column(
      children: [
        ConstrainedBox(
          constraints:
              BoxConstraints(minHeight: widget.minSize, maxHeight: maxSize),
          child: SizedBox(height: _size, child: widget.child),
        ),
        GestureDetector(
          onVerticalDragUpdate: _handleDrag,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: Container(
              height: dividerThickness,
              color: dividerColor,
              child: Divider(
                  height: dividerThickness,
                  thickness: dividerThickness,
                  color: dividerColor),
            ),
          ),
        ),
      ],
    );
  }

  void _handleDrag(DragUpdateDetails details) {
    setState(() {
      _size += widget.isHorizontal ? details.delta.dx : details.delta.dy;
      double maxSize = widget.isHorizontal
          ? MediaQuery.of(context).size.width * widget.maxSizePercentage
          : MediaQuery.of(context).size.height * widget.maxSizePercentage;
      _size = _size.clamp(widget.minSize, maxSize);
    });
  }
}
