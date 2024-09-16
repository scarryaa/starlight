import 'package:flutter/services.dart';
import 'package:starlight/features/editor/services/text_editing_service.dart';

class ClipboardService {
  final TextEditingService textEditingService;

  ClipboardService(this.textEditingService);

  Future<void> handleCopy() async {
    if (textEditingService.hasSelection()) {
      await Clipboard.setData(
          ClipboardData(text: textEditingService.getSelectedText()));
    }
  }

  Future<void> handleCut() async {
    if (textEditingService.hasSelection()) {
      final selectedText = textEditingService.getSelectedText();
      await Clipboard.setData(ClipboardData(text: selectedText));
      textEditingService.deleteSelection();
    }
  }

  Future<void> handlePaste() async {
    ClipboardData? clipboardData =
        await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      textEditingService.insertText(clipboardData!.text!);
    }
  }
}
