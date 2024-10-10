import 'package:flutter/foundation.dart';
import 'package:starlight/features/editor/models/cursor_position.dart';

class CaretPositionNotifier extends ChangeNotifier {
  CursorPosition _position = const CursorPosition(line: 0, column: 0);

  CursorPosition get position => _position;

  void updatePosition(int line, int column) {
    _position = CursorPosition(line: line, column: column);
    notifyListeners();
  }
}

