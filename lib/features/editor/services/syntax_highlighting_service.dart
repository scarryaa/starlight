import 'package:flutter/material.dart';

class SyntaxHighlightingService {
  static const Map<String, Color> _darkThemeColors = {
    'keyword': Color(0xFF569CD6),
    'string': Color(0xFFCE9178),
    'comment': Color(0xFF6A9955),
    'number': Color(0xFFB5CEA8),
  };

  static const Map<String, Color> _lightThemeColors = {
    'keyword': Color(0xFF0000FF),
    'string': Color(0xFFA31515),
    'comment': Color(0xFF008000),
    'number': Color(0xFF098658),
  };

  static final Set<String> _keywords = {
    'void', 'int', 'double', 'String', 'List', 'Map', 'var', 'final', 'const',
    'if', 'else', 'for', 'while', 'do', 'switch', 'case', 'break', 'continue',
    'return', 'class', 'extends', 'implements', 'new', 'this', 'super', 'try',
    'catch', 'throw', 'import', 'export', 'library', 'part', 'typedef', 'enum'
  };

  List<TextSpan> highlightSyntax(String text, bool isDarkMode) {
    List<TextSpan> spans = [];
    Map<String, Color> colors = isDarkMode ? _darkThemeColors : _lightThemeColors;
    Color defaultColor = isDarkMode ? Colors.white : Colors.black;

    StringBuffer currentWord = StringBuffer();
    bool inString = false;
    bool inComment = false;
    String stringDelimiter = '';

    void addSpan(String text, Color color) {
      if (text.isNotEmpty) {
        spans.add(TextSpan(text: text, style: TextStyle(color: color)));
      }
    }

    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      
      if (inComment) {
        currentWord.write(char);
        if (i == text.length - 1) {
          addSpan(currentWord.toString(), colors['comment']!);
          currentWord.clear();
        }
      } else if (inString) {
        currentWord.write(char);
        if (char == stringDelimiter && text[i - 1] != '\\') {
          addSpan(currentWord.toString(), colors['string']!);
          inString = false;
          currentWord.clear();
        }
      } else if (char == '//' && !inString) {
        if (currentWord.isNotEmpty) {
          addSpan(currentWord.toString(), defaultColor);
          currentWord.clear();
        }
        inComment = true;
        currentWord.write(char);
      } else if ((char == '"' || char == "'") && !inString) {
        if (currentWord.isNotEmpty) {
          addSpan(currentWord.toString(), defaultColor);
          currentWord.clear();
        }
        inString = true;
        stringDelimiter = char;
        currentWord.write(char);
      } else if (char.trim().isEmpty) {
        if (currentWord.isNotEmpty) {
          String word = currentWord.toString();
          if (_keywords.contains(word)) {
            addSpan(word, colors['keyword']!);
          } else if (RegExp(r'^\d+$').hasMatch(word)) {
            addSpan(word, colors['number']!);
          } else {
            addSpan(word, defaultColor);
          }
          currentWord.clear();
        }
        addSpan(char, defaultColor);  // Preserve whitespace
      } else {
        currentWord.write(char);
      }
    }

    // Handle any remaining text
    if (currentWord.isNotEmpty) {
      String word = currentWord.toString();
      if (_keywords.contains(word)) {
        addSpan(word, colors['keyword']!);
      } else if (RegExp(r'^\d+$').hasMatch(word)) {
        addSpan(word, colors['number']!);
      } else {
        addSpan(word, defaultColor);
      }
    }

    return spans;
  }
}
