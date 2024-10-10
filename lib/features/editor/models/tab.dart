import 'package:starlight/features/editor/models/cursor_position.dart';

class TabModel {
  final String fullPath;
  final String fullAbsolutePath;
  final String path;
  String content;
  final bool isSelected;
  bool isModified;
  final CursorPosition cursorPosition;

  TabModel({
    required this.fullPath,
    required this.fullAbsolutePath,
    required this.path,
    required this.content,
    this.isSelected = false,
    this.isModified = false,
    this.cursorPosition = const CursorPosition(line: 0, column: 0),
  });

  TabModel copyWith({
    String? fullPath,
    String? fullAbsolutePath,
    String? path,
    String? content,
    bool? isSelected,
    bool? isModified,
    CursorPosition? cursorPosition,
  }) {
    return TabModel(
      fullPath: fullPath ?? this.fullPath,
      fullAbsolutePath: fullAbsolutePath ?? this.fullAbsolutePath,
      path: path ?? this.path,
      content: content ?? this.content,
      isSelected: isSelected ?? this.isSelected,
      isModified: isModified ?? this.isModified,
      cursorPosition: cursorPosition ?? this.cursorPosition,
    );
  }
}
