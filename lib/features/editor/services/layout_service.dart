import 'dart:math';

import 'package:starlight/features/editor/domain/models/text_editing_core.dart';
import 'package:starlight/utils/constants.dart';

class LayoutService {
  final TextEditingCore editingCore;
  final Map<int, double> lineWidthCache = {};
  int lastCalculatedLine = -1;
  double cachedMaxLineWidth = 0;
  int lastLineCount = 0;
  double lineNumberWidth = 0;
  double maxLineWidth = 0;

  LayoutService(this.editingCore);

  double calculateLineNumberWidth() {
    final lineCount = editingCore.lineCount;
    final maxLineNumberWidth =
        '$lineCount'.length * CodeEditorConstants.charWidth;
    lineNumberWidth = maxLineNumberWidth + 40;
    return lineNumberWidth;
  }

  double calculateLineWidth(String line) {
    return line.length * CodeEditorConstants.charWidth;
  }

  void updateMaxLineWidth() {
    int currentLineCount = editingCore.lineCount;
    double newMaxLineWidth = cachedMaxLineWidth;

    // Only recalculate if the line count has changed
    if (currentLineCount != lastLineCount) {
      // Check for deleted lines
      if (currentLineCount < lastLineCount) {
        lineWidthCache.removeWhere((key, value) => key >= currentLineCount);
        // Recalculate max width if we removed the previously longest line
        if (cachedMaxLineWidth == newMaxLineWidth) {
          newMaxLineWidth = lineWidthCache.values.fold(0, max);
        }
      }

      // Calculate only new lines
      for (int i = lastCalculatedLine + 1; i < currentLineCount; i++) {
        String line = editingCore.getLineContent(i);
        double lineWidth = calculateLineWidth(line);
        lineWidthCache[i] = lineWidth;
        newMaxLineWidth = max(newMaxLineWidth, lineWidth);
      }

      lastCalculatedLine = currentLineCount - 1;
      lastLineCount = currentLineCount;
    } else {
      // If line count hasn't changed, we only need to check the last modified line
      int lastModifiedLine = editingCore.lastModifiedLine;
      if (lastModifiedLine >= 0 && lastModifiedLine < currentLineCount) {
        String line = editingCore.getLineContent(lastModifiedLine);
        double lineWidth = calculateLineWidth(line);
        lineWidthCache[lastModifiedLine] = lineWidth;
        newMaxLineWidth = max(newMaxLineWidth, lineWidth);
      }
    }

    newMaxLineWidth += lineNumberWidth + 50;

    if (newMaxLineWidth != cachedMaxLineWidth) {
      maxLineWidth = newMaxLineWidth;
      cachedMaxLineWidth = newMaxLineWidth - lineNumberWidth;
    }
  }

  double getMaxLineWidth() {
    return cachedMaxLineWidth;
  }
}
