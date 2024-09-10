import 'dart:math';

class Rope {
  Node root = Node();
  int length = 0;
  List<int> lineStarts = [0];

  Rope([String? initialContent]) {
    if (initialContent != null && initialContent.isNotEmpty) {
      insert(0, initialContent);
    }
  }

  void insert(int index, String text) {
    if (length == 0) {
      root = Node(data: text, length: text.length);
      length = text.length;
      _updateLineStarts(0, text);
      return;
    }
    _checkIfIndexOutOfRange(index);
    Node? n;
    int adjustedIndex;
    (n, adjustedIndex) = findNodeFromCharacterIndex(index);
    if (n != null) {
      String beforeInsert = n.data.substring(0, adjustedIndex);
      String afterInsert = n.data.substring(adjustedIndex);
      n.data = beforeInsert + text + afterInsert;
      updateLengths(root);
      length += text.length;
      _updateLineStarts(index, text);
    }
  }

  void delete(int index, int deleteLength) {
    if (deleteLength <= 0 || length == 0) return;
    _checkIfIndexOutOfRange(index);
    _checkIfIndexOutOfRange(index + deleteLength - 1);
    Node? node;
    int adjustedIndex;
    (node, adjustedIndex) = findNodeFromCharacterIndex(index);
    if (node != null) {
      int actualDeleteLength =
          min(deleteLength, node.data.length - adjustedIndex);
      String deletedText = node.data
          .substring(adjustedIndex, adjustedIndex + actualDeleteLength);
      node.data = node.data.substring(0, adjustedIndex) +
          node.data.substring(adjustedIndex + actualDeleteLength);
      updateLengths(root);
      length -= actualDeleteLength;
      _updateLineStartsAfterDelete(index, deletedText);
    }
  }

  void _updateLineStarts(int index, String insertedText) {
    int newLineCount = '\n'.allMatches(insertedText).length;
    if (newLineCount == 0) {
      for (int i = 1; i < lineStarts.length; i++) {
        if (lineStarts[i] > index) {
          lineStarts[i] += insertedText.length;
        }
      }
      return;
    }

    int currentLine = _getLineNumberFromIndex(index);
    List<int> newLinePositions =
        insertedText.split('\n').map((s) => s.length).toList();
    int currentPosition = index - lineStarts[currentLine];

    for (int i = 0; i < newLineCount; i++) {
      currentPosition += newLinePositions[i] + 1;
      lineStarts.insert(
          currentLine + 1 + i, lineStarts[currentLine] + currentPosition);
    }

    for (int i = currentLine + newLineCount + 1; i < lineStarts.length; i++) {
      lineStarts[i] += insertedText.length;
    }
  }

  void _updateLineStartsAfterDelete(int index, String deletedText) {
    int deletedNewLineCount = '\n'.allMatches(deletedText).length;
    if (deletedNewLineCount == 0) {
      for (int i = 1; i < lineStarts.length; i++) {
        if (lineStarts[i] > index) {
          lineStarts[i] -= deletedText.length;
        }
      }
      return;
    }

    int currentLine = _getLineNumberFromIndex(index);
    List<int> linesToRemove = [];

    for (int i = currentLine + 1;
        i < lineStarts.length && i <= currentLine + deletedNewLineCount;
        i++) {
      if (lineStarts[i] <= index + deletedText.length) {
        linesToRemove.add(i);
      }
    }

    linesToRemove.reversed.forEach(lineStarts.removeAt);

    for (int i = currentLine + 1; i < lineStarts.length; i++) {
      lineStarts[i] -= deletedText.length;
    }

    // Handle the case when deleting the last newline character
    if (currentLine == lineStarts.length - 1 && deletedText.endsWith('\n')) {
      lineStarts.removeLast();
    }
  }

  @override
  String toString() {
    return _toString(root);
  }

  String _toString(Node? node) {
    if (node == null) return '';
    if (node.data.isNotEmpty) return node.data;
    return _toString(node.left) + _toString(node.right);
  }

  String getSlice(int start, int end) {
    if (start < 0 || end > length || start > end) {
      throw RangeError('Invalid start or end index');
    }

    return _getSliceInternal(root, start, end);
  }

  String _getSliceInternal(Node? node, int start, int end) {
    if (node == null) return '';

    if (node.data.isNotEmpty) {
      return node.data.substring(max(0, start), min(end, node.data.length));
    }

    int leftLength = node.left?.length ?? 0;

    if (end <= leftLength) {
      return _getSliceInternal(node.left, start, end);
    }

    if (start >= leftLength) {
      return _getSliceInternal(
          node.right, start - leftLength, end - leftLength);
    }

    String leftPart = _getSliceInternal(node.left, start, leftLength);
    String rightPart = _getSliceInternal(node.right, 0, end - leftLength);

    return leftPart + rightPart;
  }

  int _getLineNumberFromIndex(int index) {
    if (index < 0) return 0;
    if (index >= length) return lineStarts.length - 1;
    int line = lineStarts.indexWhere((start) => start > index) - 1;
    return line >= 0 ? line : lineStarts.length - 1;
  }

  int getLineStartFromIndex(int index) {
    int lineNumber = _getLineNumberFromIndex(index);
    return lineStarts[lineNumber];
  }

  (Node?, int) findNodeFromCharacterIndex(int index) {
    _checkIfIndexOutOfRange(index);
    return findNodeFromCharacterIndexInternal(root, index);
  }

  (Node, int) findNodeFromCharacterIndexInternal(Node n, int index) {
    if (n.data.isNotEmpty) {
      return (n, index);
    }
    if (index > n.length) {
      if (n.right == null) {
        return (n, index);
      }
      return findNodeFromCharacterIndexInternal(n.right!, index - n.length);
    } else {
      if (n.left == null) {
        return (n, index);
      }
      return findNodeFromCharacterIndexInternal(n.left!, index);
    }
  }

  void updateLengths(Node? node) {
    if (node == null) return;
    node.length = node.data.length;
    if (node.left != null) {
      updateLengths(node.left);
      node.length += node.left!.length;
    }
    if (node.right != null) {
      updateLengths(node.right);
      node.length += node.right!.length;
    }
  }

  void _checkIfIndexOutOfRange(int index) {
    if (index < 0 || index > length) {
      throw RangeError.range(index, 0, length, 'index');
    }
  }

  int getLineNumberFromIndex(int index) {
    if (index < 0) return 0;
    if (index >= length) return lineStarts.length - 1;

    int low = 0;
    int high = lineStarts.length - 1;

    while (low <= high) {
      int mid = (low + high) ~/ 2;
      if (lineStarts[mid] > index) {
        high = mid - 1;
      } else if (mid < lineStarts.length - 1 && lineStarts[mid + 1] <= index) {
        low = mid + 1;
      } else {
        return mid;
      }
    }

    return low;
  }

  int getLineEndFromIndex(int index) {
    int lineNumber = getLineNumberFromIndex(index);
    if (lineNumber >= lineStarts.length - 1) {
      return length - 1;
    }
    return lineStarts[lineNumber + 1] - 1;
  }

  String getLineContent(int lineNumber) {
    if (lineNumber < 0 || lineNumber >= lineStarts.length) {
      throw RangeError.range(
          lineNumber, 0, lineStarts.length - 1, 'lineNumber');
    }
    int start = lineStarts[lineNumber];
    int end = (lineNumber < lineStarts.length - 1)
        ? lineStarts[lineNumber + 1] - 1
        : length - 1;
    return toString().substring(start, end + 1);
  }

  int getLineCount() {
    return lineStarts.length;
  }
}

class Node {
  Node? left;
  Node? right;
  String data = "";
  int length = 0;
  Node({this.left, this.right, this.data = "", this.length = 0});
}
