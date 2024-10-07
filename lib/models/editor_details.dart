class EditorDetails {
  final double scrollPositionVertical;
  final double scrollPositionHorizontal;
  final int caretPosition;
  final int caretLine;
  final int absoluteCaretPosition;
  final int selectionStart;
  final int selectionEnd;

  EditorDetails({
    required this.scrollPositionVertical,
    required this.scrollPositionHorizontal,
    required this.caretPosition,
    required this.caretLine,
    required this.absoluteCaretPosition,
    required this.selectionStart,
    required this.selectionEnd,
  });
}
