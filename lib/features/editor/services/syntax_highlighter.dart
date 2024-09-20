import 'package:flutter/material.dart';

class SyntaxHighlighter extends ChangeNotifier {
  Map<String, TextStyle> _styles;
  final Map<int, List<TextSpan>> _cachedHighlights = {};
  int _lastProcessedVersion = -1;
  String _language;
  ThemeMode _currentThemeMode;

  SyntaxHighlighter(this._styles,
      {String language = 'dart', required ThemeMode initialThemeMode})
      : _language = language,
        _currentThemeMode = initialThemeMode;

  static const Map<String, List<String>> _languageKeywords = {
    'dart': [
      'abstract',
      'as',
      'assert',
      'async',
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'covariant',
      'default',
      'deferred',
      'do',
      'dynamic',
      'else',
      'enum',
      'export',
      'extends',
      'extension',
      'external',
      'factory',
      'false',
      'final',
      'finally',
      'for',
      'Function',
      'get',
      'hide',
      'if',
      'implements',
      'import',
      'in',
      'interface',
      'is',
      'library',
      'mixin',
      'new',
      'null',
      'on',
      'operator',
      'part',
      'rethrow',
      'return',
      'set',
      'show',
      'static',
      'super',
      'switch',
      'sync',
      'this',
      'throw',
      'true',
      'try',
      'typedef',
      'var',
      'void',
      'while',
      'with',
      'yield'
    ],
  };

  static const Map<String, List<String>> _languageTypes = {
    'dart': [
      'int',
      'double',
      'String',
      'bool',
      'List',
      'Map',
      'Set',
      'Future',
      'Stream'
    ],
  };

  void updateTheme(ThemeMode newThemeMode, BuildContext context) {
    if (_currentThemeMode != newThemeMode) {
      _currentThemeMode = newThemeMode;
      _updateStyles(context);
      invalidateCache();
      notifyListeners();
    }
  }

  void _updateStyles(BuildContext context) {
    final brightness = _currentThemeMode == ThemeMode.system
        ? MediaQuery.of(context).platformBrightness
        : _currentThemeMode == ThemeMode.dark
            ? Brightness.dark
            : Brightness.light;

    final isDark = brightness == Brightness.dark;

    _styles = {
      'keyword': TextStyle(
        color: isDark ? Colors.blue[300] : Colors.blue[800],
      ),
      'type': TextStyle(
        color: isDark ? Colors.green[300] : Colors.green[800],
      ),
      'comment': TextStyle(
        color: isDark ? Colors.grey[500] : Colors.grey[700],
      ),
      'string': TextStyle(
        color: isDark ? Colors.red[300] : Colors.red[800],
      ),
      'number': TextStyle(
        color: isDark ? Colors.purple[300] : Colors.purple[800],
      ),
      'function': TextStyle(
        color: isDark ? Colors.orange[300] : Colors.orange[800],
      ),
      'default': TextStyle(
        color: isDark ? Colors.white : Colors.black,
      ),
    };
  }

  List<TextSpan> highlightLine(String line, int lineNumber, int version) {
    if (_cachedHighlights.containsKey(lineNumber) &&
        version == _lastProcessedVersion) {
      return _cachedHighlights[lineNumber]!;
    }

    final spans = _processLine(line);
    _cachedHighlights[lineNumber] = spans;
    _lastProcessedVersion = version;
    return spans;
  }

  List<TextSpan> _processLine(String line) {
    final spans = <TextSpan>[];
    final fullPattern = _getFullPattern();
    int lastMatchEnd = 0;

    for (final match in fullPattern.allMatches(line)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: line.substring(lastMatchEnd, match.start)));
      }

      final matchedText = match.group(0)!;
      final type = _getHighlightType(matchedText);
      spans.add(TextSpan(text: matchedText, style: _styles[type]));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < line.length) {
      spans.add(TextSpan(text: line.substring(lastMatchEnd)));
    }

    return spans;
  }

  RegExp _getFullPattern() {
    final keywordPattern =
        RegExp(r'\b(?:' + _languageKeywords[_language]!.join('|') + r')\b');
    final typePattern =
        RegExp(r'\b(?:' + _languageTypes[_language]!.join('|') + r')\b');
    const commentPattern = r'//.*|/\*[\s\S]*?\*/';
    const stringPattern = r'(?<!\\)"(?:\\.|[^\\"])*"';
    const numberPattern = r'\b\d+(?:\.\d+)?\b';
    const functionPattern = r'\b[a-zA-Z_]\w*(?=\s*\()';

    return RegExp(
      [
        keywordPattern.pattern,
        typePattern.pattern,
        commentPattern,
        stringPattern,
        numberPattern,
        functionPattern
      ].join('|'),
      multiLine: true,
    );
  }

  String _getHighlightType(String text) {
    if (_languageKeywords[_language]!.contains(text)) return 'keyword';
    if (_languageTypes[_language]!.contains(text)) return 'type';
    if (text.startsWith('//') || text.startsWith('/*')) return 'comment';
    if (text.startsWith('"')) return 'string';
    if (RegExp(r'\b\d+(?:\.\d+)?\b').hasMatch(text)) return 'number';
    if (RegExp(r'\b[a-zA-Z_]\w*(?=\s*\()').hasMatch(text)) return 'function';
    return 'default';
  }

  void invalidateCache() {
    _cachedHighlights.clear();
    _lastProcessedVersion = -1;
  }

  void updateLine(int lineNumber, int version) {
    _cachedHighlights.remove(lineNumber);
    _lastProcessedVersion = version;
  }

  set language(String newLanguage) {
    if (_languageKeywords.containsKey(newLanguage)) {
      _language = newLanguage;
      invalidateCache();
    } else {
      throw ArgumentError('Unsupported language: $newLanguage');
    }
  }

  String get language => _language;
}
