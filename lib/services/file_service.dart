import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class FileService extends ChangeNotifier {
  late ValueNotifier<String> currentDirectoryNotifier;
  File? _currentFile;
  File? get currentFile => _currentFile;

  FileService(String? currentDirectory) {
    currentDirectoryNotifier = ValueNotifier<String>('');
  }

  set currentFile(File? file) {
    if (_currentFile != file) {
      _currentFile = file;
      notifyListeners();
    }
  }

  void setCurrentDirectory(String directory) {
    currentDirectoryNotifier.value = directory;
    refreshDirectory(directory);
    notifyListeners();
  }

  void refreshDirectory(String directory) {
    notifyListeners();
  }

  List<File> openFiles = [];

  String readFile(String path) {
    return File(path).readAsStringSync();
  }

  void writeFile(String path, String content) {
    File(path).writeAsStringSync(content);
    notifyListeners();
  }

  String getAbsolutePath(String path) {
    return File(path).absolute.path;
  }

  void selectFile(String path) {
    currentFile = File(path);
  }

  void openFile(String path) {
    File file = File(path);
    if (!openFiles.contains(file)) {
      openFiles.add(file);
      currentFile = file;
      notifyListeners();
    } else {
      currentFile = file;
    }
  }

  void closeFile(String path) {
    File file = File(path);
    openFiles.remove(file);
    if (currentFile == file) {
      currentFile = openFiles.isNotEmpty ? openFiles.last : null;
    }
    notifyListeners();
  }

  List<FileSystemEntity> listDirectory(String path) {
    return Directory(path).listSync();
  }

  void createFile(String path) {
    File(path).createSync();
    notifyListeners();
  }

  void createFolder(String path) {
    Directory(path).createSync();
    notifyListeners();
  }

  void renameFile(String oldPath, String newPath) {
    FileSystemEntity entity =
        FileSystemEntity.typeSync(oldPath) == FileSystemEntityType.directory
            ? Directory(oldPath)
            : File(oldPath);
    entity.renameSync(newPath);
    notifyListeners();
  }

  void deleteFile(String path) {
    if (FileSystemEntity.isDirectorySync(path)) {
      Directory(path).deleteSync(recursive: true);
    } else {
      File(path).deleteSync();
    }
    notifyListeners();
  }

  void copyPath(String path) {
    Clipboard.setData(ClipboardData(text: path));
  }

  void copyRelativePath(String path, String basePath) {
    String relativePath = p.relative(path, from: basePath);
    Clipboard.setData(ClipboardData(text: relativePath));
  }

  Future<void> revealInFinder(String path) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', path]);
      } else if (Platform.isLinux) {
        final directory = p.dirname(path);
        await Process.run('xdg-open', [directory]);
      } else {
        print('Revealing files is not supported on this platform.');
      }
    } catch (e) {
      print('Error revealing file: $e');
    }
  }

  List<FileSystemEntity> _clipboard = [];
  bool _isCut = false;

  void copyFiles(List<String> paths) {
    _clipboard = paths
        .map((path) => FileSystemEntity.isDirectorySync(path)
            ? Directory(path)
            : File(path))
        .toList();
    _isCut = false;
  }

  void cutFiles(List<String> paths) {
    _clipboard = paths
        .map((path) => FileSystemEntity.isDirectorySync(path)
            ? Directory(path)
            : File(path))
        .toList();
    _isCut = true;
  }

  void pasteFiles(String destinationPath,
      {String Function(String)? onNameConflict}) {
    for (var entity in _clipboard) {
      final String baseName = p.basename(entity.path);
      String newPath = p.join(destinationPath, baseName);

      if (FileSystemEntity.typeSync(newPath) != FileSystemEntityType.notFound) {
        if (onNameConflict != null) {
          newPath = onNameConflict(newPath);
        } else {
          newPath = _getUniqueFilePath(newPath);
        }
      }

      if (entity is File) {
        if (_isCut) {
          entity.renameSync(newPath);
        } else {
          File(entity.path).copySync(newPath);
        }
      } else if (entity is Directory) {
        if (_isCut) {
          entity.renameSync(newPath);
        } else {
          _copyDirectory(entity.path, newPath);
        }
      }
    }

    if (_isCut) {
      _clipboard.clear();
    }

    notifyListeners();
  }

  String _getUniqueFilePath(String originalPath) {
    String baseName = p.basenameWithoutExtension(originalPath);
    String extension = p.extension(originalPath);
    String directory = p.dirname(originalPath);
    int copyNumber = 1;
    String newPath = originalPath;

    while (
        FileSystemEntity.typeSync(newPath) != FileSystemEntityType.notFound) {
      newPath = p.join(directory, '$baseName (${copyNumber++})$extension');
    }

    return newPath;
  }

  void _copyDirectory(String source, String destination) {
    Directory(destination).createSync(recursive: true);
    for (var entity in Directory(source).listSync(recursive: false)) {
      if (entity is Directory) {
        _copyDirectory(
            entity.path, p.join(destination, p.basename(entity.path)));
      } else if (entity is File) {
        entity.copySync(p.join(destination, p.basename(entity.path)));
      }
    }
  }
}
