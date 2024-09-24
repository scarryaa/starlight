import 'package:flutter/material.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';

class FileTreeItemWidget extends StatelessWidget {
  final FileTreeItem item;
  final bool isSelected;
  final Function(FileTreeItem) onItemSelected;
  final VoidCallback onItemLongPress;
  final Function(TapUpDetails) onSecondaryTap;

  const FileTreeItemWidget({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onItemSelected,
    required this.onItemLongPress,
    required this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onItemSelected(item),
      onLongPress: onItemLongPress,
      onSecondaryTapUp: onSecondaryTap,
      child: Container(
        height: 24,
        padding: EdgeInsets.only(left: 8.0 * item.level),
        color: isSelected
            ? Theme.of(context).colorScheme.secondary.withOpacity(0.4)
            : Colors.transparent,
        child: Row(
          children: [
            _buildIcon(context),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                item.name,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final iconColor = Theme.of(context).iconTheme.color ?? Colors.grey;
    if (item.isDirectory) {
      return Icon(
        item.isExpanded ? Icons.folder_open : Icons.folder,
        size: 16,
        color: iconColor,
      );
    } else {
      return _getFileIcon(iconColor);
    }
  }

  Widget _getFileIcon(Color color) {
    final extension = item.name.split('.').last.toLowerCase();
    switch (extension) {
      case 'dart':
      case 'py':
      case 'js':
      case 'css':
        return Icon(Icons.code, size: 16, color: color);
      case 'html':
        return Icon(Icons.html, size: 16, color: color);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icon(Icons.image, size: 16, color: color);
      case 'pdf':
        return Icon(Icons.picture_as_pdf, size: 16, color: color);
      case 'doc':
      case 'docx':
        return Icon(Icons.description, size: 16, color: color);
      case 'xls':
      case 'xlsx':
        return Icon(Icons.table_chart, size: 16, color: color);
      case 'ppt':
      case 'pptx':
        return Icon(Icons.slideshow, size: 16, color: color);
      default:
        return Icon(Icons.insert_drive_file, size: 16, color: color);
    }
  }
}
