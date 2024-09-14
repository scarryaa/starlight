import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';

class FileTreeItemWidget extends StatelessWidget {
  final FileTreeItem item;
  final Function(File) onFileSelected;

  const FileTreeItemWidget({
    super.key,
    required this.item,
    required this.onFileSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _FileTreeItemContent(
      item: item,
      onTap: () => _handleTap(context),
    );
  }

  void _handleTap(BuildContext context) {
    final controller =
        Provider.of<FileExplorerController>(context, listen: false);
    if (item.isDirectory) {
      controller.toggleDirectoryExpansion(item);
    } else if (item.entity is File) {
      onFileSelected(item.entity as File);
    }
  }
}

class _FileTreeItemContent extends StatefulWidget {
  final FileTreeItem item;
  final VoidCallback onTap;

  const _FileTreeItemContent({
    required this.item,
    required this.onTap,
  });

  @override
  _FileTreeItemContentState createState() => _FileTreeItemContentState();
}

class _FileTreeItemContentState extends State<_FileTreeItemContent> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.only(left: 8.0 * (widget.item.level + 1)),
          height: 24,
          color: _isHovering ? theme.hoverColor : Colors.transparent,
          child: Row(
            children: [
              _buildIcon(theme),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.item.path.split('/').last,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ThemeData theme) {
    const iconSize = 14.0;
    if (widget.item.isDirectory) {
      return Icon(
        widget.item.isExpanded ? Icons.folder_open : Icons.folder,
        size: iconSize,
        color: theme.colorScheme.primary,
      );
    } else {
      return Icon(
        Icons.insert_drive_file,
        size: iconSize,
        color: theme.iconTheme.color?.withOpacity(0.7),
      );
    }
  }
}
