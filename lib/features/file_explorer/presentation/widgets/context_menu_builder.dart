import 'package:flutter/material.dart';
import 'package:starlight/features/context_menu/context_menu.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';
import 'package:starlight/features/file_explorer/application/file_operation_manager.dart';

List<ContextMenuItem> buildContextMenuItems(
    BuildContext context,
    FileExplorerController controller,
    FileTreeItem? item,
    Function(bool, FileTreeItem?) startCreatingNewItem,
    Function(BuildContext, FileExplorerController) copyItems,
    Function(BuildContext, FileExplorerController) cutItems,
    Function(BuildContext, FileExplorerController, FileTreeItem) renameItem,
    Function(BuildContext, FileExplorerController, FileTreeItem) deleteItem,
    Function(BuildContext, FileExplorerController, List<FileTreeItem>, bool)
        deleteItems,
    Function(BuildContext, bool) copyPath,
    Function(BuildContext) revealInFinder,
    Function(String) onOpenInTerminal,
    FileOperationManager fileOperationManager) {
  final List<ContextMenuItem> menuItems = [];
  final bool isMultiSelectMode = controller.isMultiSelectMode;
  final List<FileTreeItem> selectedItems = controller.selectedItems;

  if (item == null) {
    menuItems.addAll([
      ContextMenuItem(
        title: 'New File',
        onTap: () => startCreatingNewItem(true, null),
      ),
      ContextMenuItem(
        title: 'New Folder',
        onTap: () => startCreatingNewItem(false, null),
      ),
      ContextMenuItem(
        title: 'Refresh',
        onTap: () => controller.refreshDirectory(),
      ),
      ContextMenuItem(
        title: 'Paste',
        onTap: () => fileOperationManager.pasteItems(controller),
      ),
    ]);
  } else {
    if (item.isDirectory) {
      menuItems.addAll([
        ContextMenuItem(
          title: 'New File',
          onTap: () => startCreatingNewItem(true, item),
        ),
        ContextMenuItem(
          title: 'New Folder',
          onTap: () => startCreatingNewItem(false, item),
        ),
      ]);
    } else {
      menuItems.addAll([
        ContextMenuItem(
          title: 'New File',
          onTap: () => startCreatingNewItem(true, item.parent),
        ),
        ContextMenuItem(
          title: 'New Folder',
          onTap: () => startCreatingNewItem(false, item.parent),
        ),
      ]);
    }
    menuItems.addAll([
      ContextMenuItem(
        title: 'Copy',
        onTap: () => copyItems(context, controller),
      ),
      ContextMenuItem(
        title: 'Cut',
        onTap: () => cutItems(context, controller),
      ),
      ContextMenuItem(
        title: 'Rename',
        onTap: () => renameItem(context, controller, item),
      ),
      ContextMenuItem(
        title: "Delete",
        onTap: () {
          if (isMultiSelectMode && selectedItems.isNotEmpty) {
            deleteItems(context, controller, selectedItems, false);
          } else {
            deleteItem(context, controller, item);
          }
        },
      ),
    ]);
  }

  menuItems.addAll([
    ContextMenuItem(
      title: 'Copy Path',
      onTap: () => copyPath(context, false),
    ),
    ContextMenuItem(
      title: 'Copy Relative Path',
      onTap: () => copyPath(context, true),
    ),
    ContextMenuItem(
      title: 'Reveal in Finder',
      onTap: () => revealInFinder(context),
    ),
    ContextMenuItem(
      title: 'Open in Integrated Terminal',
      onTap: () => onOpenInTerminal(controller.currentDirectory!.path),
    ),
  ]);

  return menuItems;
}

void showContextMenu(
    BuildContext context,
    RelativeRect position,
    FileExplorerController controller,
    FileTreeItem? item,
    Function(bool, FileTreeItem?) startCreatingNewItem,
    Function(BuildContext, FileExplorerController) copyItems,
    Function(BuildContext, FileExplorerController) cutItems,
    Function(BuildContext, FileExplorerController, FileTreeItem) renameItem,
    Function(BuildContext, FileExplorerController, FileTreeItem) deleteItem,
    Function(BuildContext, FileExplorerController, List<FileTreeItem>, bool)
        deleteItems,
    Function(BuildContext, bool) copyPath,
    Function(BuildContext) revealInFinder,
    Function(String) onOpenInTerminal,
    FileOperationManager fileOperationManager) {
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
          items: buildContextMenuItems(
            context,
            controller,
            item,
            startCreatingNewItem,
            copyItems,
            cutItems,
            renameItem,
            deleteItem,
            deleteItems,
            copyPath,
            revealInFinder,
            onOpenInTerminal,
            fileOperationManager,
          ),
        ),
      ),
    ],
  );
}
