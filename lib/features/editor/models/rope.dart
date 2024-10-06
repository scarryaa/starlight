class Rope {
  final Node _root;
  int length = 0;
  List<int> lineStarts = [0];
  static const splitThreshold = 1024;

  Rope([String? initialText]) : _root = Node() {
    if (initialText == null || initialText.isEmpty) {
      _root.text = "\n";
      length = 1;
    } else {
      _root.text = initialText.endsWith("\n") ? initialText : "$initialText\n";
      length = _root.text.length;
    }
    _updateLineStarts();
  }

  void _updateLineStarts() {
    lineStarts = [0];
    for (int i = 1; i < _root.text.length; i++) {
      if (_root.text[i] == '\n') {
        lineStarts.add(i + 1);
      }
    }
  }

  // Getters
  get text => _root.text;
  get lineCount => lineStarts.length;

  void insert(String s, int position) {
    if (position < 0 || position > length) {
      throw RangeError('Insert position out of bounds');
    }

    _root.text =
        _root.text.substring(0, position) + s + _root.text.substring(position);
    length += s.length;

    // Update lineStarts
    int lineIndex = _findLineIndex(position);
    for (int i = lineIndex + 1; i < lineStarts.length; i++) {
      lineStarts[i] += s.length;
    }

    // Add new line starts if we're inserting newlines
    int newLineCount = s.split('\n').length - 1;
    if (newLineCount > 0) {
      int newLinePosition = position;
      for (int i = 0; i < newLineCount; i++) {
        newLinePosition = _root.text.indexOf('\n', newLinePosition) + 1;
        lineStarts.insert(lineIndex + 1 + i, newLinePosition);
      }
    }
  }

  void delete(int position, int deletionLength) {
    if (position < 0 ||
        position >= length ||
        position + deletionLength > length) {
      throw RangeError('Delete range out of bounds');
    }

    String deletedSubstring =
        _root.text.substring(position, position + deletionLength);

    _root.text = _root.text.substring(0, position) +
        _root.text.substring(position + deletionLength);
    length -= deletionLength;

    int startLineIndex = _findLineIndex(position);
    int endLineIndex = _findLineIndex(position + deletionLength - 1);

    int deletedNewlines = '\n'.allMatches(deletedSubstring).length;

    for (int i = startLineIndex + 1; i < lineStarts.length; i++) {
      if (i > endLineIndex) {
        lineStarts[i] -= deletionLength;
      } else if (deletedNewlines > 0) {
        lineStarts.removeAt(i);
        i--;
        deletedNewlines--;
      }
    }

    if (deletedSubstring.endsWith('\n') &&
        endLineIndex + 1 < lineStarts.length) {
      lineStarts.removeAt(endLineIndex + 1);
    }
  }

  int _findLineIndex(int position) {
    for (int i = 1; i < lineStarts.length; i++) {
      if (lineStarts[i] > position) {
        return i - 1;
      }
    }
    return lineStarts.length - 1;
  }

  String charAt(int index) {
    return findNodeFromCharIndex(index)!.text[index];
  }

  String getLine(int index) {
    return _root.text.split('\n')[index];
  }

  Node? findNodeFromCharIndex(int index,
      {bool updateWeights = false,
      bool subtract = false,
      int weightToAdd = 0}) {
    return _findNodeFromCharIndexRecursive(_root, index,
        updateWeights: updateWeights,
        weightToAdd: weightToAdd,
        subtract: subtract);
  }

  Node? _findNodeFromCharIndexRecursive(Node node, int index,
      {bool updateWeights = false,
      bool subtract = false,
      int weightToAdd = 0}) {
    if (updateWeights) {
      if (subtract) {
        node.weight -= weightToAdd;
      } else {
        node.weight += weightToAdd;
      }
    }

    if (node.right != null && index > node.right!.weight) {
      return _findNodeFromCharIndexRecursive(
          _root.right!, index - node.right!.weight,
          updateWeights: updateWeights,
          weightToAdd: weightToAdd,
          subtract: subtract);
    }

    if (node.left != null) {
      return _findNodeFromCharIndexRecursive(node.left!, index,
          updateWeights: updateWeights,
          weightToAdd: weightToAdd,
          subtract: subtract);
    }

    return _root;
  }

  int findClosestLineStart(int index) {
    if (lineStarts.isEmpty) return 0;
    return lineStarts[index];
  }

  int _findClosestLineStartFromCharIndex(int index) {
    if (lineStarts.isEmpty) return 0;

    return _findClosestLineStartRecursive(lineStarts, index);
  }

  int _findClosestLineStartRecursive(List<int> lineStarts, int index) {
    if (lineStarts.length == 1) {
      return lineStarts[0] <= index ? lineStarts[0] : 0;
    }

    int mid = lineStarts.length ~/ 2;
    if (index < lineStarts[mid]) {
      return _findClosestLineStartRecursive(lineStarts.sublist(0, mid), index);
    } else {
      return _findClosestLineStartRecursive(lineStarts.sublist(mid), index);
    }
  }

  int getLineLength(int lineNumber) {
    if (lineNumber < 0 || lineNumber >= lineStarts.length) {
      return 0;
    }

    int start = lineStarts[lineNumber];
    int end;
    if (lineNumber == lineStarts.length - 1) {
      end = length - 1;
    } else {
      end = lineStarts[lineNumber + 1] - 1; // Exclude the newline character
    }

    return end - start;
  }

  void balance() {}

  void _balanceRecursive() {}
}

class Node {
  int weight = 0;
  String text = "";
  Node? left;
  Node? right;
}
