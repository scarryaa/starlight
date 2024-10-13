import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Tab;
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/models/cursor_position.dart';
import 'package:starlight/services/caret_position_notifier.dart';
import 'package:starlight/services/file_service.dart';
import 'package:starlight/widgets/tab/tab.dart';

class TabService extends ChangeNotifier {
  final List<Tab> _tabs = [];
  FileService fileService;
  final ValueNotifier<int?> currentTabIndexNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<CursorPosition> cursorPositionNotifier =
      ValueNotifier(const CursorPosition(line: 0, column: 0));
  CaretPositionNotifier caretPositionNotifier;

  TabService({required this.fileService, required this.caretPositionNotifier});

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

  Future<void> saveTab(BuildContext context, {int? index}) async {
    final tabIndex = index ?? currentTabIndexNotifier.value;
    if (tabIndex == null || tabIndex < 0 || tabIndex >= _tabs.length) {
      print("Invalid tab index for saving");
      return;
    }

    final tab = _tabs[tabIndex];
    String filePath = tab.fullAbsolutePath;

    // Check if the file is new (hasn't been saved to disk yet)
    if (!await File(filePath).exists()) {
      // Prompt for a save location
      String? selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save File',
        fileName: p.basename(filePath),
      );

      if (selectedPath == null) {
        // User cancelled the save dialog
        return;
      }

      filePath = selectedPath;
    }

    // Save the file
    fileService.writeFile(filePath, tab.content);

    // Update the tab information
    _tabs[tabIndex] = tab.copyWith(
      isModified: false,
      fullAbsolutePath: filePath,
      fullPath: p.relative(filePath,
          from: fileService.currentDirectoryNotifier.value),
      path: p.basename(filePath),
    );

    notifyListeners();
  }

  void createNewFile(BuildContext context) {
    final newFileName = 'Untitled-${_tabs.length + 1}.txt';
    final newFilePath =
        p.join(fileService.currentDirectoryNotifier.value, newFileName);
    addTab(newFileName, newFileName, newFilePath, content: '');
  }

  void addTab(String fileName, String path, String fullAbsolutePath,
      {String? content}) {
    int existingIndex =
        _tabs.indexWhere((tab) => tab.fullPath == fullAbsolutePath);

    if (existingIndex == -1) {
      // Tab doesn't exist, create a new one
      final fileContent = content ??
          (File(fullAbsolutePath).existsSync()
              ? fileService.readFile(fullAbsolutePath)
              : '');
      _tabs.add(Tab(
        onCloseRequest: onCloseRequest,
        fullAbsolutePath: fullAbsolutePath,
        fullPath: path,
        path: fileName,
        content: fileContent,
        isSelected: true,
        isModified: content != null, // Mark as modified if content is provided
      ));
      setCurrentTab(_tabs.length - 1);
    } else {
      // Tab already exists
      if (content != null && content != _tabs[existingIndex].content) {
        // Update the content if it's provided and different
        _tabs[existingIndex] = _tabs[existingIndex].copyWith(
          content: content,
          isModified: true,
        );
      }
      setCurrentTab(existingIndex);
    }

    notifyListeners();
  }

  // Keep only this version of updateTabContent
  void updateTabContent(String path, String content,
      {bool isModified = true, String? newPath}) {
    final index = _tabs.indexWhere((tab) => tab.path == path);
    if (index != -1) {
      _tabs[index] = _tabs[index].copyWith(
        content: content,
        isModified: isModified,
        path: newPath ?? _tabs[index].path,
        fullPath: newPath ?? _tabs[index].fullPath,
        fullAbsolutePath: newPath ?? _tabs[index].fullAbsolutePath,
      );
      notifyListeners();
    }
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

  void jumpToCursorPosition(int line, int column) {
    if (currentTab != null) {
      updateCursorPosition(
          currentTab!.path, CursorPosition(line: line, column: column));
    }

    caretPositionNotifier.updatePosition(line, column);

    notifyListeners();
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
