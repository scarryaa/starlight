import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/services/editor_service.dart';

class KeyboardShortcutService {
  final EditorService _editorService;

  KeyboardShortcutService(this._editorService);

  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      bool isCommandOrControlPressed = Platform.isMacOS
          ? HardwareKeyboard.instance.isMetaPressed
          : HardwareKeyboard.instance.isControlPressed;

      // Search All Files (Cmd/Ctrl + Shift + F)
      if (isCommandOrControlPressed &&
          HardwareKeyboard.instance.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyF) {
        _editorService.editorKey.currentState?.addSearchAllFilesTab();
        return KeyEventResult.handled;
      }

      // Save (Cmd/Ctrl + S)
      if (isCommandOrControlPressed &&
          event.logicalKey == LogicalKeyboardKey.keyS &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _editorService.editorKey.currentState?.saveCurrentFile();
        return KeyEventResult.handled;
      }

      // Save As (Cmd/Ctrl + Shift + S)
      if (isCommandOrControlPressed &&
          HardwareKeyboard.instance.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyS) {
        _editorService.editorKey.currentState?.saveFileAs();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void initializeKeyboardShortcuts() {
    HardwareKeyboard.instance.addHandler((event) {
      final result = handleKeyEvent(event);
      return result == KeyEventResult.handled;
    });
  }
}
