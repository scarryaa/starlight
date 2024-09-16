import 'dart:async';
import 'package:flutter/material.dart';
import 'package:starlight/features/editor/services/text_editing_service.dart';
import 'package:starlight/features/editor/services/selection_service.dart';

class GestureHandlingService {
  final TextEditingService textEditingService;
  final CodeEditorSelectionService selectionService;
  final Function(Offset) getPositionFromOffset;
  final VoidCallback recalculateEditor;

  int _tapCount = 0;
  Timer? _tapTimer;
  Offset? _lastTapPosition;

  GestureHandlingService(
      {required this.textEditingService,
      required this.selectionService,
      required this.getPositionFromOffset,
      required this.recalculateEditor});

  void handleTap(TapDownDetails details) {
    if (_lastTapPosition != null) {
      double distance = (details.localPosition - _lastTapPosition!).distance;
      if (distance > 20.0) {
        _tapCount = 0;
      }
    }

    _tapCount++;
    _lastTapPosition = details.localPosition;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 500), () {
      _tapCount = 0;
      _lastTapPosition = null;
    });

    if (_tapCount == 1) {
      _handleSingleTap(details);
    } else if (_tapCount == 2) {
      _handleDoubleTap(details);
    } else if (_tapCount == 3) {
      _handleTripleTap(details);
    }

    recalculateEditor();
  }

  void _handleSingleTap(TapDownDetails details) {
    final position = getPositionFromOffset(details.localPosition);
    textEditingService.editingCore.cursorPosition = position;
    textEditingService.clearSelection();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final position = getPositionFromOffset(details.localPosition);
    selectionService.selectWordAtPosition(position);
  }

  void _handleTripleTap(TapDownDetails details) {
    final position = getPositionFromOffset(details.localPosition);
    selectionService.selectLineAtPosition(position);
  }
}
