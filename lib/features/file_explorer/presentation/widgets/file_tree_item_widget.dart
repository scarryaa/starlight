import 'package:flutter/material.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';
import 'package:starlight/features/file_explorer/domain/models/git_status.dart';

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
                style: _getTextStyle(context),
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

  TextStyle _getTextStyle(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium!;
    final brightness = Theme.of(context).brightness;
    Color color;

    switch (item.gitStatus) {
      case GitStatus.modified:
        color = brightness == Brightness.light
            ? const Color(0xFFE6A23C) // Pastel orange for light mode
            : const Color(0xFFE6A23C); // Brighter orange for dark mode
        break;
      case GitStatus.added:
        color = brightness == Brightness.light
            ? const Color(0xFF67C23A) // Pastel green for light mode
            : const Color(0xFF98FB98); // Pale green for dark mode
        break;
      case GitStatus.deleted:
        color = brightness == Brightness.light
            ? const Color(0xFFF56C6C) // Pastel red for light mode
            : const Color(0xFFFF6B6B); // Brighter red for dark mode
        break;
      case GitStatus.renamed:
        color = brightness == Brightness.light
            ? const Color(0xFF409EFF) // Pastel blue for light mode
            : const Color(0xFF87CEFA); // Light sky blue for dark mode
        break;
      case GitStatus.untracked:
        color = brightness == Brightness.light
            ? const Color(0xFF909399) // Pastel grey for light mode
            : const Color(0xFFD3D3D3); // Light grey for dark mode
        break;
      case GitStatus.none:
      default:
        return baseStyle; // Return the default style if there's no git status
    }

    return baseStyle.copyWith(color: color);
  }
}
