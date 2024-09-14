import 'dart:math';

class Rope {
  Node? root;

  Rope(String s) {
    root = _buildTree(s.isEmpty ? '\n' : s);
  }

  static Node? _buildTree(String s) {
    if (s.isEmpty) return Leaf('\n');
    if (s.length <= 64) return Leaf(s);
    int mid = s.length ~/ 2;
    return Branch(
      _buildTree(s.substring(0, mid)),
      _buildTree(s.substring(mid)),
    );
  }

  @override
  String toString() => root?.toString() ?? '\n';

  String charAt(int index) {
    if (index < 0 || index >= length) {
      throw RangeError('Index out of bounds');
    }
    return root!.charAt(index);
  }

  Rope insert(int index, String s) {
    if (index < 0 || index > length) {
      throw RangeError(
          'Index $index is out of bounds. Valid range: 0 to $length.');
    }
    return Rope('')..root = root?.insert(index, s) ?? _buildTree(s);
  }

  Rope delete(int start, int end) {
    if (start < 0) {
      throw RangeError('Start index $start cannot be negative.');
    }
    if (end > length) {
      throw RangeError('End index $end exceeds the valid length of $length.');
    }
    if (start > end) {
      throw RangeError(
          'Start index $start must be less than or equal to end index $end.');
    }

    Node? newRoot = root?.delete(start, end);

    if (newRoot == null || (newRoot.length) == 0) {
      // If the document is empty or null after deletion, return a new Rope with a newline
      return Rope("\n");
    }

    return Rope('')..root = newRoot;
  }

  int get length => root?.length ?? 1;

  String slice(int start, int end) {
    if (start < 0) start = 0;
    if (end > length) end = length;
    if (start > end) {
      print('Start is greater than end, swapping values');
      int temp = start;
      start = end;
      end = temp;
    }
    return root?.slice(start, end) ?? '\n';
  }

  List<String> sliceLines(int startLine, int endLine) {
    if (root == null) return ['\n'];
    return root!.sliceLines(startLine, endLine);
  }

  int get lineCount => root?.lineCount ?? 1;

  int findLine(int index) {
    if (length == 0) return 0;
    index = index.clamp(0, length - 1);
    return root?.findLine(index) ?? 0;
  }

  int indexOf(String searchTerm, [int start = 0]) {
    if (searchTerm.isEmpty) return -1;
    if (start < 0) start = 0;
    if (start >= length) return -1;

    for (int i = start; i <= length - searchTerm.length; i++) {
      bool found = true;
      for (int j = 0; j < searchTerm.length; j++) {
        if (charAt(i + j) != searchTerm[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  int findLineStart(int line) {
    if (line < 0 || line >= lineCount) {
      print("Warning: Invalid line number $line. Clamping to valid range.");
      return root?.findLineStart(line.clamp(0, lineCount - 1)) ?? 0;
    }
    return root?.findLineStart(line) ?? 0;
  }

  int findLineEnd(int line) {
    if (line < 0 || line >= lineCount) {
      throw RangeError('Invalid line number');
    }
    if (line == lineCount - 1) {
      return length;
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
  List<int> get lineStarts;
  void updateLineStarts();
  int indexOf(String searchTerm, int start);
}

class Leaf extends Node {
  final String value;
  late final List<int> _lineStarts;

  Leaf(this.value) {
    updateLineStarts();
  }

  @override
  void updateLineStarts() {
    _lineStarts = [];
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
  List<int> get lineStarts => _lineStarts;

  @override
  String charAt(int index) {
    if (index < 0 || index >= value.length) {
      throw RangeError('Index out of bounds');
    }
    return value[index];
  }

  @override
  int indexOf(String searchTerm, int start) {
    return value.indexOf(searchTerm, start);
  }

  @override
  Node insert(int index, String s) {
    String newValue = value.substring(0, index) + s + value.substring(index);
    return Leaf(newValue);
  }

  @override
  Node? delete(int start, int end) {
    if (start == 0 && end == length) return null;
    String newValue = value.substring(0, start) + value.substring(end);
    return Leaf(newValue);
  }

  @override
  String toString() => value;

  @override
  String slice(int start, int end) {
    if (start >= value.length) return "";
    return value.substring(start, min(end, value.length));
  }

  @override
  List<String> sliceLines(int startLine, int endLine) {
    List<String> result = [];
    for (int i = startLine; i < min(endLine, _lineStarts.length); i++) {
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
    if (line < 0 || line >= lineCount) {
      return 0;
    }
    return _lineStarts[line];
  }
}

class Branch extends Node {
  Node? left;
  Node? right;
  late int _length;
  late int _lineCount;
  late List<int> _lineStarts;

  Branch(this.left, this.right) {
    _length = (left?.length ?? 0) + (right?.length ?? 0);
    updateLineStarts();
  }

  @override
  void updateLineStarts() {
    List<int> leftLineStarts = left?.lineStarts ?? [0];
    List<int> rightLineStarts = right?.lineStarts ?? [0];
    int leftLength = left?.length ?? 0;

    // Efficiently merge left and right line starts
    _lineStarts = List<int>.from(leftLineStarts);

    // Check if we need to join lines at the boundary
    if (left != null &&
        right != null &&
        leftLineStarts.isNotEmpty &&
        rightLineStarts.isNotEmpty) {
      String leftLastChar = left!.charAt(left!.length - 1);
      String rightFirstChar = right!.charAt(0);

      if (leftLastChar != '\n' && rightFirstChar != '\n') {
        // Remove the first line start of the right node (which is always 0)
        if (rightLineStarts.length > 1) {
          rightLineStarts = rightLineStarts.sublist(1);
        } else {
          rightLineStarts = [];
        }
      }
    }

    if (rightLineStarts.isNotEmpty) {
      int rightOffset =
          leftLength - (leftLineStarts.isNotEmpty ? leftLineStarts.last : 0);
      _lineStarts.addAll(rightLineStarts.map((index) => index + rightOffset));
    }

    _lineCount = _lineStarts.length;
  }

  @override
  int indexOf(String searchTerm, int start) {
    int leftLength = left?.length ?? 0;
    if (start < leftLength) {
      int leftIndex = left!.indexOf(searchTerm, start);
      if (leftIndex != -1) return leftIndex;

      // Check if the search term spans the boundary between left and right
      int remainingLength = min(searchTerm.length - 1, leftLength - start);
      String leftPart = left!.slice(leftLength - remainingLength, leftLength);
      String rightPart = right!.slice(0, searchTerm.length - leftPart.length);
      if (leftPart + rightPart == searchTerm) {
        return leftLength - leftPart.length;
      }

      return right!.indexOf(searchTerm, 0) + leftLength;
    } else {
      int rightIndex = right!.indexOf(searchTerm, start - leftLength);
      return rightIndex == -1 ? -1 : rightIndex + leftLength;
    }
  }

  @override
  int get length => _length;

  @override
  int get lineCount => _lineCount;

  @override
  List<int> get lineStarts => _lineStarts;

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
    updateLineStarts();
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
    updateLineStarts();
    return this;
  }

  @override
  List<String> sliceLines(int startLine, int endLine) {
    List<String> result = [];
    int currentLine = startLine;

    while (currentLine < min(endLine, _lineStarts.length)) {
      int start = _lineStarts[currentLine];
      int end = currentLine + 1 < _lineStarts.length
          ? _lineStarts[currentLine + 1]
          : _length;
      result.add(slice(start, end));
      currentLine++;
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

  @override
  String toString() => '${left.toString()}${right.toString()}';
}
