import 'package:flutter/foundation.dart';
import 'package:starlight/services/file_service.dart';
import 'package:starlight/widgets/tab/tab.dart';

class TabService extends ChangeNotifier {
  final List<Tab> _tabs = [];
  FileService fileService;
  int? currentTabIndex;

  TabService({required this.fileService});

  List<Tab> get tabs => List.unmodifiable(_tabs);

  void setCurrentTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      currentTabIndex = index;
      // Update isSelected for all tabs
      for (int i = 0; i < _tabs.length; i++) {
        _tabs[i] = Tab(
          path: _tabs[i].path,
          content: _tabs[i].content,
          isSelected: i == index,
        );
      }
      notifyListeners();
    }
  }

  void addTab(String path) {
    if (!_tabs.any((tab) => tab.path == path)) {
      final fileContent = fileService.readFile(path);
      _tabs.add(Tab(path: path, content: fileContent, isSelected: true));
      setCurrentTab(_tabs.length - 1);
      notifyListeners();
    }
  }

  void removeTab(String path) {
    int index = _tabs.indexWhere((tab) => tab.path == path);
    if (index != -1) {
      _tabs.removeAt(index);
      if (currentTabIndex != null) {
        if (currentTabIndex! >= _tabs.length) {
          currentTabIndex = _tabs.isEmpty ? null : _tabs.length - 1;
        } else if (currentTabIndex! > index) {
          currentTabIndex = currentTabIndex! - 1;
        }
      }
      notifyListeners();
    }
  }

  void updateTabContent(String path, String content) {
    final index = _tabs.indexWhere((tab) => tab.path == path);
    if (index != -1) {
      _tabs[index] = Tab(
        path: path,
        content: content,
        isSelected: _tabs[index].isSelected,
      );
      fileService.writeFile(path, content);
      notifyListeners();
    }
  }

  void reorderTabs(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final Tab tab = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, tab);

    if (currentTabIndex == oldIndex) {
      currentTabIndex = newIndex;
    } else if (currentTabIndex! > oldIndex && currentTabIndex! <= newIndex) {
      currentTabIndex = currentTabIndex! - 1;
    } else if (currentTabIndex! < oldIndex && currentTabIndex! >= newIndex) {
      currentTabIndex = currentTabIndex! + 1;
    }

    notifyListeners();
  }
}
