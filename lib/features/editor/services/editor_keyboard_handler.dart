import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide VerticalDirection;
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/models/direction.dart';
import 'package:starlight/features/editor/models/rope.dart';
import 'package:starlight/features/editor/services/editor_selection_manager.dart';
import 'package:starlight/services/hotkey_service.dart';
import 'package:starlight/services/tab_service.dart';

class EditorKeyboardHandler {
  Rope rope;
  final TabService tabService;
  final EditorSelectionManager selectionManager;
  final HotkeyService hotkeyService;
  final Function(int, int) updateSelection;
  final Function updateLineCounts;
  final Function saveFile;
  final Function ensureCursorVisible;
  final Function(int, int) updateAfterEdit;
  final Function() notifyListeners;

  int _lastUpdatedLine = 0;
  int get lastUpdatedLine => _lastUpdatedLine;
  int absoluteCaretPosition = 0;
  int caretLine = 0;
  int caretPosition = 0;
  HorizontalDirection horizontalDirection = HorizontalDirection.right;
  VerticalDirection verticalDirection = VerticalDirection.down;

  EditorKeyboardHandler({
    required this.rope,
    required this.tabService,
    required this.selectionManager,
    required this.hotkeyService,
    required this.updateSelection,
    required this.updateLineCounts,
    required this.saveFile,
    required this.ensureCursorVisible,
    required this.updateAfterEdit,
    required this.notifyListeners,
  });

  KeyEventResult handleInput(KeyEvent keyEvent) {
    bool isKeyDownEvent = keyEvent is KeyDownEvent;
    bool isKeyRepeatEvent = keyEvent is KeyRepeatEvent;
    bool isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
    bool isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
    bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    _lastUpdatedLine = max(0, caretLine - 1);

    KeyEventResult result = KeyEventResult.ignored;

    if (hotkeyService.isGlobalHotkey(keyEvent)) {
      return KeyEventResult.ignored;
    }

    if ((isCtrlPressed && !Platform.isMacOS) ||
        (Platform.isMacOS && isMetaPressed) && keyEvent.character != null) {
      _handleCtrlKeys(keyEvent.character!);
      result = KeyEventResult.handled;
    } else if ((isKeyDownEvent || isKeyRepeatEvent) &&
        keyEvent.character != null &&
        !_isSpecialKey(keyEvent.logicalKey)) {
      _handleRegularInput(keyEvent.character!);
      result = KeyEventResult.handled;
    } else if (isKeyDownEvent || isKeyRepeatEvent) {
      result = _handleSpecialKeys(keyEvent.logicalKey, isShiftPressed);
    }

    if (result == KeyEventResult.handled) {
      updateLineCounts();
      tabService.currentTab!.content = rope.text;
      tabService.currentTab!.isModified = true;
      notifyListeners();
      ensureCursorVisible();
    }

    return result;
  }

  bool _isSpecialKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown;
  }

  void _handleRegularInput(String character) {
    if (selectionManager.hasSelection()) {
      deleteSelection();
    }
    rope.insert(character, absoluteCaretPosition);
    caretPosition++;
    absoluteCaretPosition++;
  }

  KeyEventResult _handleSpecialKeys(
      LogicalKeyboardKey key, bool isShiftPressed) {
    switch (key) {
      case LogicalKeyboardKey.tab:
        handleTabKey();
        break;
      case LogicalKeyboardKey.backspace:
        handleBackspaceKey();
        break;
      case LogicalKeyboardKey.enter:
        handleEnterKey();
        break;
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowDown:
        handleArrowKeys(key, isShiftPressed);
        break;
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void handleBackspaceKey() {
    if (selectionManager.hasSelection()) {
      deleteSelection();
    } else if (absoluteCaretPosition > 0) {
      int startLine = rope.findLineForPosition(absoluteCaretPosition);
      int endLine = startLine;

      if (caretPosition == 0 && caretLine > 0) {
        // Deleting a newline character
        caretLine--;
        int previousLineLength = rope.getLineLength(caretLine);
        rope.delete(absoluteCaretPosition - 1, 1);
        absoluteCaretPosition--;
        caretPosition = previousLineLength;
        endLine = startLine;
        startLine = caretLine;
      } else if (caretPosition > 0) {
        // Deleting a regular character
        rope.delete(absoluteCaretPosition - 1, 1);
        caretPosition--;
        absoluteCaretPosition--;
      }

      // Update caret position bounds
      caretLine = max(0, caretLine);
      caretPosition = max(0, min(caretPosition, rope.getLineLength(caretLine)));
      absoluteCaretPosition = max(0, min(absoluteCaretPosition, rope.length));

      _lastUpdatedLine = max(0, startLine - 1);
      updateAfterEdit(startLine, endLine);
    }
  }

  void deleteSelection() {
    if (selectionManager.hasSelection()) {
      int start =
          min(selectionManager.selectionStart, selectionManager.selectionEnd);
      int end =
          max(selectionManager.selectionStart, selectionManager.selectionEnd);
      int length = end - start;

      int startLine = rope.findLineForPosition(start);
      int endLine = rope.findLineForPosition(end);

      rope.delete(start, length);
      absoluteCaretPosition = start;
      updateCaretPosition();
      selectionManager.clearSelection();

      _lastUpdatedLine = max(0, startLine - 1);
      updateAfterEdit(startLine, endLine);
    }
  }

  void _handleCtrlKeys(String key) {
    switch (key.toLowerCase()) {
      case 'a':
        selectAll();
        break;
      case 'v':
        pasteText();
        break;
      case 'c':
        copyText();
        break;
      case 'x':
        cutText();
        break;
      case 's':
        saveFile();
        tabService.currentTab!.isModified = false;
        break;
    }
  }

  void selectAll() {
    selectionManager.selectionAnchor = 0;
    selectionManager.selectionFocus = rope.length;
    selectionManager.updateSelection();
    int lastLineLength = rope.getLineLength(rope.lineCount - 1);
    caretPosition = lastLineLength;
    absoluteCaretPosition = rope.length;
    caretLine = rope.lineCount - 1;
  }

  Future<void> pasteText() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final textToBePasted = clipboardData?.text;

    if (textToBePasted == null || textToBePasted.isEmpty) {
      return;
    }

    if (selectionManager.hasSelection()) {
      deleteSelection();
    }

    rope.insert(textToBePasted, absoluteCaretPosition);
    absoluteCaretPosition += textToBePasted.length;
    updateCaretPosition();

    selectionManager.selectionStart =
        selectionManager.selectionEnd = absoluteCaretPosition;

    updateLineCounts();
    ensureCursorVisible();
  }

  void copyText() {
    if (selectionManager.hasSelection()) {
      Clipboard.setData(ClipboardData(
        text: rope.text.substring(
            selectionManager.selectionStart, selectionManager.selectionEnd),
      ));
    } else {
      int closestLineStart = rope.findClosestLineStart(caretLine);
      int lineEnd = rope.getLineLength(caretLine) + closestLineStart;
      Clipboard.setData(ClipboardData(
        text: rope.text.substring(closestLineStart, lineEnd),
      ));
    }
  }

  void cutText() {
    copyText();
    deleteSelection();
  }

  void handleArrowKeys(LogicalKeyboardKey key, bool isShiftPressed) {
    int oldCaretPosition = absoluteCaretPosition;

    switch (key) {
      case LogicalKeyboardKey.arrowDown:
        moveCaretVertically(1);
        break;
      case LogicalKeyboardKey.arrowUp:
        moveCaretVertically(-1);
        break;
      case LogicalKeyboardKey.arrowLeft:
        moveCaretHorizontally(-1);
        break;
      case LogicalKeyboardKey.arrowRight:
        moveCaretHorizontally(1);
        break;
      default:
        return;
    }

    if (isShiftPressed) {
      if (selectionManager.selectionAnchor == -1) {
        selectionManager.selectionAnchor = oldCaretPosition;
      }
      selectionManager.selectionFocus = absoluteCaretPosition;
    } else {
      selectionManager.clearSelection();
    }

    selectionManager.updateSelection();
  }

  void handleEnterKey() {
    if (selectionManager.selectionStart != selectionManager.selectionEnd) {
      deleteSelection();
    }

    rope.insert('\n', absoluteCaretPosition);
    caretLine++;
    caretPosition = 0;
    absoluteCaretPosition++;

    // Auto-indentation
    int previousLineStart = rope.findClosestLineStart(caretLine - 1);
    int indentationCount = 0;
    while (rope.text[previousLineStart + indentationCount] == ' ' &&
        indentationCount < rope.getLineLength(caretLine - 1)) {
      indentationCount++;
    }
    if (indentationCount > 0) {
      String indentation = ' ' * indentationCount;
      rope.insert(indentation, absoluteCaretPosition);
      caretPosition += indentationCount;
      absoluteCaretPosition += indentationCount;
    }
  }

  void handleTabKey() {
    if (selectionManager.selectionStart != selectionManager.selectionEnd) {
      deleteSelection();
    }

    rope.insert("    ", absoluteCaretPosition);
    caretPosition += 4;
    absoluteCaretPosition += 4;
  }

  void moveCaretHorizontally(int amount) {
    int newCaretPosition = caretPosition + amount;
    int currentLineLength = rope.getLineLength(caretLine);

    if (newCaretPosition >= 0 && newCaretPosition <= currentLineLength) {
      caretPosition = newCaretPosition;
      absoluteCaretPosition += amount;
    } else if (newCaretPosition < 0 && caretLine > 0) {
      caretLine--;
      caretPosition = rope.getLineLength(caretLine);
      absoluteCaretPosition =
          rope.findClosestLineStart(caretLine) + caretPosition;
    } else if (newCaretPosition > currentLineLength &&
        caretLine < rope.lineCount - 1) {
      caretLine++;
      caretPosition = 0;
      absoluteCaretPosition = rope.findClosestLineStart(caretLine);
    }

    absoluteCaretPosition = max(0, min(absoluteCaretPosition, rope.length));
    selectionManager.moveSelectionHorizontally(absoluteCaretPosition);
  }

  void moveCaretVertically(int amount) {
    int targetLine = caretLine + amount;
    if (targetLine >= 0 && targetLine < rope.lineCount) {
      int targetLineStart = rope.findClosestLineStart(targetLine);
      int targetLineLength = rope.getLineLength(targetLine);

      caretPosition = min(caretPosition, targetLineLength);
      caretLine = targetLine;
      absoluteCaretPosition = targetLineStart + caretPosition;
    } else if (targetLine == rope.lineCount) {
      // Move to the end of the last line
      caretLine = rope.lineCount - 1;
      caretPosition = rope.getLineLength(caretLine);
      absoluteCaretPosition = rope.length;
    } else if (targetLine < 0) {
      // Move to the beginning of the first line
      caretLine = 0;
      caretPosition = 0;
      absoluteCaretPosition = 0;
    }

    selectionManager.moveSelectionVertically(absoluteCaretPosition);
  }

  void updateCaretPosition() {
    caretLine = rope.findLineForPosition(absoluteCaretPosition);
    int lineStart = rope.findClosestLineStart(caretLine);
    caretPosition = absoluteCaretPosition - lineStart;
  }
}

