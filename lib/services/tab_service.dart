import 'package:flutter/foundation.dart';
import 'package:starlight/features/editor/models/cursor_position.dart';
import 'package:starlight/services/file_service.dart';
import 'package:starlight/widgets/tab/tab.dart';

class TabService extends ChangeNotifier {
  final List<Tab> _tabs = [];
  FileService fileService;
  final ValueNotifier<int?> currentTabIndexNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<CursorPosition> cursorPositionNotifier =
      ValueNotifier(const CursorPosition(line: 0, column: 0));

  TabService({required this.fileService});

  List<Tab> get tabs => List.unmodifiable(_tabs);

  Tab? get currentTab => currentTabIndexNotifier.value != null
      ? _tabs[currentTabIndexNotifier.value!]
      : null;

  void setCurrentTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      currentTabIndexNotifier.value = index;
      cursorPositionNotifier.value = _tabs[index].cursorPosition;
      // Update isSelected for all tabs
      for (int i = 0; i < _tabs.length; i++) {
        _tabs[i] = _tabs[i].copyWith(isSelected: i == index);
      }
      notifyListeners();
    }
  }

  void addTab(String fileName, String path, String fullAbsolutePath) {
    if (!_tabs.any((tab) => tab.fullPath == path)) {
      final fileContent = fileService.readFile(path);
      _tabs.add(Tab(
        fullAbsolutePath: fullAbsolutePath,
        fullPath: path,
        path: fileName,
        content: fileContent,
        isSelected: true,
        isModified: false,
      ));
      setCurrentTab(_tabs.length - 1);
      notifyListeners();
    } else {
      // If the tab already exists, just set it as the current tab
      int existingIndex = _tabs.indexWhere((tab) => tab.fullPath == path);
      setCurrentTab(existingIndex);
    }
  }

  void removeTab(String path) {
    int index = _tabs.indexWhere((tab) => tab.path == path);
    if (index != -1) {
      _tabs.removeAt(index);
      if (_tabs.isNotEmpty) {
        currentTabIndexNotifier.value =
            index < _tabs.length ? index : _tabs.length - 1;
      } else {
        currentTabIndexNotifier.value = null;
      }
      notifyListeners();
    }
  }

  void updateTabContent(String path, String content,
      {required bool isModified}) {
    final index = _tabs.indexWhere((tab) => tab.path == path);
    if (index != -1) {
      _tabs[index] = Tab(
        fullAbsolutePath: _tabs[index].fullAbsolutePath,
        fullPath: _tabs[index].fullPath,
        path: path,
        content: content,
        isSelected: _tabs[index].isSelected,
        isModified: isModified,
        cursorPosition: _tabs[index].cursorPosition,
      );
      notifyListeners();
    }
  }

  void reorderTabs(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final Tab tab = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, tab);
    if (currentTabIndexNotifier.value == oldIndex) {
      currentTabIndexNotifier.value = newIndex;
    } else if (currentTabIndexNotifier.value! > oldIndex &&
        currentTabIndexNotifier.value! <= newIndex) {
      currentTabIndexNotifier.value = currentTabIndexNotifier.value! - 1;
    } else if (currentTabIndexNotifier.value! < oldIndex &&
        currentTabIndexNotifier.value! >= newIndex) {
      currentTabIndexNotifier.value = currentTabIndexNotifier.value! + 1;
    }
    notifyListeners();
  }

  void setTabModified(String path, bool isModified) {
    final index = _tabs.indexWhere((tab) => tab.path == path);
    if (index != -1) {
      _tabs[index] = Tab(
        fullAbsolutePath: _tabs[index].fullAbsolutePath,
        fullPath: _tabs[index].fullPath,
        isModified: isModified,
        path: _tabs[index].path,
        content: _tabs[index].content,
        isSelected: _tabs[index].isSelected,
        cursorPosition: _tabs[index].cursorPosition,
      );
      notifyListeners();
    }
  }

  void updateCursorPosition(String path, CursorPosition position) {
    final index = _tabs.indexWhere((tab) => tab.path == path);
    if (index != -1 && _tabs[index].cursorPosition != position) {
      _tabs[index] = _tabs[index].copyWith(cursorPosition: position);
      if (index == currentTabIndexNotifier.value) {
        cursorPositionNotifier.value = position;
      }
    }
  }
}
