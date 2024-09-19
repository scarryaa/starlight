import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/context_menu/context_menu.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/features/file_explorer/infrastructure/file_operation.dart';
import 'package:starlight/features/file_explorer/infrastructure/services/file_service.dart';
import 'package:starlight/features/toasts/error_toast.dart';
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
  static const double _itemHeight = 24.0;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _newItemController = TextEditingController();
  final FocusNode _newItemFocusNode = FocusNode();
  final FocusNode _explorerFocusNode = FocusNode();

  late ErrorToastManager _errorToastManager;

  bool _isCreatingNewItem = false;
  bool _isCreatingFile = true;

  final List<FileOperation> _undoStack = [];
  final List<FileOperation> _redoStack = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _errorToastManager = ErrorToastManager(context);
    _newItemFocusNode.addListener(_onNewItemFocusChange);
    _explorerFocusNode.addListener(_onExplorerFocusChange);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _newItemController.dispose();
    _newItemFocusNode.removeListener(_onNewItemFocusChange);
    _newItemFocusNode.dispose();
    _explorerFocusNode.removeListener(_onExplorerFocusChange);
    _explorerFocusNode.dispose();
    super.dispose();
  }

  void _onNewItemFocusChange() {
    if (!_newItemFocusNode.hasFocus) {
      _handleNewItemCreation();
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
    return items.expand((item) {
      final List<Widget> widgets = [
        FileTreeItemWidget(
          key: ValueKey(item.path),
          item: item,
          isSelected: controller.isItemSelected(item),
          onItemSelected: (item) => _handleItemTap(item, controller),
          onItemLongPress: () => _handleItemLongPress(item, controller),
          onSecondaryTap: (details) =>
              _handleItemSecondaryTap(context, details, item, controller),
        ),
      ];
      if (item.isDirectory && item.isExpanded) {
        widgets.addAll(_buildFileTreeItems(item.children, controller));
      }
      return widgets;
    }).toList();
  }

  Widget _buildNewItemInput(FileExplorerController controller) {
    return Container(
      padding: const EdgeInsets.only(left: 8.0),
      height: _itemHeight,
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
        onSubmitted: (_) => _handleNewItemCreation(),
        onEditingComplete: _handleNewItemCreation,
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

  void _handleItemLongPress(
      FileTreeItem item, FileExplorerController controller) {
    controller.selectItem(item);
  }

  void _handleItemSecondaryTap(BuildContext context, TapUpDetails details,
      FileTreeItem item, FileExplorerController controller) {
    controller.setSelectedItem(item);
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );
    _showContextMenu(context, position, controller, item);
  }

  void _toggleItemSelection(
      FileTreeItem item, FileExplorerController controller) {
    if (controller.isItemSelected(item)) {
      controller.deselectItem(item);
    } else {
      controller.selectItem(item);
    }
  }

  KeyEventResult _handleKeyPress(
      RawKeyEvent event, FileExplorerController controller) {
    if (event is RawKeyDownEvent) {
      final bool isShiftPressed = event.isShiftPressed;
      final bool isCtrlPressed = event.isControlPressed || event.isMetaPressed;

      if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
        _selectAll(controller);
        return KeyEventResult.handled;
      }

      if (isShiftPressed &&
          (event.logicalKey == LogicalKeyboardKey.arrowUp ||
              event.logicalKey == LogicalKeyboardKey.arrowDown)) {
        _handleShiftArrowSelection(
            controller, event.logicalKey == LogicalKeyboardKey.arrowUp);
        return KeyEventResult.handled;
      }

      if (_isCreatingNewItem) {
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          _handleNewItemCreation();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }

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
        case LogicalKeyboardKey.delete:
        case LogicalKeyboardKey.backspace:
          if (isCtrlPressed || isShiftPressed) {
            _handleDelete(context, controller, isShiftPressed);
            return KeyEventResult.handled;
          }
      }

      if (isCtrlPressed) {
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
          case LogicalKeyboardKey.keyZ:
            if (isShiftPressed) {
              _redo(context, controller);
            } else {
              _undo(context, controller);
            }
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyY:
            _redo(context, controller);
            return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _selectAll(FileExplorerController controller) {
    controller.enterMultiSelectMode();
    final allItems = _flattenItems(controller.rootItems);
    for (var item in allItems) {
      controller.selectItem(item);
    }
  }

  void _handleShiftArrowSelection(
      FileExplorerController controller, bool isUpArrow) {
    if (!controller.isMultiSelectMode) {
      controller.enterMultiSelectMode();
    }

    final allItems = _flattenItems(controller.rootItems);
    final currentIndex = controller.selectedItem != null
        ? allItems.indexOf(controller.selectedItem!)
        : -1;

    if (currentIndex != -1) {
      int newIndex = isUpArrow ? currentIndex - 1 : currentIndex + 1;
      if (newIndex >= 0 && newIndex < allItems.length) {
        final itemsToSelect = isUpArrow
            ? allItems.sublist(newIndex, currentIndex + 1).reversed
            : allItems.sublist(currentIndex, newIndex + 1);

        for (var item in itemsToSelect) {
          controller.selectItem(item);
        }

        controller.setSelectedItem(allItems[newIndex]);
        _scrollToSelectedItem(
            isUpArrow ? ScrollDirection.reverse : ScrollDirection.forward);
      }
    }
  }

  void _showContextMenu(BuildContext context, RelativeRect position,
      FileExplorerController controller, FileTreeItem? item) {
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
            items: _buildContextMenuItems(context, controller, item),
          ),
        ),
      ],
    );
  }

  List<ContextMenuItem> _buildContextMenuItems(BuildContext context,
      FileExplorerController controller, FileTreeItem? item) {
    final List<ContextMenuItem> menuItems = [];
    final bool isMultiSelectMode = controller.isMultiSelectMode;
    final List<FileTreeItem> selectedItems = controller.selectedItems;

    if (item == null) {
      menuItems.addAll([
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
          onTap: () => _pasteItems(context, controller),
        ),
      ]);
    } else {
      menuItems.addAll([
        ContextMenuItem(
          title: 'Copy',
          onTap: () => _copyItems(context, controller),
        ),
        ContextMenuItem(
          title: 'Cut',
          onTap: () => _cutItems(context, controller),
        ),
        ContextMenuItem(
          title: 'Rename',
          onTap: () => _renameItem(context, controller, item),
        ),
        ContextMenuItem(
          title: "Delete",
          onTap: () {
            if (isMultiSelectMode && selectedItems.isNotEmpty) {
              _deleteItems(context, controller, selectedItems, false);
            } else {
              _deleteItem(context, controller, item);
            }
          },
        ),
      ]);
    }

    menuItems.addAll([
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
    ]);

    return menuItems;
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
          final bottomEdge = currentScrollOffset + viewportHeight;
          if (itemPosition + _itemHeight > bottomEdge) {
            targetScrollOffset = itemPosition - viewportHeight + _itemHeight;
          }
        } else {
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
    return items.expand((item) {
      final flattened = [item];
      if (item.isDirectory && item.isExpanded) {
        flattened.addAll(_flattenItems(item.children));
      }
      return flattened;
    }).toList();
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

  void _handleDelete(BuildContext context, FileExplorerController controller,
      bool forceDelete) async {
    if (controller.selectedItems.isNotEmpty) {
      await _deleteItems(
          context, controller, controller.selectedItems, forceDelete);
    }
  }

  Future<void> _pasteItems(
      BuildContext context, FileExplorerController controller) async {
    try {
      List<FileOperation> pasteOperations =
          await controller.pasteItems(controller.currentDirectory!.path);
      _addToUndoStack(pasteOperations);
      await controller.refreshDirectory();
      MessageToastManager.showToast(context, 'Items pasted successfully');
    } catch (e) {
      _errorToastManager.showErrorToast(
          controller.currentDirectory!.path, 'Error pasting items: $e');
    }
  }

  void _addToUndoStack(List<FileOperation> operations) {
    _undoStack.add(FileOperation.combine(operations));
    _redoStack.clear();
  }

  Future<void> _undo(
      BuildContext context, FileExplorerController controller) async {
    if (_undoStack.isNotEmpty) {
      try {
        FileOperation operation = _undoStack.removeLast();
        List<FileOperation> undoOperations = await operation.undo(controller);
        _redoStack.add(FileOperation.combine(undoOperations));
        await controller.refreshDirectory();
        MessageToastManager.showToast(context, 'Undo successful');
      } catch (e) {
        _errorToastManager.showErrorToast(
            controller.currentDirectory!.path, 'Error undoing operation: $e');
      }
    } else {
      MessageToastManager.showToast(context, 'Nothing to undo');
    }
  }

  Future<void> _redo(
      BuildContext context, FileExplorerController controller) async {
    if (_redoStack.isNotEmpty) {
      try {
        FileOperation operation = _redoStack.removeLast();
        List<FileOperation> redoOperations = await operation.redo(controller);
        _undoStack.add(FileOperation.combine(redoOperations));
        await controller.refreshDirectory();
        MessageToastManager.showToast(context, 'Redo successful');
      } catch (e) {
        _errorToastManager.showErrorToast(
            controller.currentDirectory!.path, 'Error redoing operation: $e');
      }
    } else {
      MessageToastManager.showToast(context, 'Nothing to redo');
    }
  }

  Future<void> _handleNewItemCreation() async {
    final name = _newItemController.text.trim();
    if (name.isNotEmpty) {
      try {
        final controller = context.read<FileExplorerController>();
        if (_isCreatingFile) {
          await controller.createFile(controller.currentDirectory!.path, name);
        } else {
          await controller.createFolder(
              controller.currentDirectory!.path, name);
        }
        await controller.refreshDirectory();
        MessageToastManager.showToast(context,
            '${_isCreatingFile ? 'File' : 'Folder'} created successfully');
      } catch (e) {
        MessageToastManager.showToast(context,
            'Error creating ${_isCreatingFile ? 'file' : 'folder'}: $e');
      }
    }
    setState(() {
      _isCreatingNewItem = false;
      _explorerFocusNode.requestFocus();
    });
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

  Future<void> _renameItem(BuildContext context,
      FileExplorerController controller, FileTreeItem item) async {
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Rename ${item.isDirectory ? 'Folder' : 'File'}'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter new name'),
            controller: TextEditingController(text: item.name),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Rename'),
              onPressed: () => Navigator.of(context).pop((context
                      .findAncestorWidgetOfExactType<TextField>() as TextField)
                  .controller!
                  .text),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != item.name) {
      try {
        await controller.rename(item.path, newName);
        MessageToastManager.showToast(context, 'Item renamed successfully');
      } catch (e) {
        _errorToastManager.showErrorToast(
            controller.currentDirectory!.path, 'Error renaming item: $e');
      }
    }
  }

  Future<void> _deleteItem(BuildContext context,
      FileExplorerController controller, FileTreeItem item) async {
    final bool confirmDelete =
        await _showDeleteConfirmationDialog(context, [item]);

    if (confirmDelete) {
      try {
        String tempPath = await controller.moveToTemp(item.path);
        final deleteOperation =
            FileOperation(OperationType.delete, item.path, tempPath);
        _addToUndoStack([deleteOperation]);
        await controller.refreshDirectory();
        MessageToastManager.showToast(context,
            '${item.isDirectory ? 'Folder' : 'File'} deleted successfully');
      } catch (e) {
        _errorToastManager.showErrorToast(controller.currentDirectory!.path,
            'Error deleting ${item.isDirectory ? 'folder' : 'file'}: $e');
      }
    }
  }

  Future<void> _deleteItems(
      BuildContext context,
      FileExplorerController controller,
      List<FileTreeItem> items,
      bool forceDelete) async {
    bool confirmDelete = forceDelete;
    if (!forceDelete) {
      confirmDelete = await _showDeleteConfirmationDialog(context, items);
    }

    if (confirmDelete) {
      try {
        List<FileOperation> deleteOperations = [];
        for (var item in items) {
          String tempPath = await controller.moveToTemp(item.path);
          deleteOperations
              .add(FileOperation(OperationType.delete, item.path, tempPath));
        }
        _addToUndoStack(deleteOperations);
        await controller.refreshDirectory();
        MessageToastManager.showToast(
            context, '${items.length} item(s) deleted successfully');
      } catch (e) {
        _errorToastManager.showErrorToast(
            controller.currentDirectory!.path, 'Error deleting items: $e');
      }
    }
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

  Future<bool> _showDeleteConfirmationDialog(
      BuildContext context, List<FileTreeItem> items) async {
    final itemCount = items.length;
    final isMultipleItems = itemCount > 1;

    String content;
    if (isMultipleItems) {
      content = 'Are you sure you want to delete these $itemCount item(s)?';
    } else {
      final item = items.first;
      content = 'Are you sure you want to delete ${item.name}?';
    }

    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Delete'),
              content: Text(content),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('Delete'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
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
      _errorToastManager.showErrorToast(
          currentPath, 'Error revealing in finder: $e');
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
      _errorToastManager.showErrorToast(controller.currentDirectory?.path ?? '',
          'Error selecting directory: $e');
    } finally {
      controller.setLoading(false);
    }
  }
}

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
        color:
            isSelected ? Theme.of(context).highlightColor : Colors.transparent,
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
