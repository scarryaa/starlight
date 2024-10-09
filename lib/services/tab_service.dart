import 'package:flutter/foundation.dart';
import 'package:starlight/services/file_service.dart';
import 'package:starlight/widgets/tab/tab.dart';

class TabService extends ChangeNotifier {
  final List<Tab> _tabs = [];
  FileService fileService;
  int? currentTabIndex;

  TabService({required this.fileService});

  List<Tab> get tabs => List.unmodifiable(_tabs);
  Tab? get currentTab =>
      currentTabIndex != null ? _tabs[currentTabIndex!] : null;

  void setCurrentTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      currentTabIndex = index;
      // Update isSelected for all tabs
      for (int i = 0; i < _tabs.length; i++) {
        _tabs[i] = Tab(
          isModified: _tabs[i].isModified,
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
      _tabs.add(Tab(
        path: path,
        content: fileContent,
        isSelected: true,
        isModified: false,
      ));
      setCurrentTab(_tabs.length - 1);
      notifyListeners();
    }
  }

  void removeTab(String path) {
    int index = _tabs.indexWhere((tab) => tab.path == path);
    if (index != -1) {
      _tabs.removeAt(index);

      if (_tabs.isNotEmpty) {
        currentTabIndex = index < _tabs.length ? index : _tabs.length - 1;
      } else {
        currentTabIndex = null;
      }

      notifyListeners();
    }
  }

  void updateTabContent(String path, String content) {
    final index = _tabs.indexWhere((tab) => tab.path == path);
    if (index != -1) {
      _tabs[index] = Tab(
        isModified: false,
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
