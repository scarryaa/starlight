import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/context_menu/context_menu.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/features/toasts/message_toast.dart';
import 'package:path/path.dart' as path;

class FileTreeItemWidget extends StatefulWidget {
  final FileTreeItem item;
  final ValueChanged<File> onFileSelected;
  final Function(String) onOpenInTerminal;

  const FileTreeItemWidget({
    super.key,
    required this.item,
    required this.onFileSelected,
    required this.onOpenInTerminal,
  });

  @override
  _FileTreeItemWidgetState createState() => _FileTreeItemWidgetState();
}

class _FileTreeItemWidgetState extends State<FileTreeItemWidget> {
  bool _isEditing = false;
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.item.name);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      setState(() => _isEditing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isEditing
        ? _buildEditingWidget(context)
        : _buildNormalWidget(context);
  }

  Widget _buildNormalWidget(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: _FileTreeItemContent(
        item: widget.item,
        onTap: () => _handleTap(context),
      ),
    );
  }

  Widget _buildEditingWidget(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 8.0 * (widget.item.level + 1)),
      height: 24,
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        autofocus: true,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        onSubmitted: _handleRename,
      ),
    );
  }

  void _handleTap(BuildContext context) {
    final controller = context.read<FileExplorerController>();
    if (widget.item.isDirectory) {
      controller.toggleDirectoryExpansion(widget.item);
    } else if (widget.item.entity is File) {
      widget.onFileSelected(widget.item.entity as File);
    }
  }

  void _showContextMenu(BuildContext context, Offset globalPosition) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlay.size,
    );

    final controller = context.read<FileExplorerController>();
    showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      color: Colors.transparent,
      elevation: 0,
      items: [
        PopupMenuItem(
          padding: EdgeInsets.zero,
          enabled: false,
          child: ContextMenu(
            items: [
              ContextMenuItem(
                title: 'Rename',
                onTap: () => setState(() => _isEditing = true),
              ),
              ContextMenuItem(
                title: 'Delete',
                onTap: () => _handleDelete(context, controller),
              ),
              ContextMenuItem(
                title: 'Copy Path',
                onTap: () => _copyPath(context, false),
              ),
              ContextMenuItem(
                title: 'Copy Relative Path',
                onTap: () => _copyPath(context, true),
              ),
              ContextMenuItem(
                title: 'Cut',
                onTap: () => _cutItem(context, controller),
              ),
              ContextMenuItem(
                title: 'Copy',
                onTap: () => _copyItem(context, controller),
              ),
              ContextMenuItem(
                title: 'Paste',
                onTap: () => _pasteItem(context, controller),
              ),
              ContextMenuItem(
                title: 'Reveal in Finder',
                onTap: () => _revealInFinder(context),
              ),
              ContextMenuItem(
                title: 'Open in Terminal',
                onTap: () => _openInTerminal(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _revealInFinder(BuildContext context) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', widget.item.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', widget.item.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path.dirname(widget.item.path)]);
      } else {
        throw UnsupportedError('Unsupported platform for reveal in finder');
      }
    } catch (e) {
      MessageToastManager.showToast(context, 'Error revealing in finder: $e');
    }
  }

  void _openInTerminal(BuildContext context) {
    // ignore: no_leading_underscores_for_local_identifiers
    final _path = widget.item.isDirectory
        ? widget.item.path
        : path.dirname(widget.item.path);
    widget.onOpenInTerminal(_path);
  }

  void _handleRename(String newName) async {
    if (newName != widget.item.name) {
      final controller = context.read<FileExplorerController>();
      try {
        await controller.rename(widget.item.path, newName);
        await controller.refreshDirectory();
      } catch (e) {
        MessageToastManager.showToast(context, 'Error renaming: $e');
      }
    }
    setState(() => _isEditing = false);
  }

  void _handleDelete(
      BuildContext context, FileExplorerController controller) async {
    final isShiftPressed =
        RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftLeft);
    final isShiftRightPressed = RawKeyboard.instance.keysPressed
        .contains(LogicalKeyboardKey.shiftRight);

    if (isShiftPressed || isShiftRightPressed) {
      _performDelete(context, controller);
    } else {
      final confirmDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete ${widget.item.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmDelete == true) {
        _performDelete(context, controller);
      }
    }
  }

  void _performDelete(
      BuildContext context, FileExplorerController controller) async {
    try {
      await controller.delete(widget.item.path);
      await controller.refreshDirectory();
    } catch (e) {
      MessageToastManager.showToast(context, 'Error deleting: $e');
    }
  }

  void _copyPath(BuildContext context, bool relative) {
    final path = relative
        ? widget.item.path.replaceFirst(RegExp(r'^.*?/'), '')
        : widget.item.path;
    Clipboard.setData(ClipboardData(text: path));
    MessageToastManager.showToast(
        context, '${relative ? 'Relative path' : 'Path'} copied to clipboard');
  }

  void _cutItem(BuildContext context, FileExplorerController controller) {
    controller.setCutItem(widget.item);
  }

  void _copyItem(BuildContext context, FileExplorerController controller) {
    controller.setCopiedItem(widget.item);
  }

  void _pasteItem(
      BuildContext context, FileExplorerController controller) async {
    try {
      await controller.pasteItem(widget.item.path);
      await controller.refreshDirectory();
    } catch (e) {
      MessageToastManager.showToast(context, 'Error pasting item: $e');
    }
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
