import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/services/text_editing_service.dart';
import 'package:starlight/features/editor/services/clipboard_service.dart';
import 'package:starlight/services/keyboard_shortcut_service.dart';

class KeyboardHandlingService {
  final TextEditingService textEditingService;
  final KeyboardShortcutService keyboardShortcutService;
  final ClipboardService clipboardService;
  final VoidCallback recalculateEditor;

  KeyboardHandlingService(
      {required this.textEditingService,
      required this.clipboardService,
      required this.recalculateEditor,
      required this.keyboardShortcutService});

  bool handleKeyPress(KeyEvent event) {
    if (keyboardShortcutService.handleKeyEvent(event) ==
        KeyEventResult.handled) {
      return true;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

    if (_isModifierKey(event.logicalKey)) {
      return false;
    }

    if (_handleShortcuts(event)) {
      recalculateEditor();
      return true;
    }

    if (_handleSelectionKeys(event)) {
      recalculateEditor();
      return true;
    }

    if (_handleTextInputKeys(event)) {
      recalculateEditor();
      return true;
    }

    return false;
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.capsLock ||
        key == LogicalKeyboardKey.numLock ||
        key == LogicalKeyboardKey.scrollLock ||
        key == LogicalKeyboardKey.fn;
  }

  bool _handleShortcuts(KeyEvent event) {
    final bool isControlPressed = Platform.isMacOS
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;

    if (isControlPressed) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyC:
          clipboardService.handleCopy();
          return true;
        case LogicalKeyboardKey.keyX:
          clipboardService.handleCut();
          return true;
        case LogicalKeyboardKey.keyV:
          clipboardService.handlePaste();
          return true;
        case LogicalKeyboardKey.keyA:
          textEditingService.setSelection(
              0, textEditingService.editingCore.length);
          return true;
      }
    }
    return false;
  }

  bool _handleSelectionKeys(KeyEvent event) {
    if (textEditingService.hasSelection()) {
      int selectionStart = textEditingService.editingCore.selectionStart!;
      int selectionEnd = textEditingService.editingCore.selectionEnd!;
      bool isBackwardSelection = selectionEnd < selectionStart;
      int actualStart = min(selectionStart, selectionEnd);
      int actualEnd = max(selectionStart, selectionEnd);

      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
          textEditingService.editingCore.cursorPosition =
              isBackwardSelection ? actualEnd : actualStart;
          textEditingService.clearSelection();
          return true;
        case LogicalKeyboardKey.arrowRight:
          textEditingService.editingCore.cursorPosition =
              isBackwardSelection ? actualStart : actualEnd;
          textEditingService.clearSelection();
          return true;
        case LogicalKeyboardKey.arrowUp:
          _handleSelectionArrowUp(isBackwardSelection, actualStart, actualEnd);
          return true;
        case LogicalKeyboardKey.arrowDown:
          _handleSelectionArrowDown(
              isBackwardSelection, actualStart, actualEnd);
          return true;
      }
    }
    return false;
  }

  void _handleSelectionArrowUp(
      bool isBackwardSelection, int actualStart, int actualEnd) {
    int targetLine = textEditingService.editingCore.rope
        .findLine(isBackwardSelection ? actualEnd : actualStart);
    if (targetLine > 0) {
      int column = (isBackwardSelection ? actualEnd : actualStart) -
          textEditingService.editingCore.getLineStartIndex(targetLine);
      int newLine = targetLine - 1;
      int newPosition = textEditingService.getPositionAtColumn(newLine, column);
      textEditingService.editingCore.cursorPosition = newPosition;
    } else {
      textEditingService.editingCore.cursorPosition =
          isBackwardSelection ? actualEnd : actualStart;
    }
    textEditingService.clearSelection();
  }

  void _handleSelectionArrowDown(
      bool isBackwardSelection, int actualStart, int actualEnd) {
    int targetLine = textEditingService.editingCore.rope
        .findLine(isBackwardSelection ? actualStart : actualEnd);
    if (targetLine < textEditingService.editingCore.lineCount - 1) {
      int column = (isBackwardSelection ? actualStart : actualEnd) -
          textEditingService.editingCore.getLineStartIndex(targetLine);
      int newLine = targetLine + 1;
      int newPosition = textEditingService.getPositionAtColumn(newLine, column);
      textEditingService.editingCore.cursorPosition = newPosition;
    } else {
      textEditingService.editingCore.cursorPosition =
          isBackwardSelection ? actualStart : actualEnd;
    }
    textEditingService.clearSelection();
  }

  bool _handleTextInputKeys(KeyEvent event) {
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        textEditingService.moveCursor(-1, 0);
        return true;
      case LogicalKeyboardKey.arrowRight:
        textEditingService.moveCursor(1, 0);
        return true;
      case LogicalKeyboardKey.arrowUp:
        textEditingService.moveCursor(0, -1);
        return true;
      case LogicalKeyboardKey.arrowDown:
        textEditingService.moveCursor(0, 1);
        return true;
      case LogicalKeyboardKey.enter:
        textEditingService.insertText('\n');
        return true;
      case LogicalKeyboardKey.backspace:
        textEditingService.handleBackspace();
        return true;
      case LogicalKeyboardKey.delete:
        textEditingService.handleDelete();
        return true;
      case LogicalKeyboardKey.tab:
        textEditingService.insertText('    '); // 4 spaces for tab
        return true;
      default:
        if (event.character != null) {
          textEditingService.insertText(event.character!);
          return true;
        }
    }
    return false;
  }
}
