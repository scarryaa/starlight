class FoldingRegion {
  final int startLine;
  final int endLine;
  final int startColumn;
  final int endColumn;
  bool isFolded;

  FoldingRegion({
    required this.startLine,
    required this.endLine,
    required this.startColumn,
    required this.endColumn,
    this.isFolded = false,
  });
}

class FoldingStackItem {
  final int line;
  final int column;

  FoldingStackItem(this.line, this.column);
}
