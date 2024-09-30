import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/features/file_explorer/application/file_operation_manager.dart';
import 'package:starlight/features/file_explorer/infrastructure/file_operation.dart';
import 'package:starlight/features/toasts/message_toast.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class FileOperationHandler {
  final BuildContext context;
  final FileOperationManager fileOperationManager;

  FileOperationHandler(this.context, this.fileOperationManager);

  Future<void> copyItems(FileExplorerController controller) async {
    final selectedItems = controller.selectedItems;
    if (selectedItems.isNotEmpty) {
      controller.setCopiedItems(selectedItems);
      MessageToastManager.showToast(
          context, '${selectedItems.length} item(s) copied');
    } else {
      MessageToastManager.showToast(context, 'No items selected');
    }
  }

  Future<void> cutItems(FileExplorerController controller) async {
    final selectedItems = controller.selectedItems;
    if (selectedItems.isNotEmpty) {
      controller.setCutItems(selectedItems);
      MessageToastManager.showToast(
          context, '${selectedItems.length} item(s) cut');
    } else {
      MessageToastManager.showToast(context, 'No items selected');
    }
  }

  Future<void> pasteItems(FileExplorerController controller) async {
    await fileOperationManager.pasteItems(controller);
    await controller.refreshDirectoryImmediately();
  }

  Future<void> deleteItems(FileExplorerController controller,
      List<FileTreeItem> items, bool forceDelete) async {
    bool confirmDelete = forceDelete;
    if (!forceDelete) {
      confirmDelete = await _showDeleteConfirmationDialog(items);
    }

    if (confirmDelete) {
      try {
        List<FileOperation> deleteOperations = [];
        for (var item in items) {
          String tempPath = await controller.moveToTemp(item.path);
          deleteOperations
              .add(FileOperation(OperationType.delete, item.path, tempPath));
        }
        fileOperationManager.addToUndoStack(deleteOperations);
        await controller.refreshDirectoryImmediately();
        MessageToastManager.showToast(
            context, '${items.length} item(s) deleted successfully');
      } catch (e) {
        MessageToastManager.showToast(context, 'Error deleting items: $e');
      }
    }
  }

  Future<void> renameItem(
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

  void copyPath(bool relative) {
    final currentPath =
        context.read<FileExplorerController>().currentDirectory!.path;
    final pathToCopy = relative
        ? path.relative(currentPath, from: path.dirname(currentPath))
        : currentPath;
    Clipboard.setData(ClipboardData(text: pathToCopy));
    MessageToastManager.showToast(
        context, '${relative ? 'Relative path' : 'Path'} copied to clipboard');
  }

  Future<void> revealInFinder() async {
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

  Future<bool> _showDeleteConfirmationDialog(List<FileTreeItem> items) async {
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
}
