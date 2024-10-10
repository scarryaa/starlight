import 'package:flutter/material.dart' hide Tab;
import 'package:flutter/services.dart';
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

  Future<bool> onCloseRequest(BuildContext context, String path) async {
    final index = _tabs.indexWhere((tab) => tab.path == path);
    if (index != -1 && _tabs[index].isModified) {
      final result = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Unsaved Changes'),
            content: Text(
                'The file "${_tabs[index].path}" has unsaved changes. What would you like to do?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop('cancel'),
              ),
              TextButton(
                child: const Text('Close without Saving'),
                onPressed: () => Navigator.of(context).pop('close'),
              ),
              TextButton(
                child: const Text('Save and Close'),
                onPressed: () => Navigator.of(context).pop('save'),
              ),
            ],
          );
        },
      );

      switch (result) {
        case 'close':
          return true;
        case 'save':
          await _saveAndClose(index);
          return true;
        case 'cancel':
        default:
          return false;
      }
    }
    return true;
  }

  Future<void> _saveAndClose(int index) async {
    final tab = _tabs[index];
    fileService.writeFile(tab.fullPath, tab.content);
    _tabs[index] = tab.copyWith(isModified: false);
    notifyListeners();
  }

  void removeTab(String path) async {
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

  Future<void> closeLeft(BuildContext context, int index) async {
    if (index > 0) {
      for (int i = 0; i < index; i++) {
        if (!_tabs[i].isPinned &&
            !await onCloseRequest(context, _tabs[i].path)) {
          return;
        }
      }
      _tabs.removeWhere((tab) => _tabs.indexOf(tab) < index && !tab.isPinned);
      if (currentTabIndexNotifier.value! >= index) {
        currentTabIndexNotifier.value = currentTabIndexNotifier.value! - index;
      } else {
        currentTabIndexNotifier.value = 0;
      }
      notifyListeners();
    }
  }

  Future<void> closeRight(BuildContext context, int index) async {
    if (index < _tabs.length - 1) {
      for (int i = index + 1; i < _tabs.length; i++) {
        if (!_tabs[i].isPinned &&
            !await onCloseRequest(context, _tabs[i].path)) {
          return;
        }
      }
      _tabs.removeWhere((tab) => _tabs.indexOf(tab) > index && !tab.isPinned);
      if (currentTabIndexNotifier.value! > index) {
        currentTabIndexNotifier.value = index;
      }
      notifyListeners();
    }
  }

  Future<void> closeOtherTabs(BuildContext context, int index) async {
    for (int i = 0; i < _tabs.length; i++) {
      if (i != index &&
          !_tabs[i].isPinned &&
          !await onCloseRequest(context, _tabs[i].path)) {
        return;
      }
    }
    _tabs.removeWhere((tab) => _tabs.indexOf(tab) != index && !tab.isPinned);
    if (_tabs.isNotEmpty) {
      currentTabIndexNotifier.value = 0;
      cursorPositionNotifier.value = _tabs[0].cursorPosition;
    } else {
      currentTabIndexNotifier.value = null;
    }
    notifyListeners();
  }

  Future<void> closeAllTabs(BuildContext context) async {
    for (var tab in _tabs) {
      if (!tab.isPinned && !await onCloseRequest(context, tab.path)) {
        return;
      }
    }
    _tabs.removeWhere((tab) => !tab.isPinned);
    currentTabIndexNotifier.value = null;
    cursorPositionNotifier.value = const CursorPosition(line: 0, column: 0);
    notifyListeners();
  }

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
        onCloseRequest: onCloseRequest,
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

  void pinTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _tabs[index] = _tabs[index].copyWith(isPinned: true);
      // Move pinned tab to the start of the list
      if (index > 0) {
        final pinnedTab = _tabs.removeAt(index);
        _tabs.insert(0, pinnedTab);
        if (currentTabIndexNotifier.value == index) {
          currentTabIndexNotifier.value = 0;
        } else if (currentTabIndexNotifier.value! < index) {
          currentTabIndexNotifier.value = currentTabIndexNotifier.value! + 1;
        }
      }
      notifyListeners();
    }
  }

  void unpinTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _tabs[index] = _tabs[index].copyWith(isPinned: false);
      notifyListeners();
    }
  }

  void copyRelativePath(int index) {
    if (index >= 0 && index < _tabs.length) {
      Clipboard.setData(ClipboardData(text: _tabs[index].fullPath));
    } else {
      print('Invalid tab index');
    }
  }

  void copyPath(int index) {
    if (index >= 0 && index < _tabs.length) {
      Clipboard.setData(ClipboardData(text: _tabs[index].fullAbsolutePath));
    } else {
      print('Invalid tab index');
    }
  }

  void updateTabContent(String path, String content,
      {required bool isModified}) {
    final index = _tabs.indexWhere((tab) => tab.path == path);
    if (index != -1) {
      _tabs[index] = Tab(
        onCloseRequest: _tabs[index].onCloseRequest,
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
        onCloseRequest: _tabs[index].onCloseRequest,
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
