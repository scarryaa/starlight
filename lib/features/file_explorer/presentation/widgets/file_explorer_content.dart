import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';
import 'package:starlight/features/file_explorer/infrastructure/file_operation.dart';
import 'package:starlight/features/file_explorer/presentation/widgets/file_tree_item_widget.dart';
import 'package:starlight/features/file_explorer/presentation/widgets/new_item_input.dart';
import 'package:starlight/features/file_explorer/presentation/widgets/directory_selection_prompt.dart';
import 'package:starlight/features/file_explorer/application/file_operation_manager.dart';
import 'package:starlight/features/file_explorer/presentation/widgets/context_menu_builder.dart';
import 'package:starlight/features/file_explorer/presentation/widgets/quick_action_bar.dart';
import 'package:starlight/features/toasts/message_toast.dart';
import 'package:starlight/features/file_explorer/infrastructure/services/file_service.dart';

class FileExplorerContent extends StatefulWidget {
  final Function(File) onFileSelected;
  final Function(String?) onDirectorySelected;
  final Function(String) onOpenInTerminal;

  const FileExplorerContent({
    super.key,
    required this.onFileSelected,
    required this.onDirectorySelected,
    required this.onOpenInTerminal,
  });

  @override
  _FileExplorerContentState createState() => _FileExplorerContentState();
}

class _FileExplorerContentState extends State<FileExplorerContent>
    with AutomaticKeepAliveClientMixin {
  static const double _itemHeight = 24.0;
  FileTreeItem? _highlightedItem;
  late ScrollController _scrollController;
  late FocusNode _explorerFocusNode;
  late FileOperationManager _fileOperationManager;
  late TextEditingController _searchController;
  List<FileTreeItem> _filteredItems = [];
  bool _isSearching = false;
  bool _isSearchBarVisible = false;
  final FocusNode _searchFocusNode = FocusNode();
  bool _isCreatingNewItem = false;
  FileTreeItem? _newItemParent;
  bool _isCreatingFile = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _explorerFocusNode = FocusNode();
    _explorerFocusNode.addListener(_onExplorerFocusChange);
    _fileOperationManager = FileOperationManager(context);
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _explorerFocusNode.addListener(_onExplorerFocusChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _explorerFocusNode.removeListener(_onExplorerFocusChanged);
    _explorerFocusNode.dispose();
    super.dispose();
  }

  void _onExplorerFocusChanged() {
    if (_explorerFocusNode.hasFocus) {
      final controller = context.read<FileExplorerController>();
      if (controller.selectedItem == null && controller.rootItems.isNotEmpty) {
        _scrollToSelectedItem(ScrollDirection.forward);
      }
    }
  }

  void _onSearchFocusChanged() {
    if (!_searchFocusNode.hasFocus) {
      setState(() {
        if (_searchController.text.isEmpty) {
          _isSearchBarVisible = false;
          _isSearching = false;
          _filteredItems = [];
        }
      });
    }
  }

  void _onSearchChanged() {
    final controller = context.read<FileExplorerController>();
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _isSearching = false;
        _filteredItems = [];
      } else {
        _isSearching = true;
        _filteredItems = _searchItems(controller.rootItems, query);
      }
    });
  }

  List<FileTreeItem> _searchItems(List<FileTreeItem> items, String query) {
    List<FileTreeItem> results = [];
    for (var item in items) {
      if (item.name.toLowerCase().contains(query)) {
        results.add(item);
      }
      if (item.isDirectory) {
        results.addAll(_searchItems(item.children, query));
      }
    }
    return results;
  }

  void _onExplorerFocusChange() {
    if (_explorerFocusNode.hasFocus) {
      final controller = context.read<FileExplorerController>();
      if (controller.selectedItem == null && controller.rootItems.isNotEmpty) {
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
          Consumer<FileExplorerController>(
            builder: (context, controller, child) => QuickActionBar(
              onNewFolder: () => _startCreatingNewItem(false, null),
              onNewFile: () => _startCreatingNewItem(true, null),
              onCopy: _copyItems,
              onCut: _cutItems,
              onPaste: (controller) =>
                  _fileOperationManager.pasteItems(controller),
              onExpandAll: () async {
                await controller.expandAll();
                MessageToastManager.showToast(
                    context, 'All directories expanded');
              },
              onCollapseAll: () {
                controller.collapseAll();
                MessageToastManager.showToast(
                    context, 'All directories collapsed');
              },
              onSearch: _toggleSearchBar,
              onToggleSystemFiles: () => context
                  .read<FileExplorerController>()
                  .toggleHideSystemFiles(),
            ),
          ),
          if (_isSearchBarVisible) _buildSearchBar(),
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _closeSearch();
          }
        },
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search files and folders',
            hintStyle: TextStyle(fontSize: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: _closeSearch,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          ),
          onSubmitted: (_) => _closeSearch(),
          onEditingComplete: () {
            _onSearchChanged();
            _explorerFocusNode.requestFocus();
          },
        ),
      ),
    );
  }

  List<Widget> _buildFileTreeItems(
      List<FileTreeItem> items, FileExplorerController controller) {
    List<Widget> widgets = [];
    final itemsToDisplay = _isSearching ? _filteredItems : items;

    if (_isCreatingNewItem && _newItemParent == null) {
      widgets.add(
        NewItemInput(
          onItemCreated: (name, isFile) =>
              _handleNewItemCreation(controller, name, isFile),
          onCancel: _cancelNewItemCreation,
          parent: null,
          isCreatingFile: _isCreatingFile,
        ),
      );
    }

    for (var item in itemsToDisplay) {
      widgets.add(
        _buildDraggableItem(item, controller),
      );
      if (_isCreatingNewItem && _newItemParent == item) {
        widgets.add(
          NewItemInput(
            onItemCreated: (name, isFile) =>
                _handleNewItemCreation(controller, name, isFile),
            onCancel: _cancelNewItemCreation,
            parent: _newItemParent,
            isCreatingFile: _isCreatingFile,
          ),
        );
      }

      if (!_isSearching && item.isDirectory && item.isExpanded) {
        widgets.addAll(_buildFileTreeItems(item.children, controller));
      }
    }

    return widgets;
  }

  Widget _buildDraggableItem(
      FileTreeItem item, FileExplorerController controller) {
    final isItemSelected = controller.isItemSelected(item);
    final isMultipleSelection = controller.selectedItems.length > 1;

    final itemsToDrag = isItemSelected && isMultipleSelection
        ? controller.selectedItems
        : [item];

    return Draggable<List<FileTreeItem>>(
      data: itemsToDrag,
      child: _buildDropTarget(item, controller),
      feedback: Material(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.grey[200],
          child: Text(
            itemsToDrag.length > 1 ? '${itemsToDrag.length} items' : item.name,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: FileTreeItemWidget(
          key: ValueKey(item.path),
          item: item,
          isSelected: controller.isItemSelected(item),
          onItemSelected: (item) => _handleItemTap(item, controller),
          onItemLongPress: () => _handleItemLongPress(item, controller),
          onSecondaryTap: (details) =>
              _handleItemSecondaryTap(context, details, item, controller),
        ),
      ),
    );
  }

  Widget _buildDropTarget(
      FileTreeItem item, FileExplorerController controller) {
    return DragTarget<List<FileTreeItem>>(
      onWillAccept: (data) {
        bool canAccept = data != null &&
            data.every((draggedItem) =>
                draggedItem != item && _canAcceptDrop(draggedItem, item));
        if (canAccept) {
          setState(() {
            _highlightedItem = item;
          });
        }
        return canAccept;
      },
      onLeave: (data) {
        setState(() {
          _highlightedItem = null;
        });
      },
      onAccept: (data) {
        setState(() {
          _highlightedItem = null;
        });
        _handleItemsDrop(data, item, controller);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  _highlightedItem == item ? Colors.blue : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FileTreeItemWidget(
            key: ValueKey(item.path),
            item: item,
            isSelected: controller.isItemSelected(item),
            onItemSelected: (item) => _handleItemTap(item, controller),
            onItemLongPress: () => _handleItemLongPress(item, controller),
            onSecondaryTap: (details) =>
                _handleItemSecondaryTap(context, details, item, controller),
          ),
        );
      },
    );
  }

  void _toggleSearchBar() {
    setState(() {
      _isSearchBarVisible = !_isSearchBarVisible;
      if (_isSearchBarVisible) {
        _searchFocusNode.requestFocus();
      } else {
        _closeSearch();
      }
    });
  }

  void _handleItemsDrop(List<FileTreeItem> draggedItems,
      FileTreeItem? targetItem, FileExplorerController controller) async {
    try {
      final String destinationPath =
          targetItem?.getFullPath() ?? controller.currentDirectory!.path;

      for (var draggedItem in draggedItems) {
        final String newPath =
            path.join(destinationPath, path.basename(draggedItem.path));
        await controller.moveItem(draggedItem.getFullPath(), newPath);
      }
      await controller.refreshDirectory();
      MessageToastManager.showToast(context, 'Items moved successfully');
    } catch (e) {
      MessageToastManager.showToast(context, 'Error moving items: $e');
    }
  }

  Widget _buildFileExplorer(
      ThemeData theme, FileExplorerController controller) {
    if (controller.currentDirectory == null) {
      return DirectorySelectionPrompt(onSelectDirectory: _pickDirectory);
    }
    return Theme(
      data: theme.copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: MaterialStateProperty.all(
              theme.colorScheme.secondary.withOpacity(0.6)),
          thickness: MaterialStateProperty.all(6.0),
          radius: const Radius.circular(0),
        ),
      ),
      child: Focus(
        focusNode: _explorerFocusNode,
        onKey: (node, event) => _handleKeyPress(event, controller),
        child: GestureDetector(
          onTap: () => _explorerFocusNode.requestFocus(),
          child: DragTarget<List<FileTreeItem>>(
            onWillAccept: (data) {
              setState(() {
                _highlightedItem =
                    null; // Clear any previously highlighted item
              });
              return data != null;
            },
            onAccept: (data) => _handleItemsDrop(data, null, controller),
            builder: (context, candidateData, rejectedData) {
              return Container(
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _highlightedItem == null && candidateData.isNotEmpty
                        ? Colors.blue
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: GestureDetector(
                    onTap: () => _handleEmptySpaceLeftClick(controller),
                    onSecondaryTapUp: (details) => _handleEmptySpaceRightClick(
                        context, details, controller),
                    behavior: HitTestBehavior.opaque,
                    child: Scrollbar(
                        controller: _scrollController,
                        child: ListView(
                          controller: _scrollController,
                          padding: EdgeInsets.zero,
                          children: [
                            ..._buildFileTreeItems(
                                controller.rootItems, controller),
                            const SizedBox(height: 24),
                          ],
                        ))),
              );
            },
          ),
        ),
      ),
    );
  }

  bool _canAcceptDrop(FileTreeItem draggedItem, FileTreeItem targetItem) {
    // Prevent dropping a directory into its own subdirectory
    if (draggedItem.isDirectory) {
      FileTreeItem? parent = targetItem;
      while (parent != null) {
        if (parent == draggedItem) {
          return false;
        }
        parent = parent.parent;
      }
    }
    return targetItem.isDirectory;
  }

  void _handleEmptySpaceLeftClick(FileExplorerController controller) {
    controller.clearSelectedItems();
    _explorerFocusNode.requestFocus();
  }

  void _handleEmptySpaceRightClick(BuildContext context, TapUpDetails details,
      FileExplorerController controller) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    showContextMenu(
        context,
        position,
        controller,
        null,
        _startCreatingNewItem,
        _copyItems,
        _cutItems,
        _renameItem,
        _deleteItem,
        _deleteItems,
        _copyPath,
        _revealInFinder,
        widget.onOpenInTerminal,
        _fileOperationManager);
  }

  void _startCreatingNewItem(bool isFile, FileTreeItem? parentItem) {
    setState(() {
      _isCreatingNewItem = true;
      _newItemParent = parentItem;
      _isCreatingFile = isFile;
    });
  }

  void _handleItemTap(FileTreeItem item, FileExplorerController controller) {
    _explorerFocusNode.requestFocus();
    if (_isCtrlOrCmdPressed()) {
      controller.toggleItemSelection(item);
    } else if (_isShiftPressed() && controller.selectedItem != null) {
      _handleShiftClickSelection(controller, item);
    } else {
      controller.clearSelectedItems();
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

  void _closeSearch() {
    setState(() {
      _isSearchBarVisible = false;
      _isSearching = false;
      _filteredItems = [];
    });
    _searchController.clear();
    _explorerFocusNode.requestFocus();
  }

  void _handleItemSecondaryTap(BuildContext context, TapUpDetails details,
      FileTreeItem item, FileExplorerController controller) {
    if (!controller.isItemSelected(item)) {
      controller.clearSelectedItems();
      controller.setSelectedItem(item);
    }

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    showContextMenu(
        context,
        position,
        controller,
        item,
        _startCreatingNewItem,
        _copyItems,
        _cutItems,
        _renameItem,
        _deleteItem,
        _deleteItems,
        _copyPath,
        _revealInFinder,
        widget.onOpenInTerminal,
        _fileOperationManager);
  }

  KeyEventResult _handleKeyPress(
      RawKeyEvent event, FileExplorerController controller) {
    if (event is RawKeyDownEvent) {
      final bool isShiftPressed = event.isShiftPressed;
      final bool isCtrlPressed = event.isControlPressed || event.isMetaPressed;
      final bool isAltPressed = event.isAltPressed;

      // Handle Escape key to close search
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_isSearchBarVisible) {
          _closeSearch();
          return KeyEventResult.handled;
        }
      }

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
          _handleNewItemCreation(controller, '', true);
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
            _fileOperationManager.pasteItems(controller);
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyZ:
            if (isShiftPressed) {
              _fileOperationManager.redo(controller);
            } else {
              _fileOperationManager.undo(controller);
            }
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyY:
            _fileOperationManager.redo(controller);
            return KeyEventResult.handled;
        }
      }

      // Handle Escape key to close search or cancel multi-select
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_isSearchBarVisible) {
          _closeSearch();
          return KeyEventResult.handled;
        } else if (controller.isMultiSelectMode) {
          controller.clearSelectedItems();
          return KeyEventResult.handled;
        }
      }

      // Handle typing to trigger search
      if (!_isModifierKey(event.logicalKey) &&
          !_isSpecialKey(event.logicalKey) &&
          event.character != null &&
          event.character!.isNotEmpty &&
          !isCtrlPressed &&
          !isAltPressed) {
        if (!_isSearchBarVisible) {
          setState(() {
            _isSearchBarVisible = true;
          });
        }
        _searchFocusNode.requestFocus();
        _searchController.text += event.character!;
        _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  bool _isSpecialKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown;
  }

  Future<void> _handleNewItemCreation(
      FileExplorerController controller, String name, bool isFile) async {
    if (name.isNotEmpty) {
      try {
        FileTreeItem? parentItem;
        if (_newItemParent != null) {
          parentItem = _newItemParent;
        } else if (controller.selectedItem != null &&
            controller.selectedItem!.isDirectory) {
          parentItem = controller.selectedItem;
        } else {
          parentItem = null;
        }

        final parentPath =
            parentItem?.getFullPath() ?? controller.currentDirectory!.path;
        final newItemPath = path.join(parentPath, name);
        if (isFile) {
          await controller.createFile(parentPath, name);
        } else {
          await controller.createFolder(parentPath, name);
        }

        await controller.refreshDirectory();
        final newItem = controller.findItemByPath(newItemPath);
        if (newItem != null) {
          controller.clearSelection();
          controller.setSelectedItem(newItem);
          _scrollToSelectedItem(ScrollDirection.forward);
        }
        MessageToastManager.showToast(
            context, '${isFile ? 'File' : 'Folder'} created successfully');
      } catch (e) {
        MessageToastManager.showToast(
            context, 'Error creating ${isFile ? 'file' : 'folder'}: $e');
      } finally {
        _cancelNewItemCreation();
      }
    } else {
      _cancelNewItemCreation();
    }
  }

  void _cancelNewItemCreation() {
    setState(() {
      _isCreatingNewItem = false;
      _newItemParent = null;
      _isCreatingFile = true;
      _explorerFocusNode.requestFocus();
    });
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
      controller.clearSelectedItems();
      controller.setSelectedItem(allItems[currentIndex - 1]);
      _scrollToSelectedItem(ScrollDirection.reverse);
    } else if (currentIndex == -1) {
      controller.clearSelectedItems();
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
      controller.clearSelectedItems();
      controller.setSelectedItem(allItems[currentIndex + 1]);
      _scrollToSelectedItem(ScrollDirection.forward);
    } else if (currentIndex == -1) {
      controller.clearSelectedItems();
      controller.setSelectedItem(allItems.first);
      _scrollToSelectedItem(ScrollDirection.forward);
    }
  }

  void _navigateLeft(FileExplorerController controller) {
    if (controller.selectedItem?.isDirectory == true &&
        controller.selectedItem!.isExpanded) {
      controller.toggleDirectoryExpansion(controller.selectedItem!);
    } else if (controller.selectedItem?.parent != null) {
      controller.clearSelectedItems();
      controller.setSelectedItem(controller.selectedItem!.parent!);
      _scrollToSelectedItem(ScrollDirection.reverse);
    }
  }

  void _navigateRight(FileExplorerController controller) {
    if (controller.selectedItem?.isDirectory == true) {
      if (!controller.selectedItem!.isExpanded) {
        controller.toggleDirectoryExpansion(controller.selectedItem!);
      } else if (controller.selectedItem!.children.isNotEmpty) {
        controller.clearSelectedItems();
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
        await controller.rename(item.getFullPath(), newName);
        MessageToastManager.showToast(context, 'Item renamed successfully');
      } catch (e) {
        MessageToastManager.showToast(context, 'Error renaming item: $e');
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
        _fileOperationManager.addToUndoStack([deleteOperation]);
        await controller.refreshDirectory();
        MessageToastManager.showToast(context,
            '${item.isDirectory ? 'Folder' : 'File'} deleted successfully');
      } catch (e) {
        MessageToastManager.showToast(context,
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
        _fileOperationManager.addToUndoStack(deleteOperations);
        await controller.refreshDirectory();
        MessageToastManager.showToast(
            context, '${items.length} item(s) deleted successfully');
      } catch (e) {
        MessageToastManager.showToast(context, 'Error deleting items: $e');
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
      MessageToastManager.showToast(context, 'Error selecting directory: $e');
    } finally {
      controller.setLoading(false);
    }
  }

  bool _isCtrlOrCmdPressed() {
    return RawKeyboard.instance.keysPressed
            .contains(LogicalKeyboardKey.controlLeft) ||
        RawKeyboard.instance.keysPressed
            .contains(LogicalKeyboardKey.controlRight) ||
        (Platform.isMacOS &&
            (RawKeyboard.instance.keysPressed
                    .contains(LogicalKeyboardKey.metaLeft) ||
                RawKeyboard.instance.keysPressed
                    .contains(LogicalKeyboardKey.metaRight)));
  }

  bool _isShiftPressed() {
    return RawKeyboard.instance.keysPressed
            .contains(LogicalKeyboardKey.shiftLeft) ||
        RawKeyboard.instance.keysPressed
            .contains(LogicalKeyboardKey.shiftRight);
  }

  void _handleShiftClickSelection(
      FileExplorerController controller, FileTreeItem item) {
    final allItems = _flattenItems(controller.rootItems);
    final selectedItemIndex = allItems.indexOf(controller.selectedItem!);
    final clickedItemIndex = allItems.indexOf(item);

    if (selectedItemIndex != -1 && clickedItemIndex != -1) {
      final startIndex = selectedItemIndex.compareTo(clickedItemIndex) < 0
          ? selectedItemIndex
          : clickedItemIndex;
      final endIndex = selectedItemIndex.compareTo(clickedItemIndex) < 0
          ? clickedItemIndex
          : selectedItemIndex;

      for (int i = startIndex; i <= endIndex; i++) {
        controller.selectItem(allItems[i]);
      }
    }
  }
}
