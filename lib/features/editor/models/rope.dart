class Rope {
  final Node _root;
  int length = 0;
  List<int> lineStarts = [0];
  static const splitThreshold = 1024;

  Rope(String? initialText) : _root = Node() {
    _root.text = initialText ?? "";
    length = initialText?.length ?? 0;
  }

  // Getters
  get text => _root.text;
  get lineCount => lineStarts.length;

  void insert(String s, int position) {
    Node? foundNode = findNodeFromCharIndex(position,
        updateWeights: true, weightToAdd: s.length, subtract: false);
    if (foundNode == null) throw Exception("Node to insert at not found.");

    foundNode.text = foundNode.text.substring(0, position) +
        s +
        foundNode.text.substring(position, foundNode.text.length);

    // Update line starts if needed
    int closestLineStart = _findClosestLineStartFromCharIndex(position);
    int closestLineStartIndex = lineStarts.indexOf(closestLineStart);
    for (int i = closestLineStartIndex + 1; i < lineStarts.length; i++) {
      lineStarts[i]++;
    }

    if (s == '\n') {
      lineStarts.insert(closestLineStartIndex + 1, position);
    }

    if (foundNode.weight > splitThreshold) {
      balance();
    }
  }

  String charAt(int index) {
    return findNodeFromCharIndex(index)!.text[index];
  }

  String getLine(int index) {
    return _root.text.split('\n')[index];
  }

  void delete(int position) {
    Node? foundNode = findNodeFromCharIndex(position,
        updateWeights: true, weightToAdd: 1, subtract: true);
    if (foundNode == null) throw Exception("Node to delete at not found.");
    int closestLineStart = _findClosestLineStartFromCharIndex(position);
    int closestLineStartIndex = lineStarts.indexOf(closestLineStart);

    // Remove corresponding line start if needed
    if (foundNode.text.substring(position, position + 1) == '\n') {
      lineStarts.remove(position);
    } else {
      for (int i = closestLineStartIndex + 1; i < lineStarts.length; i++) {
        lineStarts[i]--;
      }
    }

    foundNode.text = foundNode.text.substring(0, position) +
        foundNode.text.substring(position + 1, foundNode.text.length);
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
    if (lineNumber > lineStarts.length) return 0;
    if (lineNumber == 0) {
      return _root.text.split('\n')[0].length;
    }

    if (lineNumber == lineStarts.length - 1) {
      return _root.weight - lineStarts[lineNumber] - 1;
    }

    return lineStarts[lineNumber + 1] - lineStarts[lineNumber] - 1;
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
