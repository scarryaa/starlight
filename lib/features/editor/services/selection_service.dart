import 'package:flutter/material.dart';
import 'package:starlight/features/editor/domain/enums/selection_mode.dart';
import 'package:starlight/features/editor/domain/models/text_editing_core.dart';

class CodeEditorSelectionService {
  final SelectionMode _selectionMode = SelectionMode.character;
  int? _selectionAnchor;
  late TextEditingCore editingCore;

  void updateSelection(DragStartDetails details) {}

  void updateSelectionOnDrag(DragUpdateDetails details) {}

  void selectWordAtPosition(int position) {}

  void selectLineAtPosition(int position) {}
}
