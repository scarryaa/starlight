import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/presentation/editor_widget.dart';
import 'package:starlight/services/editor_service.dart';

class KeyboardShortcutService {
  final EditorService editorService;
  VoidCallback? _toggleCommandPalette;
  FocusNode? _lastFocusedNode;
  final FocusNode focusNode = FocusNode(debugLabel: 'KeyboardShortcutService');

  KeyboardShortcutService(this.editorService);

  void dispose() {
    focusNode.dispose();
  }

  EditorWidgetState? get currentEditorState =>
      editorService.editorKey.currentState;

  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      _lastFocusedNode = FocusManager.instance.primaryFocus;
      bool isCommandOrControlPressed = Platform.isMacOS
          ? HardwareKeyboard.instance.isMetaPressed
          : HardwareKeyboard.instance.isControlPressed;

      // Search All Files (Cmd/Ctrl + Shift + F)
      if (isCommandOrControlPressed &&
          HardwareKeyboard.instance.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyF) {
        editorService.editorKey.currentState?.addSearchAllFilesTab();
        _restoreFocus();
        return KeyEventResult.handled;
      }

      // Save (Cmd/Ctrl + S)
      if (isCommandOrControlPressed &&
          event.logicalKey == LogicalKeyboardKey.keyS &&
          !HardwareKeyboard.instance.isShiftPressed) {
        editorService.handleSaveCurrentFile();
        _restoreFocus();
        return KeyEventResult.handled;
      }

      // Save As (Cmd/Ctrl + Shift + S)
      if (isCommandOrControlPressed &&
          HardwareKeyboard.instance.isShiftPressed &&
          event.logicalKey == LogicalKeyboardKey.keyS) {
        editorService.handleSaveFileAs();
        _restoreFocus();
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
        editorService.undo();
        editorService.editorKey.currentState
            ?.maintainFocus(); // Ensure focus remains
        return KeyEventResult.handled;
      }

      // Redo (Cmd/Ctrl + Shift + Z or Cmd/Ctrl + Y)
      if (isCommandOrControlPressed &&
          ((HardwareKeyboard.instance.isShiftPressed &&
                  event.logicalKey == LogicalKeyboardKey.keyZ) ||
              (!HardwareKeyboard.instance.isShiftPressed &&
                  event.logicalKey == LogicalKeyboardKey.keyY))) {
        editorService.redo();
        editorService.editorKey.currentState
            ?.maintainFocus(); // Ensure focus remains
        return KeyEventResult.handled;
      }

      // Zoom In (Cmd/Ctrl + Plus)
      if (isCommandOrControlPressed &&
          event.logicalKey == LogicalKeyboardKey.equal) {
        editorService.editorKey.currentState?.zoomIn();
        _restoreFocus();
        return KeyEventResult.handled;
      }

      // Zoom Out (Cmd/Ctrl + Minus)
      if (isCommandOrControlPressed &&
          event.logicalKey == LogicalKeyboardKey.minus) {
        editorService.editorKey.currentState?.zoomOut();
        _restoreFocus();
        return KeyEventResult.handled;
      }

      // Reset Zoom (Cmd/Ctrl + 0)
      if (isCommandOrControlPressed &&
          event.logicalKey == LogicalKeyboardKey.digit0) {
        editorService.editorKey.currentState?.resetZoom();
        _restoreFocus();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void setToggleCommandPalette(VoidCallback callback) {
    _toggleCommandPalette = callback;
  }

  void _restoreFocus() {
    if (_lastFocusedNode != null && _lastFocusedNode!.canRequestFocus) {
      _lastFocusedNode!.requestFocus();
    } else {
      focusNode.requestFocus();
    }
  }
}
