class Rope {
  Node? root;

  Rope(String s) : root = _buildTree(s);

  static Node? _buildTree(String s) {
    if (s.isEmpty) return null;
    if (s.length <= 64) return Leaf(s);
    int mid = s.length ~/ 2;
    return Branch(
      _buildTree(s.substring(0, mid)),
      _buildTree(s.substring(mid)),
    );
  }

  @override
  String toString() => root?.toString() ?? '';

  String charAt(int index) {
    if (index < 0 || index >= length) {
      throw RangeError('Index out of bounds');
    }
    return root!.charAt(index);
  }

  Rope insert(int index, String s) {
    if (index < 0 || index > length) {
      throw RangeError('Index out of bounds');
    }
    return Rope('')..root = root?.insert(index, s) ?? _buildTree(s);
  }

  Rope delete(int start, int end) {
    if (start < 0 || end > length || start > end) {
      throw RangeError('Invalid range');
    }
    return Rope('')..root = root?.delete(start, end);
  }

  int get length => root?.length ?? 0;

  String slice(int start, int end) {
    if (start < 0 || end > length || start > end) {
      throw RangeError('Invalid range');
    }
    return root?.slice(start, end) ?? '';
  }

  List<String> sliceLines(int startLine, int endLine) {
    if (startLine < 0 || endLine > lineCount || startLine > endLine) {
      throw RangeError('Invalid line range');
    }
    return root?.sliceLines(startLine, endLine) ?? [];
  }

  int get lineCount => root?.lineCount ?? 0;

  int findLine(int index) {
    if (index < 0 || index >= length) {
      throw RangeError('Index out of bounds');
    }
    return root?.findLine(index) ?? 0;
  }

  int findLineStart(int line) {
    if (line < 0 || line >= lineCount) {
      throw RangeError('Invalid line number');
    }
    return root?.findLineStart(line) ?? 0;
  }

  int findLineEnd(int line) {
    if (line < 0 || line >= lineCount) {
      throw RangeError('Invalid line number');
    }
    if (line == lineCount - 1) {
      return length - 1;
    }
    return findLineStart(line + 1) - 1;
  }
}

abstract class Node {
  int get length;
  int get lineCount;
  String charAt(int index);
  Node? insert(int index, String s);
  Node? delete(int start, int end);
  String slice(int start, int end);
  List<String> sliceLines(int startLine, int endLine);
  int findLine(int index);
  int findLineStart(int line);
}

class Leaf extends Node {
  final String value;
  late final List<int> _lineStarts;

  Leaf(this.value) {
    _computeLineStarts();
  }

  void _computeLineStarts() {
    _lineStarts = [0];
    for (int i = 0; i < value.length; i++) {
      if (value[i] == '\n') {
        _lineStarts.add(i + 1);
      }
    }
  }

  @override
  int get length => value.length;

  @override
  int get lineCount => _lineStarts.length;

  @override
  String charAt(int index) => value[index];

  @override
  Node insert(int index, String s) {
    return Leaf(value.substring(0, index) + s + value.substring(index));
  }

  @override
  Node? delete(int start, int end) {
    if (start == 0 && end == length) return null;
    return Leaf(value.substring(0, start) + value.substring(end));
  }

  @override
  String toString() => value;

  @override
  String slice(int start, int end) {
    return value.substring(start, end);
  }

  @override
  List<String> sliceLines(int startLine, int endLine) {
    List<String> result = [];
    for (int i = startLine; i < endLine; i++) {
      int start = _lineStarts[i];
      int end = i + 1 < _lineStarts.length ? _lineStarts[i + 1] : value.length;
      result.add(value.substring(start, end));
    }
    return result;
  }

  @override
  int findLine(int index) {
    for (int i = 0; i < _lineStarts.length; i++) {
      if (index < _lineStarts[i]) {
        return i - 1;
      }
    }
    return _lineStarts.length - 1;
  }

  @override
  int findLineStart(int line) {
    if (line < 0 || line >= _lineStarts.length) {
      throw RangeError('Invalid line number');
    }
    return _lineStarts[line];
  }
}

class Branch extends Node {
  Node? left;
  Node? right;
  late int _length;
  late int _lineCount;

  Branch(this.left, this.right) {
    _length = (left?.length ?? 0) + (right?.length ?? 0);
    _lineCount = (left?.lineCount ?? 0) + (right?.lineCount ?? 0);
  }

  @override
  int get length => _length;

  @override
  int get lineCount => _lineCount;

  @override
  String charAt(int index) {
    int leftLength = left?.length ?? 0;
    if (index < leftLength) {
      return left!.charAt(index);
    } else {
      return right!.charAt(index - leftLength);
    }
  }

  @override
  String slice(int start, int end) {
    int leftLength = left?.length ?? 0;
    if (end <= leftLength) {
      return left!.slice(start, end);
    } else if (start >= leftLength) {
      return right!.slice(start - leftLength, end - leftLength);
    } else {
      return left!.slice(start, leftLength) + right!.slice(0, end - leftLength);
    }
  }

  @override
  Node insert(int index, String s) {
    int leftLength = left?.length ?? 0;
    if (index <= leftLength) {
      left = left?.insert(index, s) ?? Leaf(s);
    } else {
      right = right?.insert(index - leftLength, s) ?? Leaf(s);
    }
    _length += s.length;
    _lineCount += s.split('\n').length - 1;
    return this;
  }

  @override
  Node? delete(int start, int end) {
    int leftLength = left?.length ?? 0;
    if (end <= leftLength) {
      left = left?.delete(start, end);
    } else if (start >= leftLength) {
      right = right?.delete(start - leftLength, end - leftLength);
    } else {
      left = left?.delete(start, leftLength);
      right = right?.delete(0, end - leftLength);
    }
    if (left == null) return right;
    if (right == null) return left;
    _length -= end - start;
    _lineCount = (left?.lineCount ?? 0) + (right?.lineCount ?? 0);
    return this;
  }

  @override
  List<String> sliceLines(int startLine, int endLine) {
    int leftLineCount = left?.lineCount ?? 0;
    if (endLine <= leftLineCount) {
      return left!.sliceLines(startLine, endLine);
    } else if (startLine >= leftLineCount) {
      return right!
          .sliceLines(startLine - leftLineCount, endLine - leftLineCount);
    } else {
      return [
        ...left!.sliceLines(startLine, leftLineCount),
        ...right!.sliceLines(0, endLine - leftLineCount)
      ];
    }
  }

  @override
  int findLine(int index) {
    int leftLength = left?.length ?? 0;
    if (index < leftLength) {
      return left!.findLine(index);
    } else {
      int rightLine = right!.findLine(index - leftLength);
      return (left?.lineCount ?? 0) + rightLine;
    }
  }

  @override
  int findLineStart(int line) {
    int leftLineCount = left?.lineCount ?? 0;
    if (line < leftLineCount) {
      return left!.findLineStart(line);
    } else {
      int rightLineStart = right!.findLineStart(line - leftLineCount);
      return (left?.length ?? 0) + rightLineStart;
    }
  }

  @override
  String toString() => '${left.toString()}${right.toString()}';
}
