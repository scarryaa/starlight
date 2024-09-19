import 'package:flutter/material.dart';
import 'package:starlight/features/file_explorer/infrastructure/file_operation.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/features/toasts/error_toast.dart';
import 'package:starlight/features/toasts/message_toast.dart';

class FileOperationManager {
  final BuildContext context;
  final List<FileOperation> _undoStack = [];
  final List<FileOperation> _redoStack = [];
  late ErrorToastManager _errorToastManager;

  FileOperationManager(this.context) {
    _errorToastManager = ErrorToastManager(context);
  }

  Future<void> pasteItems(FileExplorerController controller) async {
    try {
      List<FileOperation> pasteOperations =
          await controller.pasteItems(controller.currentDirectory!.path);
      addToUndoStack(pasteOperations);
      await controller.refreshDirectory();
      MessageToastManager.showToast(context, 'Items pasted successfully');
    } catch (e) {
      _errorToastManager.showErrorToast(
          controller.currentDirectory!.path, 'Error pasting items: $e');
    }
  }

  void addToUndoStack(List<FileOperation> operations) {
    _undoStack.add(FileOperation.combine(operations));
    _redoStack.clear();
  }

  Future<void> undo(FileExplorerController controller) async {
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

  Future<void> redo(FileExplorerController controller) async {
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
}
