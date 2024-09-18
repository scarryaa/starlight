import 'package:flutter/material.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';

class FileTreeItemWidget extends StatefulWidget {
  final FileTreeItem item;
  final bool isSelected;
  final ValueChanged<FileTreeItem> onItemSelected;
  final VoidCallback onLongPress;

  const FileTreeItemWidget({
    Key? key,
    required this.item,
    required this.isSelected,
    required this.onItemSelected,
    required this.onLongPress,
  }) : super(key: key);

  @override
  _FileTreeItemWidgetState createState() => _FileTreeItemWidgetState();
}

class _FileTreeItemWidgetState extends State<FileTreeItemWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateRenderBox();
      }
    });
  }

  @override
  void didUpdateWidget(FileTreeItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateRenderBox();
      }
    });
  }

  void _updateRenderBox() {
    if (!mounted) return;
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      widget.item.setRenderBox(renderBox);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onItemSelected(widget.item),
      onLongPress: widget.onLongPress,
      child: Container(
        color: widget.isSelected
            ? Theme.of(context).colorScheme.secondary.withOpacity(0.3)
            : null,
        padding: EdgeInsets.only(left: 16.0 * widget.item.level),
        height: 24,
        child: Row(
          children: [
            _buildIcon(context),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.item.name,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final theme = Theme.of(context);
    const double iconSize = 16.0;
    final IconData iconData;
    final Color iconColor;

    if (widget.item.isDirectory) {
      iconData = widget.item.isExpanded ? Icons.folder_open : Icons.folder;
      iconColor = theme.colorScheme.primary;
    } else {
      iconData = Icons.insert_drive_file;
      iconColor = theme.iconTheme.color?.withOpacity(0.7) ?? Colors.grey;
    }

    return Icon(
      iconData,
      size: iconSize,
      color: iconColor,
    );
  }
}
