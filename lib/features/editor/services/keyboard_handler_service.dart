import 'package:flutter/material.dart';
import 'package:starlight/features/editor/domain/models/text_editing_core.dart';

class CodeEditorKeyboardHandlerService {
  late TextEditingCore editingCore;

  KeyEventResult handleKeyPress(FocusNode node, KeyEvent event) {
    return KeyEventResult.ignored;
  }

  bool handleShortcuts(KeyEvent event) {
    return false;
  }

  bool handleSelectionKeys(KeyEvent event) {
    return false;
  }

  bool handleTextInputKeys(KeyEvent event) {
    return false;
  }
}
