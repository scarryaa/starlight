import 'dart:math';
import 'dart:ui';

import 'package:starlight/features/editor/domain/models/text_editing_core.dart';
import 'package:starlight/features/editor/services/calculation_service.dart';
import 'package:starlight/features/editor/services/clipboard_service.dart';
import 'package:starlight/features/editor/services/keyboard_handler_service.dart';
import 'package:starlight/features/editor/services/scroll_service.dart';
import 'package:starlight/features/editor/services/selection_service.dart';
import 'package:starlight/utils/constants.dart';

class CodeEditorService {
  final CodeEditorScrollService scrollService;
  final CodeEditorSelectionService selectionService;
  final CodeEditorKeyboardHandlerService keyboardHandlerService;
  final CodeEditorClipboardService clipboardService;
  final CodeEditorCalculationService calculationService;

  CodeEditorService({
    required this.scrollService,
    required this.selectionService,
    required this.keyboardHandlerService,
    required this.clipboardService,
    required this.calculationService,
  });

  void initialize(TextEditingCore editingCore, double zoomLevel) {
    scrollService.editingCore = editingCore;
    scrollService.zoomLevel = zoomLevel;
    selectionService.editingCore = editingCore;
    keyboardHandlerService.editingCore = editingCore;
    clipboardService.editingCore = editingCore;
    calculationService.editingCore = editingCore;
    calculationService.zoomLevel = zoomLevel;
  }

  int getPositionFromOffset(Offset offset) {
    final adjustedOffset = offset +
        Offset(max(0, scrollService.horizontalController.offset),
            scrollService.codeScrollController.offset);
    final tappedLine = (adjustedOffset.dy /
            (CodeEditorConstants.lineHeight * scrollService.zoomLevel))
        .floor();

    if (scrollService.editingCore.lineCount == 0) return 0;
    if (tappedLine < scrollService.editingCore.lineCount) {
      final scaledLineNumberWidth =
          scrollService.lineNumberWidth * scrollService.zoomLevel;
      final textStartX = scaledLineNumberWidth / 8;
      final adjustedTappedOffset =
          (adjustedOffset.dx - textStartX).clamp(0, double.infinity);
      final column = (adjustedTappedOffset /
              (CodeEditorConstants.charWidth * scrollService.zoomLevel))
          .round()
          .clamp(0, double.infinity)
          .toInt();

      if (tappedLine < 0) return 0;
      int lineStartIndex =
          scrollService.editingCore.getLineStartIndex(tappedLine);
      String line = scrollService.editingCore.getLineContent(tappedLine);
      if (line.isEmpty) return lineStartIndex;
      if (column >= line.length) {
        return lineStartIndex + line.length;
      }
      return lineStartIndex + column;
    }
    return scrollService.editingCore.length;
  }

  void dispose() {
    scrollService.dispose();
  }
}
