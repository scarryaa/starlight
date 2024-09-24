import 'dart:io';
import 'package:path/path.dart' as _path;
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';

enum OperationType { create, delete, move, copy, restore }

class FileOperation {
  final OperationType type;
  final String sourcePath;
  final String destinationPath;

  FileOperation(this.type, this.sourcePath, this.destinationPath);

  static FileOperation combine(List<FileOperation> operations) {
    if (operations.length == 1) return operations.first;
    return FileOperation(OperationType.move, 'multiple', 'multiple');
  }

  Future<List<FileOperation>> undo(FileExplorerController controller) async {
    switch (type) {
      case OperationType.create:
        return _undoCreate();
      case OperationType.delete:
        return _undoDelete(controller);
      case OperationType.move:
        return _undoMove();
      case OperationType.copy:
        return _undoCopy();
      case OperationType.restore:
        return _undoRestore(controller);
    }
  }

  Future<List<FileOperation>> redo(FileExplorerController controller) async {
    switch (type) {
      case OperationType.create:
        return _redoCreate();
      case OperationType.delete:
        return _redoDelete(controller);
      case OperationType.move:
        return _redoMove();
      case OperationType.copy:
        return _redoCopy(controller);
      case OperationType.restore:
        return _redoRestore(controller);
    }
  }

  Future<List<FileOperation>> _undoCreate() async {
    await _deleteFileSystemEntity(destinationPath);
    return [FileOperation(OperationType.delete, destinationPath, sourcePath)];
  }

  Future<List<FileOperation>> _undoMove() async {
    await _moveFileSystemEntity(destinationPath, sourcePath);
    return [FileOperation(OperationType.move, destinationPath, sourcePath)];
  }

  Future<List<FileOperation>> _undoCopy() async {
    await _deleteFileSystemEntity(destinationPath);
    return [FileOperation(OperationType.delete, destinationPath, sourcePath)];
  }

  Future<List<FileOperation>> _undoRestore(
      FileExplorerController controller) async {
    await controller.moveToTemp(sourcePath);
    return [FileOperation(OperationType.delete, sourcePath, destinationPath)];
  }

  Future<List<FileOperation>> _redoCreate() async {
    await _createFileSystemEntity(destinationPath);
    return [FileOperation(OperationType.create, sourcePath, destinationPath)];
  }

  Future<List<FileOperation>> _redoDelete(
      FileExplorerController controller) async {
    if (await FileSystemEntity.type(sourcePath) ==
        FileSystemEntityType.notFound) {
      return [];
    }
    await controller.deleteToTemp(sourcePath);
    return [FileOperation(OperationType.delete, sourcePath, destinationPath)];
  }

  Future<List<FileOperation>> _undoDelete(
      FileExplorerController controller) async {
    await controller.restoreFromTemp(sourcePath);
    return [FileOperation(OperationType.restore, destinationPath, sourcePath)];
  }

  Future<List<FileOperation>> _redoMove() async {
    await _moveFileSystemEntity(sourcePath, destinationPath);
    return [FileOperation(OperationType.move, sourcePath, destinationPath)];
  }

  Future<List<FileOperation>> _redoCopy(
      FileExplorerController controller) async {
    await controller.copyItem(sourcePath, destinationPath);
    return [FileOperation(OperationType.copy, sourcePath, destinationPath)];
  }

  Future<List<FileOperation>> _redoRestore(
      FileExplorerController controller) async {
    if (await File(controller.getTempPath(destinationPath)).exists()) {
      await controller.restoreFromTemp(destinationPath);
      return [
        FileOperation(OperationType.restore, destinationPath, sourcePath)
      ];
    } else {
      return [];
    }
  }

  Future<void> _deleteFileSystemEntity(String path) async {
    if (await FileSystemEntity.isDirectory(path)) {
      await Directory(path).delete(recursive: true);
    } else if (await FileSystemEntity.isFile(path)) {
      await File(path).delete();
    }
  }

  Future<void> _moveFileSystemEntity(String from, String to) async {
    if (await FileSystemEntity.isDirectory(from)) {
      await Directory(from).rename(to);
    } else if (await FileSystemEntity.isFile(from)) {
      await File(from).rename(to);
    }
  }

  Future<void> _createFileSystemEntity(String path) async {
    if (_path.extension(path).isNotEmpty) {
      await File(path).create(recursive: true);
    } else {
      await Directory(path).create(recursive: true);
    }
  }
}
