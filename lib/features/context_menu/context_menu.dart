import 'package:flutter/material.dart';

class ContextMenuItem {
  final String label;
  final VoidCallback? onTap;
  final bool isDivider;

  const ContextMenuItem({
    required this.label,
    this.onTap,
    this.isDivider = false,
  });
}

class CommonContextMenu extends StatelessWidget {
  final List<ContextMenuItem> menuItems;
  final RelativeRect position;

  const CommonContextMenu({
    Key? key,
    required this.menuItems,
    required this.position,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.colorScheme.surface;
    final textColor = theme.colorScheme.onSurface;

    return CustomSingleChildLayout(
      delegate: _PopupMenuRouteLayout(position),
      child: Card(
        color: backgroundColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: IntrinsicWidth(
          stepWidth: 56.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 120,
              maxWidth: 250,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: menuItems.map((item) {
                if (item.isDivider) {
                  return Divider(
                      height: 8, thickness: 1, color: theme.dividerColor);
                }
                return InkWell(
                  onTap: item.onTap,
                  hoverColor: theme.hoverColor,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      item.label,
                      style: TextStyle(fontSize: 13, color: textColor),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopupMenuRouteLayout extends SingleChildLayoutDelegate {
  final RelativeRect position;

  _PopupMenuRouteLayout(this.position);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest).deflate(
      const EdgeInsets.all(8.0),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double x = position.left;
    double y = position.top;

    if (x < 0) x = 0;
    if (x + childSize.width > size.width) x = size.width - childSize.width;
    if (y < 0) y = 0;
    if (y + childSize.height > size.height) y = size.height - childSize.height;

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopupMenuRouteLayout oldDelegate) {
    return position != oldDelegate.position;
  }
}

Future<T?> showCommonContextMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<ContextMenuItem> items,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (BuildContext context) {
      return CommonContextMenu(
        position: position,
        menuItems: items,
      );
    },
  );
}

