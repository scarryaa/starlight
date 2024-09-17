import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/context_menu/context_menu.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/features/toasts/message_toast.dart';
import 'package:path/path.dart' as path;

class FileTreeItemWidget extends StatelessWidget {
  final FileTreeItem item;
  final ValueChanged<File> onFileSelected;
  final Function(String) onOpenInTerminal;

  const FileTreeItemWidget({
    Key? key,
    required this.item,
    required this.onFileSelected,
    required this.onOpenInTerminal,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<FileExplorerController>(
      builder: (context, controller, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => controller.toggleDirectoryExpansion(item),
              child: _FileTreeItemContent(
                item: item,
                onTap: () {
                  if (item.isDirectory) {
                    controller.toggleDirectoryExpansion(item);
                  } else if (item.entity is File) {
                    onFileSelected(item.entity as File);
                  }
                },
              ),
            ),
            if (item.isDirectory && item.isExpanded)
              Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: item.children
                      .map((child) => FileTreeItemWidget(
                            key: ValueKey(child.path),
                            item: child,
                            onFileSelected: onFileSelected,
                            onOpenInTerminal: onOpenInTerminal,
                          ))
                      .toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FileTreeItemContent extends StatelessWidget {
  final FileTreeItem item;
  final VoidCallback onTap;

  const _FileTreeItemContent({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(left: 8.0 * (item.level + 1)),
        height: 24,
        child: Row(
          children: [
            _buildIcon(theme),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                item.name,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(ThemeData theme) {
    const double iconSize = 14.0;
    final IconData iconData;
    final Color iconColor;
    if (item.isDirectory) {
      iconData = item.isExpanded ? Icons.folder_open : Icons.folder;
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

extension on FileTreeItem {
  String get name => path.split('/').last;
}
