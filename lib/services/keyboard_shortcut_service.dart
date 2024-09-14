import 'dart:io';

import 'package:flutter/services.dart';
import 'package:starlight/services/editor_service.dart';

class KeyboardShortcutService {
  final EditorService _editorService;

  KeyboardShortcutService(this._editorService);

  bool handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      bool isCommandOrControlPressed = Platform.isMacOS
          ? HardwareKeyboard.instance.isMetaPressed
          : HardwareKeyboard.instance.isControlPressed;

      if (isCommandOrControlPressed &&
          HardwareKeyboard.instance.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyF) {
        _editorService.editorKey.currentState?.addSearchAllFilesTab();
        return true;
      }
    }
    return false;
  }

  void initializeKeyboardShortcuts() {
    HardwareKeyboard.instance.addHandler(handleKeyEvent);
  }
}
