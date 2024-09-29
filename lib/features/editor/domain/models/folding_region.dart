class FoldingRegion {
  final int startLine;
  final int endLine;
  final int startColumn;
  final int endColumn;
  bool isFolded;
  bool isHidden;

  FoldingRegion({
    required this.startLine,
    required this.endLine,
    required this.startColumn,
    required this.endColumn,
    this.isFolded = false,
    this.isHidden = false,
  });
}

class FoldingStackItem {
  final int line;
  final int column;

  FoldingStackItem(this.line, this.column);
}
