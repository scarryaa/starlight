import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/services/editor_service.dart';

class KeyboardShortcutService {
  final EditorService _editorService;
  VoidCallback? _toggleCommandPalette;
  final FocusNode focusNode = FocusNode(debugLabel: 'KeyboardShortcutService');

  KeyboardShortcutService(this._editorService);

  void dispose() {
    focusNode.dispose();
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

      // Undo (Cmd/Ctrl + Z)
      if (isCommandOrControlPressed &&
          event.logicalKey == LogicalKeyboardKey.keyZ &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _editorService.editorKey.currentState?.undo();
        return KeyEventResult.handled;
      }

      // Redo (Cmd/Ctrl + Shift + Z or Cmd/Ctrl + Y)
      if (isCommandOrControlPressed &&
          ((HardwareKeyboard.instance.isShiftPressed &&
                  event.logicalKey == LogicalKeyboardKey.keyZ) ||
              (!HardwareKeyboard.instance.isShiftPressed &&
                  event.logicalKey == LogicalKeyboardKey.keyY))) {
        _editorService.editorKey.currentState?.redo();
        return KeyEventResult.handled;
      }

      // Zoom In (Cmd/Ctrl + Plus)
      if (isCommandOrControlPressed &&
          event.logicalKey == LogicalKeyboardKey.equal) {
        _editorService.editorKey.currentState?.zoomIn();
        return KeyEventResult.handled;
      }

      // Zoom Out (Cmd/Ctrl + Minus)
      if (isCommandOrControlPressed &&
          event.logicalKey == LogicalKeyboardKey.minus) {
        _editorService.editorKey.currentState?.zoomOut();
        return KeyEventResult.handled;
      }

      // Reset Zoom (Cmd/Ctrl + 0)
      if (isCommandOrControlPressed &&
          event.logicalKey == LogicalKeyboardKey.digit0) {
        _editorService.editorKey.currentState?.resetZoom();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void setToggleCommandPalette(VoidCallback callback) {
    _toggleCommandPalette = callback;
  }
}
