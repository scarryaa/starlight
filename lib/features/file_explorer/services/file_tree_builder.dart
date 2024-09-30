import 'package:flutter/material.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';
import 'package:starlight/features/file_explorer/presentation/widgets/file_tree_item_widget.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';

class FileTreeBuilder {
  final BuildContext context;
  final ScrollController scrollController;
  final Function(FileTreeItem, FileExplorerController) onItemSelected;
  final Function(FileTreeItem, FileExplorerController) onItemLongPress;
  final Function(
          BuildContext, TapUpDetails, FileTreeItem, FileExplorerController)
      onItemSecondaryTap;
  final Function(List<FileTreeItem>, FileTreeItem?, FileExplorerController)
      onItemsDrop;
  final double itemHeight;

  FileTreeBuilder({
    required this.context,
    required this.scrollController,
    required this.onItemSelected,
    required this.onItemLongPress,
    required this.onItemSecondaryTap,
    required this.onItemsDrop,
    this.itemHeight = 24.0,
  });

  List<Widget> buildFileTreeItems(
      List<FileTreeItem> items, FileExplorerController controller) {
    List<Widget> widgets = [];
    for (var item in items) {
      widgets.add(
        _buildDraggableItem(item, controller),
      );
      if (item.isDirectory && item.isExpanded) {
        widgets.addAll(buildFileTreeItems(item.children, controller));
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
          onItemSelected: (selectedItem) =>
              onItemSelected(selectedItem, controller),
          onItemLongPress: () => onItemLongPress(item, controller),
          onSecondaryTap: (details) =>
              onItemSecondaryTap(context, details, item, controller),
        ),
      ),
    );
  }

  Widget _buildDropTarget(
      FileTreeItem item, FileExplorerController controller) {
    return DragTarget<List<FileTreeItem>>(
      onWillAccept: (data) {
        return data != null &&
            data.every((draggedItem) => _canAcceptDrop(draggedItem, item));
      },
      onAccept: (data) => onItemsDrop(data, item, controller),
      builder: (context, candidateData, rejectedData) {
        return FileTreeItemWidget(
          key: ValueKey(item.path),
          item: item,
          isSelected: controller.isItemSelected(item),
          onItemSelected: (selectedItem) =>
              onItemSelected(selectedItem, controller),
          onItemLongPress: () => onItemLongPress(item, controller),
          onSecondaryTap: (details) =>
              onItemSecondaryTap(context, details, item, controller),
        );
      },
    );
  }

  bool _canAcceptDrop(FileTreeItem draggedItem, FileTreeItem targetItem) {
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
}
