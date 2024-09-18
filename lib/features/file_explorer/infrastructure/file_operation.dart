import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';

enum OperationType { create, delete, move, copy }

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
        await controller.delete(destinationPath);
        return [
          FileOperation(OperationType.delete, destinationPath, sourcePath)
        ];
      case OperationType.delete:
        throw UnimplementedError('Restore deleted file not implemented');
      case OperationType.move:
        await controller.moveItem(destinationPath, sourcePath);
        return [FileOperation(OperationType.move, destinationPath, sourcePath)];
      case OperationType.copy:
        await controller.delete(destinationPath);
        return [
          FileOperation(OperationType.delete, destinationPath, sourcePath)
        ];
    }
  }

  Future<List<FileOperation>> redo(FileExplorerController controller) async {
    switch (type) {
      case OperationType.create:
        throw UnimplementedError('Recreate file not implemented');
      case OperationType.delete:
        await controller.delete(sourcePath);
        return [
          FileOperation(OperationType.delete, sourcePath, destinationPath)
        ];
      case OperationType.move:
        await controller.moveItem(sourcePath, destinationPath);
        return [FileOperation(OperationType.move, sourcePath, destinationPath)];
      case OperationType.copy:
        await controller.copyItem(sourcePath, destinationPath);
        return [FileOperation(OperationType.copy, sourcePath, destinationPath)];
    }
  }
}
