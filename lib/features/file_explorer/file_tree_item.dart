import 'dart:io';
import 'package:flutter/material.dart';
import 'package:starlight/utils/constants.dart';

class FileTreeItem extends StatefulWidget {
  final FileSystemEntity entity;
  final Function(File) onFileSelected;
  final int level;
  final bool isInitiallyExpanded;

  const FileTreeItem({
    super.key,
    required this.entity,
    required this.onFileSelected,
    required this.level,
    this.isInitiallyExpanded = false,
  });

  @override
  FileTreeItemState createState() => FileTreeItemState();
}

class FileTreeItemState extends State<FileTreeItem>
    with AutomaticKeepAliveClientMixin {
  late bool _isExpanded;
  List<FileSystemEntity>? _children;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
    if (_isExpanded && widget.entity is Directory) {
      _getChildren();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FileTreeItemContent(
          entity: widget.entity,
          level: widget.level,
          isExpanded: _isExpanded,
          onTap: _handleTap,
        ),
        if (_isExpanded && widget.entity is Directory)
          FutureBuilder<List<FileSystemEntity>>(
            future: _getChildren(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(left: 24.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red));
              }
              return Column(children: _buildChildren(snapshot.data ?? []));
            },
          ),
      ],
    );
  }

  void _handleTap() {
    if (widget.entity is Directory) {
      setState(() => _isExpanded = !_isExpanded);
    } else if (widget.entity is File) {
      widget.onFileSelected(widget.entity as File);
    }
  }

  Future<List<FileSystemEntity>> _getChildren() async {
    if (_children != null) return _children!;
    final directory = widget.entity as Directory;
    final children = await directory.list().toList();
    final directories = children.whereType<Directory>().toList();
    final files = children.whereType<File>().toList();
    directories.sort((a, b) => a.path.compareTo(b.path));
    files.sort((a, b) => a.path.compareTo(b.path));
    _children = [...directories, ...files];
    return _children!;
  }

  List<Widget> _buildChildren(List<FileSystemEntity> children) {
    return children.map((child) {
      return FileTreeItem(
        key: ValueKey(child.path),
        entity: child,
        onFileSelected: widget.onFileSelected,
        level: widget.level + 1,
      );
    }).toList();
  }
}

class _FileTreeItemContent extends StatelessWidget {
  final FileSystemEntity entity;
  final int level;
  final bool isExpanded;
  final VoidCallback onTap;

  const _FileTreeItemContent({
    required this.entity,
    required this.level,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(left: 8.0 * level),
        height: 24,
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                entity.path.split('/').last,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    const iconSize = 14.0;
    if (entity is Directory) {
      return Icon(
        isExpanded ? Icons.folder_open : Icons.folder,
        size: iconSize,
        color: Colors.blue[300],
      );
    } else {
      return Icon(
        Icons.insert_drive_file,
        size: iconSize,
        color: Colors.grey[400],
      );
    }
  }
}
