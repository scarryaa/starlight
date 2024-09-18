import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/context_menu/context_menu.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/features/file_explorer/infrastructure/services/file_service.dart';
import 'package:starlight/features/file_explorer/presentation/file_tree_item.dart';
import 'package:starlight/features/toasts/message_toast.dart';
import 'package:path/path.dart' as path;

class FileExplorer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: _FileExplorerContent(
        onFileSelected: onFileSelected,
        onDirectorySelected: onDirectorySelected,
        onOpenInTerminal: onOpenInTerminal,
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
  final FocusNode _explorerFocusNode = FocusNode();
  bool _isCreatingNewItem = false;
  bool _isCreatingFile = true;

  static const double _itemHeight = 24.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _newItemFocusNode.addListener(_onFocusChange);
    _explorerFocusNode.addListener(_onExplorerFocusChange);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _newItemController.dispose();
    _newItemFocusNode.removeListener(_onFocusChange);
    _newItemFocusNode.dispose();
    _explorerFocusNode.removeListener(_onExplorerFocusChange);
    _explorerFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_newItemFocusNode.hasFocus) {
      setState(() => _isCreatingNewItem = false);
    }
  }

  void _onExplorerFocusChange() {
    if (_explorerFocusNode.hasFocus) {
      final controller = context.read<FileExplorerController>();
      if (controller.selectedItem == null && controller.rootItems.isNotEmpty) {
        controller.setSelectedItem(controller.rootItems.first);
        _scrollToSelectedItem(ScrollDirection.forward);
      }
    }
  }

  void _scrollToSelectedItem(ScrollDirection direction) {
    final controller = context.read<FileExplorerController>();
    if (controller.selectedItem != null) {
      final selectedItemIndex =
          _findItemIndex(controller.rootItems, controller.selectedItem!);
      if (selectedItemIndex != -1) {
        final itemPosition = selectedItemIndex * _itemHeight;
        final viewportHeight = _scrollController.position.viewportDimension;
        final currentScrollOffset = _scrollController.offset;

        double targetScrollOffset = currentScrollOffset;

        if (direction == ScrollDirection.forward) {
          // Scrolling down
          final bottomEdge = currentScrollOffset + viewportHeight;
          if (itemPosition + _itemHeight > bottomEdge) {
            targetScrollOffset = itemPosition - viewportHeight + _itemHeight;
          }
        } else {
          // Scrolling up
          if (itemPosition < currentScrollOffset) {
            targetScrollOffset = itemPosition;
          }
        }

        targetScrollOffset = targetScrollOffset.clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );

        if ((targetScrollOffset - currentScrollOffset).abs() > 1.0) {
          _scrollController.animateTo(
            targetScrollOffset,
            duration: const Duration(milliseconds: 1),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

  int _findItemIndex(List<FileTreeItem> items, FileTreeItem target,
      [int startIndex = 0]) {
    for (var i = 0; i < items.length; i++) {
      if (items[i] == target) {
        return startIndex + i;
      }
      if (items[i].isDirectory && items[i].isExpanded) {
        final childIndex =
            _findItemIndex(items[i].children, target, startIndex + i + 1);
        if (childIndex != -1) {
          return childIndex;
        }
        startIndex += items[i].children.length;
      }
    }
    return -1;
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
      child: Focus(
        focusNode: _explorerFocusNode,
        onKey: (node, event) => _handleKeyPress(event, controller),
        child: GestureDetector(
          onTap: () => _explorerFocusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: Scrollbar(
            controller: _scrollController,
            child: ListView(
              controller: _scrollController,
              children: [
                ..._buildFileTreeItems(controller.rootItems, controller),
                if (_isCreatingNewItem) _buildNewItemInput(controller),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFileTreeItems(
      List<FileTreeItem> items, FileExplorerController controller) {
    List<Widget> widgets = [];
    for (var item in items) {
      widgets.add(FileTreeItemWidget(
        key: ValueKey(item.path),
        item: item,
        isSelected: controller.isItemSelected(item),
        onItemSelected: (item) => _handleItemTap(item, controller),
        onLongPress: () => _handleItemLongPress(item, controller),
      ));
      if (item.isDirectory && item.isExpanded) {
        widgets.addAll(_buildFileTreeItems(item.children, controller));
      }
    }
    return widgets;
  }

  void _handleItemTap(FileTreeItem item, FileExplorerController controller) {
    _explorerFocusNode.requestFocus();
    if (controller.isMultiSelectMode) {
      controller.toggleItemSelection(item);
    } else {
      controller.setSelectedItem(item);
      if (item.isDirectory) {
        controller.toggleDirectoryExpansion(item);
      } else {
        widget.onFileSelected(item.entity as File);
      }
    }
    _scrollToSelectedItem(ScrollDirection.forward);
  }

  KeyEventResult _handleKeyPress(
      RawKeyEvent event, FileExplorerController controller) {
    if (event is RawKeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          _navigateUp(controller);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowDown:
          _navigateDown(controller);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowLeft:
          _navigateLeft(controller);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
          _navigateRight(controller);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.enter:
          _handleEnter(controller);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.space:
          _handleSpace(controller);
          return KeyEventResult.handled;
      }

      if (event.isControlPressed) {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyC:
            _copyItems(context, controller);
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyX:
            _cutItems(context, controller);
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyV:
            _pasteItems(context, controller);
            return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _navigateUp(FileExplorerController controller) {
    final allItems = _flattenItems(controller.rootItems);
    final currentIndex = controller.selectedItem != null
        ? allItems.indexOf(controller.selectedItem!)
        : -1;
    if (currentIndex > 0) {
      controller.setSelectedItem(allItems[currentIndex - 1]);
      _scrollToSelectedItem(ScrollDirection.reverse);
    } else if (currentIndex == -1) {
      controller.setSelectedItem(allItems.last);
      _scrollToSelectedItem(ScrollDirection.reverse);
    }
  }

  void _navigateDown(FileExplorerController controller) {
    final allItems = _flattenItems(controller.rootItems);
    final currentIndex = controller.selectedItem != null
        ? allItems.indexOf(controller.selectedItem!)
        : -1;
    if (currentIndex < allItems.length - 1) {
      controller.setSelectedItem(allItems[currentIndex + 1]);
      _scrollToSelectedItem(ScrollDirection.forward);
    } else if (currentIndex == -1) {
      controller.setSelectedItem(allItems.first);
      _scrollToSelectedItem(ScrollDirection.forward);
    }
  }

  void _navigateLeft(FileExplorerController controller) {
    if (controller.selectedItem?.isDirectory == true &&
        controller.selectedItem!.isExpanded) {
      controller.toggleDirectoryExpansion(controller.selectedItem!);
    } else if (controller.selectedItem?.parent != null) {
      controller.setSelectedItem(controller.selectedItem!.parent!);
      _scrollToSelectedItem(ScrollDirection.reverse);
    }
  }

  void _navigateRight(FileExplorerController controller) {
    if (controller.selectedItem?.isDirectory == true) {
      if (!controller.selectedItem!.isExpanded) {
        controller.toggleDirectoryExpansion(controller.selectedItem!);
      } else if (controller.selectedItem!.children.isNotEmpty) {
        controller.setSelectedItem(controller.selectedItem!.children.first);
        _scrollToSelectedItem(ScrollDirection.forward);
      }
    }
  }

  List<FileTreeItem> _flattenItems(List<FileTreeItem> items) {
    List<FileTreeItem> flattened = [];
    for (var item in items) {
      flattened.add(item);
      if (item.isDirectory && item.isExpanded) {
        flattened.addAll(_flattenItems(item.children));
      }
    }
    return flattened;
  }

  void _handleEnter(FileExplorerController controller) {
    if (controller.selectedItem != null) {
      if (controller.selectedItem!.isDirectory) {
        controller.toggleDirectoryExpansion(controller.selectedItem!);
      } else {
        widget.onFileSelected(controller.selectedItem!.entity as File);
      }
    }
  }

  void _handleSpace(FileExplorerController controller) {
    if (controller.selectedItem != null) {
      controller.toggleItemSelection(controller.selectedItem!);
    }
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

  void _handleItemLongPress(
      FileTreeItem item, FileExplorerController controller) {
    controller.enterMultiSelectMode();
    controller.toggleItemSelection(item);
  }

  void _handleSecondaryTapUp(BuildContext context, TapUpDetails details,
      FileExplorerController controller) {
    final tappedItem =
        controller.findTappedItem(details.globalPosition, controller.rootItems);

    if (tappedItem != null) {
      controller.setSelectedItem(tappedItem);
    }

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );
    _showContextMenu(context, position, controller);
  }

  void _showContextMenu(BuildContext context, RelativeRect position,
      FileExplorerController controller) {
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
            items: _buildContextMenuItems(context, controller),
          ),
        ),
      ],
    );
  }

  List<ContextMenuItem> _buildContextMenuItems(
      BuildContext context, FileExplorerController controller) {
    return [
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
        title: 'Copy',
        onTap: () => _copyItems(context, controller),
      ),
      ContextMenuItem(
        title: 'Cut',
        onTap: () => _cutItems(context, controller),
      ),
      ContextMenuItem(
        title: 'Paste',
        onTap: () => _pasteItems(context, controller),
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
        onTap: () => widget.onOpenInTerminal(controller.currentDirectory!.path),
      ),
    ];
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

  void _copyItems(BuildContext context, FileExplorerController controller) {
    final selectedItems = controller.selectedItems;
    if (selectedItems.isNotEmpty) {
      controller.setCopiedItems(selectedItems);
      MessageToastManager.showToast(
          context, '${selectedItems.length} item(s) copied');
    } else {
      MessageToastManager.showToast(context, 'No items selected');
    }
  }

  void _cutItems(BuildContext context, FileExplorerController controller) {
    final selectedItems = controller.selectedItems;
    if (selectedItems.isNotEmpty) {
      controller.setCutItems(selectedItems);
      MessageToastManager.showToast(
          context, '${selectedItems.length} item(s) cut');
    } else {
      MessageToastManager.showToast(context, 'No items selected');
    }
  }

  Future<void> _pasteItems(
      BuildContext context, FileExplorerController controller) async {
    try {
      await controller.pasteItems(controller.currentDirectory!.path);
      await controller.refreshDirectory();
      MessageToastManager.showToast(context, 'Items pasted successfully');
    } catch (e) {
      MessageToastManager.showToast(context, 'Error pasting items: $e');
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

  Future<void> _revealInFinder(BuildContext context) async {
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
