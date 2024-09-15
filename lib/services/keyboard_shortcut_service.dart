import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/services/editor_service.dart';

class KeyboardShortcutService {
  final EditorService _editorService;
  VoidCallback? _toggleCommandPalette;
  final FocusNode focusNode = FocusNode(debugLabel: 'KeyboardShortcutService');

  KeyboardShortcutService(this._editorService);

  void setToggleCommandPalette(VoidCallback callback) {
    _toggleCommandPalette = callback;
  }

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
        _editorService.handleSaveCurrentFile();
        return KeyEventResult.handled;
      }

      // Save As (Cmd/Ctrl + Shift + S)
      if (isCommandOrControlPressed &&
          HardwareKeyboard.instance.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyS) {
        _editorService.handleSaveFileAs();
        return KeyEventResult.handled;
      }

      // Toggle Command Palette (Cmd/Ctrl + P)
      if (isCommandOrControlPressed &&
          event.logicalKey == LogicalKeyboardKey.keyP) {
        _toggleCommandPalette?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void dispose() {
    focusNode.dispose();
  }
}
