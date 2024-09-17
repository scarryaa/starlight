import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/context_menu/context_menu.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/features/file_explorer/infrastructure/services/file_service.dart';
import 'package:starlight/features/file_explorer/presentation/file_tree_item.dart';
import 'package:starlight/features/toasts/message_toast.dart';

class FileExplorer extends StatefulWidget {
  final Function(File) onFileSelected;
  final Function(String?) onDirectorySelected;
  final FileExplorerController controller;
  final Function(String) onOpenInTerminal;

  const FileExplorer({
    super.key,
    required this.onFileSelected,
    required this.onDirectorySelected,
    required this.controller,
    required this.onOpenInTerminal,
  });

  @override
  FileExplorerState createState() => FileExplorerState();
}

class FileExplorerState extends State<FileExplorer> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.controller,
      child: _FileExplorerContent(
        onFileSelected: widget.onFileSelected,
        onDirectorySelected: widget.onDirectorySelected,
        onOpenInTerminal: widget.onOpenInTerminal,
      ),
    );
  }
}

class _FileExplorerContent extends StatefulWidget {
  final Function(File) onFileSelected;
  final Function(String?) onDirectorySelected;
  final Function(String) onOpenInTerminal;

  const _FileExplorerContent({
    required this.onFileSelected,
    required this.onDirectorySelected,
    required this.onOpenInTerminal,
  });

  @override
  _FileExplorerContentState createState() => _FileExplorerContentState();
}

class _FileExplorerContentState extends State<_FileExplorerContent>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _newItemController = TextEditingController();
  final FocusNode _newItemFocusNode = FocusNode();
  bool _isCreatingNewItem = false;
  bool _isCreatingFile = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _newItemFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _newItemController.dispose();
    _newItemFocusNode.removeListener(_onFocusChange);
    _newItemFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_newItemFocusNode.hasFocus) {
      setState(() => _isCreatingNewItem = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Consumer<FileExplorerController>(
              builder: (context, controller, child) =>
                  _buildFileExplorer(theme, controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectorySelectionPrompt(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: theme.iconTheme.color?.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _pickDirectory,
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: Text(
              'Select Directory',
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileExplorer(
      ThemeData theme, FileExplorerController controller) {
    if (controller.currentDirectory == null) {
      return _buildDirectorySelectionPrompt(theme);
    }
    return Theme(
      data: theme.copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(
              theme.colorScheme.secondary.withOpacity(0.6)),
          thickness: WidgetStateProperty.all(6.0),
          radius: const Radius.circular(0),
        ),
      ),
      child: GestureDetector(
        onSecondaryTapUp: (details) => _handleSecondaryTapUp(context, details),
        behavior: HitTestBehavior.translucent,
        child: Scrollbar(
          controller: _scrollController,
          child: ListView(
            controller: _scrollController,
            children: [
              ...controller.rootItems
                  .map((item) => _buildFileTreeItem(item, controller)),
              if (_isCreatingNewItem) _buildNewItemInput(controller),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileTreeItem(
      FileTreeItem item, FileExplorerController controller) {
    return FileTreeItemWidget(
      key: ValueKey(item.path),
      item: item,
      onFileSelected: widget.onFileSelected,
      onOpenInTerminal: widget.onOpenInTerminal,
    );
  }

  Widget _buildNewItemInput(FileExplorerController controller) {
    return Container(
      padding: const EdgeInsets.only(left: 8.0),
      height: 24,
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (RawKeyEvent event) {
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            setState(() => _isCreatingNewItem = false);
          }
        },
        child: TextField(
          controller: _newItemController,
          focusNode: _newItemFocusNode,
          autofocus: true,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            prefixIcon: Icon(
              _isCreatingFile ? Icons.insert_drive_file : Icons.folder,
              size: 14,
            ),
          ),
          onSubmitted: (value) => _handleNewItemCreation(controller, value),
        ),
      ),
    );
  }

  void _handleSecondaryTapUp(BuildContext context, TapUpDetails details) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );
    _showContextMenu(context, position);
  }

  void _showContextMenu(BuildContext context, RelativeRect position) {
    final controller = context.read<FileExplorerController>();
    showMenu<void>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      color: Colors.transparent,
      elevation: 0,
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: ContextMenu(
            items: [
              ContextMenuItem(
                title: 'New File',
                onTap: () => _startCreatingNewItem(true),
              ),
              ContextMenuItem(
                title: 'New Folder',
                onTap: () => _startCreatingNewItem(false),
              ),
              ContextMenuItem(
                title: 'Refresh',
                onTap: () => controller.refreshDirectory(),
              ),
              ContextMenuItem(
                title: 'Paste',
                onTap: () => _pasteItem(context, controller),
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
                title: 'Reveal in Finder',
                onTap: () => _revealInFinder(context),
              ),
              ContextMenuItem(
                title: 'Open in Integrated Terminal',
                onTap: () =>
                    widget.onOpenInTerminal(controller.currentDirectory!.path),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _pasteItem(
      BuildContext context, FileExplorerController controller) async {
    try {
      await controller.pasteItem(controller.currentDirectory!.path);
      await controller.refreshDirectory();
      MessageToastManager.showToast(context, 'Item pasted successfully');
    } catch (e) {
      MessageToastManager.showToast(context, 'Error pasting item: $e');
    }
  }

  void _copyPath(BuildContext context, bool relative) {
    final currentPath =
        context.read<FileExplorerController>().currentDirectory!.path;
    final pathToCopy = relative
        ? path.relative(currentPath, from: path.dirname(currentPath))
        : currentPath;
    Clipboard.setData(ClipboardData(text: pathToCopy));
    MessageToastManager.showToast(
        context, '${relative ? 'Relative path' : 'Path'} copied to clipboard');
  }

  void _revealInFinder(BuildContext context) async {
    final currentPath =
        context.read<FileExplorerController>().currentDirectory!.path;
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [currentPath]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [currentPath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [currentPath]);
      } else {
        throw UnsupportedError('Unsupported platform for reveal in finder');
      }
    } catch (e) {
      MessageToastManager.showToast(context, 'Error revealing in finder: $e');
    }
  }

  void _startCreatingNewItem(bool isFile) {
    setState(() {
      _isCreatingNewItem = true;
      _isCreatingFile = isFile;
      _newItemController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _newItemFocusNode.requestFocus();
    });
  }

  Future<void> _handleNewItemCreation(
      FileExplorerController controller, String name) async {
    if (name.isNotEmpty) {
      try {
        if (_isCreatingFile) {
          await controller.createFile(controller.currentDirectory!.path, name);
        } else {
          await controller.createFolder(
              controller.currentDirectory!.path, name);
        }
        await controller.refreshDirectory();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error creating ${_isCreatingFile ? 'file' : 'folder'}: $e')),
        );
      }
    }
    setState(() => _isCreatingNewItem = false);
  }

  Future<void> _pickDirectory() async {
    final controller = context.read<FileExplorerController>();
    try {
      String? selectedDirectory = await FileService.pickDirectory();
      if (selectedDirectory != null) {
        controller.setDirectory(Directory(selectedDirectory));
        widget.onDirectorySelected(selectedDirectory);
      }
    } catch (e) {
      print('Error picking directory: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting directory: $e')),
      );
    } finally {
      controller.setLoading(false);
    }
  }
}
