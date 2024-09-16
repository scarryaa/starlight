import 'package:flutter/material.dart';

class SyntaxHighlighter {
  final Map<String, TextStyle> _styles;
  final Map<int, List<TextSpan>> _cachedHighlights = {};
  int _lastProcessedVersion = -1;
  String language;

  SyntaxHighlighter(this._styles, {this.language = 'dart'});

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

  List<TextSpan> highlightLine(String line, int lineNumber, int version) {
    if (_cachedHighlights.containsKey(lineNumber) &&
        version == _lastProcessedVersion) {
      return _cachedHighlights[lineNumber]!;
    }

    List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    // Define regex patterns
    final keywordPattern =
        RegExp(r'\b(?:' + _languageKeywords[language]!.join('|') + r')\b');
    final typePattern =
        RegExp(r'\b(?:' + _languageTypes[language]!.join('|') + r')\b');
    final commentPattern = RegExp(r'//.*|/\*[\s\S]*?\*/');
    final stringPattern = RegExp(r'(?<!\\)"(?:\\.|[^\\"])*"');
    final numberPattern = RegExp(r'\b\d+(?:\.\d+)?\b');
    final functionPattern = RegExp(r'\b[a-zA-Z_]\w*(?=\s*\()');

    // Combine all patterns
    final fullPattern = RegExp(
      '${keywordPattern.pattern}|${typePattern.pattern}|${commentPattern.pattern}|${stringPattern.pattern}|${numberPattern.pattern}|${functionPattern.pattern}',
      multiLine: true,
    );

    for (Match match in fullPattern.allMatches(line)) {
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

    _cachedHighlights[lineNumber] = spans;
    _lastProcessedVersion = version;
    return spans;
  }

  String _getHighlightType(String text) {
    if (_languageKeywords[language]!.contains(text)) return 'keyword';
    if (_languageTypes[language]!.contains(text)) return 'type';
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

  void setLanguage(String newLanguage) {
    if (_languageKeywords.containsKey(newLanguage)) {
      language = newLanguage;
      invalidateCache();
    } else {
      throw ArgumentError('Unsupported language: $newLanguage');
    }
  }
}
