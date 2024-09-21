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
            if (item.isDirectory)
              Icon(
                item.isExpanded ? Icons.folder_open : Icons.folder,
                size: 16,
              )
            else
              const Icon(Icons.insert_drive_file, size: 16),
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
}
