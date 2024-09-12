import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:starlight/utils/constants.dart';

class FileService {
  static Future<Directory> getInitialDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  static Future<String?> pickDirectory() async {
    return await FilePicker.platform.getDirectoryPath();
  }

  static Future<List<FileSystemEntity>> listDirectory(String path) async {
    final result =
        await platformChannel.invokeMethod('listDirectory', {'path': path});
    if (result is List) {
      return result.map((item) {
        final path = item['path'] as String;
        return item['isDirectory'] as bool ? Directory(path) : File(path);
      }).toList()
        ..sort((a, b) {
          if (a is Directory && b is File) return -1;
          if (a is File && b is Directory) return 1;
          return a.path.compareTo(b.path);
        });
    }
    throw Exception('Unexpected result type');
  }
}
