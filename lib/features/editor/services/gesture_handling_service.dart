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

  static const double _tapDistanceThreshold = 10.0;
  static const Duration _multiTapTimeout = Duration(milliseconds: 300);

  GestureHandlingService({
    required this.textEditingService,
    required this.selectionService,
    required this.getPositionFromOffset,
    required this.recalculateEditor,
  });

  void handleTap(TapDownDetails details) {
    final currentTapPosition = details.localPosition;

    if (_lastTapPosition != null) {
      double distance = (currentTapPosition - _lastTapPosition!).distance;
      if (distance > _tapDistanceThreshold) {
        _resetTapState();
      }
    }

    _tapCount++;
    _lastTapPosition = currentTapPosition;
    _tapTimer?.cancel();
    _tapTimer = Timer(_multiTapTimeout, _resetTapState);

    switch (_tapCount) {
      case 1:
        _handleSingleTap(currentTapPosition);
        break;
      case 2:
        _handleDoubleTap(currentTapPosition);
        break;
      case 3:
        _handleTripleTap(currentTapPosition);
        break;
    }

    recalculateEditor();
  }

  void _resetTapState() {
    _tapCount = 0;
    _lastTapPosition = null;
  }

  void _handleSingleTap(Offset tapPosition) {
    final position = getPositionFromOffset(tapPosition);
    textEditingService.editingCore.cursorPosition = position;
    textEditingService.clearSelection();
  }

  void _handleDoubleTap(Offset tapPosition) {
    final position = getPositionFromOffset(tapPosition);
    selectionService.selectWordAtPosition(position);
  }

  void _handleTripleTap(Offset tapPosition) {
    final position = getPositionFromOffset(tapPosition);
    selectionService.selectLineAtPosition(position);
  }
}
