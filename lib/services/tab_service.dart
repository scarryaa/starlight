import 'package:flutter/foundation.dart';
import 'package:starlight/models/tab.dart';
import 'package:starlight/services/file_service.dart';

class TabService extends ChangeNotifier {
  List<Tab> _tabs = [];
  FileService fileService;

  TabService({required this.fileService});

  List<Tab> get tabs => List.unmodifiable(_tabs);

  void addTab(String path) {
    if (!_tabs.any((tab) => tab.path == path)) {
      final fileContent = fileService.readFile(path);
      _tabs.add(Tab(path: path, content: fileContent));
      notifyListeners();
    }
  }

  void removeTab(String path) {
    _tabs.removeWhere((tab) => tab.path == path);
    notifyListeners();
  }

  void updateTabContent(String path, String content) {
    final index = _tabs.indexWhere((tab) => tab.path == path);
    if (index != -1) {
      _tabs[index] = Tab(path: path, content: content);
      fileService.writeFile(path, content);
      notifyListeners();
    }
  }
}
