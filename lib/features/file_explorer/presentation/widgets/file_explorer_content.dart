import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';
import 'package:starlight/features/file_explorer/presentation/widgets/directory_selection_prompt.dart';
import 'package:starlight/features/file_explorer/application/file_operation_manager.dart';
import 'package:starlight/features/file_explorer/presentation/widgets/context_menu_builder.dart';
import 'package:starlight/features/file_explorer/presentation/widgets/quick_action_bar.dart';
import 'package:starlight/features/file_explorer/services/file_operation_handler.dart';
import 'package:starlight/features/file_explorer/services/file_tree_builder.dart';
import 'package:starlight/features/file_explorer/services/keyboard_navigation_handler.dart';
import 'package:starlight/features/file_explorer/services/search_handler.dart';
import 'package:starlight/features/toasts/message_toast.dart';
import 'package:starlight/features/file_explorer/infrastructure/services/file_service.dart';
import 'package:starlight/services/ui_service.dart';

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
  late FileTreeBuilder _fileTreeBuilder;
  late FileOperationHandler _fileOperationHandler;
  late KeyboardNavigationHandler _keyboardNavigationHandler;
  late SearchHandler _searchHandler;
  List<FileTreeItem> _filteredItems = [];
  bool _isSearching = false;
  bool _isSearchBarVisible = false;
  final FocusNode _searchFocusNode = FocusNode();
  FileTreeItem? _newItemParent;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeHandlers();
    _addListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateUIServiceDirectory();
    });
  }

  void _updateUIServiceDirectory() {
    final controller = context.read<FileExplorerController>();
    final uiService = context.read<UIService>();
    if (controller.currentDirectory != null) {
      uiService.currentDirectoryPath = controller.currentDirectory!.path;
    }
  }

  void _initializeControllers() {
    _scrollController = ScrollController();
    _explorerFocusNode = FocusNode();
    _fileOperationManager = FileOperationManager(context);
    _searchController = TextEditingController();
  }

  void _initializeHandlers() {
    _fileTreeBuilder = FileTreeBuilder(
      context: context, // Add this line
      scrollController: _scrollController,
      onItemSelected: (item, controller) => _handleItemTap(item, controller),
      onItemLongPress: (item, controller) =>
          _handleItemLongPress(item, controller),
      onItemSecondaryTap: (context, details, item, controller) =>
          _handleItemSecondaryTap(context, details, item, controller),
      onItemsDrop: (items, target, controller) =>
          _handleItemsDrop(items, target, controller),
    );
    _fileOperationHandler =
        FileOperationHandler(context, _fileOperationManager);
    _keyboardNavigationHandler = KeyboardNavigationHandler(
      scrollToSelectedItem: _scrollToSelectedItem,
      onFileSelected: (item) => widget.onFileSelected(item.entity as File),
      toggleSearchBar: _toggleSearchBar,
    );
    _searchHandler = SearchHandler(
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      setSearching: (value) => setState(() => _isSearching = value),
      setFilteredItems: (items) => setState(() => _filteredItems = items),
    );
  }

  void _addListeners() {
    _explorerFocusNode.addListener(_onExplorerFocusChange);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _explorerFocusNode.dispose();
  }

  void _onExplorerFocusChange() {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickActionBar(),
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

  Widget _buildQuickActionBar() {
    return Consumer<FileExplorerController>(
      builder: (context, controller, child) => QuickActionBar(
        onNewFolder: () => _startCreatingNewItem(false, null),
        onNewFile: () => _startCreatingNewItem(true, null),
        onCopy: _copyItems,
        onCut: _cutItems,
        onPaste: (controller) => _fileOperationManager.pasteItems(controller),
        onExpandAll: () async {
          await controller.expandAll();
          MessageToastManager.showToast(context, 'All directories expanded');
        },
        onCollapseAll: () {
          controller.collapseAll();
          MessageToastManager.showToast(context, 'All directories collapsed');
        },
        onSearch: _toggleSearchBar,
        onToggleSystemFiles: () =>
            context.read<FileExplorerController>().toggleHideSystemFiles(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return _searchHandler.buildSearchBar();
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
        onKey: (node, event) =>
            _keyboardNavigationHandler.handleKeyPress(event, controller),
        child: GestureDetector(
          onTap: () => _explorerFocusNode.requestFocus(),
          child: DragTarget<List<FileTreeItem>>(
            onWillAccept: (data) {
              setState(() {
                _highlightedItem = null;
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
                  ),
                ),
                child: GestureDetector(
                  onTap: () => _handleEmptySpaceLeftClick(controller),
                  onSecondaryTapUp: (details) =>
                      _handleEmptySpaceRightClick(context, details, controller),
                  behavior: HitTestBehavior.opaque,
                  child: Scrollbar(
                    controller: _scrollController,
                    child: ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        ..._fileTreeBuilder.buildFileTreeItems(
                          _isSearching ? _filteredItems : controller.rootItems,
                          controller,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
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
      _fileOperationManager,
    );
  }

  void _toggleSearchBar() {
    setState(() {
      _isSearchBarVisible = !_isSearchBarVisible;
      _isSearching = _isSearchBarVisible;

      if (_isSearchBarVisible) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        _filteredItems = [];
        _explorerFocusNode.requestFocus();
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
      await controller.refreshDirectoryImmediately();
      setState(() {});
      MessageToastManager.showToast(context, 'Items moved successfully');
    } catch (e) {
      MessageToastManager.showToast(context, 'Error moving items: $e');
    }
  }

  void _startCreatingNewItem(bool isFile, FileTreeItem? parentItem) {
    setState(() {
      _newItemParent = parentItem;
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
        controller.toggleDirectoryExpansion(item).then((_) {
          controller.updateGitStatus();
        });
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
      _fileOperationManager,
      _isSearching,
      _isSearching ? _showInExplorer : null,
    );
  }

  void _showInExplorer(FileTreeItem item) {
    final controller = context.read<FileExplorerController>();
    _closeSearch();
    _navigateToItem(item, controller);
  }

  void _navigateToItem(FileTreeItem item, FileExplorerController controller) {
    FileTreeItem? parent = item.parent;
    List<FileTreeItem> pathToExpand = [];

    while (parent != null) {
      pathToExpand.insert(0, parent);
      parent = parent.parent;
    }

    for (var folderItem in pathToExpand) {
      if (!folderItem.isExpanded) {
        controller.toggleDirectoryExpansion(folderItem);
      }
    }

    controller.clearSelectedItems();
    controller.setSelectedItem(item);
    _scrollToSelectedItem(ScrollDirection.forward);
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

        await controller.refreshDirectoryImmediately();
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
      _newItemParent = null;
      _explorerFocusNode.requestFocus();
    });
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

  List<FileTreeItem> _flattenItems(List<FileTreeItem> items) {
    return items.expand((item) {
      final flattened = [item];
      if (item.isDirectory && item.isExpanded) {
        flattened.addAll(_flattenItems(item.children));
      }
      return flattened;
    }).toList();
  }

  void _copyItems(BuildContext context, FileExplorerController controller) {
    _fileOperationHandler.copyItems(controller);
  }

  void _cutItems(BuildContext context, FileExplorerController controller) {
    _fileOperationHandler.cutItems(controller);
  }

  Future<void> _deleteItem(BuildContext context,
      FileExplorerController controller, FileTreeItem item) async {
    await _fileOperationHandler.deleteItems(controller, [item], false);
  }

  Future<void> _deleteItems(
      BuildContext context,
      FileExplorerController controller,
      List<FileTreeItem> items,
      bool forceDelete) async {
    await _fileOperationHandler.deleteItems(controller, items, forceDelete);
  }

  Future<void> _renameItem(BuildContext context,
      FileExplorerController controller, FileTreeItem item) async {
    await _fileOperationHandler.renameItem(controller, item);
  }

  void _copyPath(BuildContext context, bool relative) {
    _fileOperationHandler.copyPath(relative);
  }

  Future<void> _revealInFinder(BuildContext context) async {
    await _fileOperationHandler.revealInFinder();
  }

  Future<void> _pickDirectory() async {
    final controller = context.read<FileExplorerController>();
    final uiService = context.read<UIService>();
    try {
      String? selectedDirectory = await FileService.pickDirectory();
      if (selectedDirectory != null) {
        await controller.setDirectory(Directory(selectedDirectory));
        widget.onDirectorySelected(selectedDirectory);
        await controller.updateGitStatus();

        // Update the UIService with the new main directory path
        uiService.currentDirectoryPath = selectedDirectory;
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

  void _closeSearch() {
    setState(() {
      _isSearchBarVisible = false;
      _isSearching = false;
      _filteredItems = [];
    });
    _searchController.clear();
    _explorerFocusNode.requestFocus();
  }
}
