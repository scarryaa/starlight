import 'package:flutter/material.dart';
import 'package:starlight/features/editor/services/lsp_client.dart';

class SyntaxHighlighter extends ChangeNotifier {
  Map<String, TextStyle> _styles = {};
  final Map<int, List<TextSpan>> _cachedHighlights = {};
  int _lastProcessedVersion = -1;
  String _language;
  ThemeMode _currentThemeMode;
  late final LspClient _lspClient;
  List<int> _semanticTokens = [];
  bool _semanticTokensReady = false;

  SyntaxHighlighter({
    String language = 'dart',
    required ThemeMode initialThemeMode,
    required LspClient lspClient,
  })  : _language = language,
        _currentThemeMode = initialThemeMode,
        _lspClient = lspClient;

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
      'Stream',
      'Object',
      'dynamic',
      'Null',
      'Never'
    ],
  };

  void updateTheme(ThemeMode newThemeMode, BuildContext context) {
    if (_currentThemeMode != newThemeMode) {
      _currentThemeMode = newThemeMode;
      updateStyles(context);
      invalidateCache();
      notifyListeners();
    }
  }

  void updateStyles(BuildContext context) {
    final isDark = _currentThemeMode == ThemeMode.dark ||
        (_currentThemeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    // Base colors
    final Color primary =
        isDark ? const Color(0xFF61AFEF) : const Color(0xFF0A84FF);
    final Color secondary =
        isDark ? const Color(0xFFE5C07B) : const Color(0xFFFF9500);
    final Color tertiary =
        isDark ? const Color(0xFFC678DD) : const Color(0xFFAF52DE);
    final Color quaternary =
        isDark ? const Color(0xFF98C379) : const Color(0xFF30D158);
    final Color quinary =
        isDark ? const Color(0xFFE06C75) : const Color(0xFFFF453A);

    // Text colors
    final Color defaultText =
        isDark ? const Color(0xFFABB2BF) : const Color(0xFF2C3E50);
    final Color dimmedText =
        isDark ? const Color(0xFF6B727D) : const Color(0xFF8E8E93);
    _styles = {
      // Keywords and control flow
      'keyword': TextStyle(color: primary, fontWeight: FontWeight.bold),
      'control': TextStyle(color: primary, fontWeight: FontWeight.bold),

      // Types and classes
      'type': TextStyle(color: secondary),
      'class': TextStyle(color: secondary, fontWeight: FontWeight.bold),

      // Functions and methods
      'function': TextStyle(color: tertiary),
      'method': TextStyle(color: tertiary),

      // Variables and properties
      'variable': TextStyle(color: defaultText),
      'property': TextStyle(color: quaternary),

      // Strings and numbers
      'string': TextStyle(color: quaternary),
      'number': TextStyle(color: quinary),

      // Comments
      'comment': TextStyle(color: dimmedText, fontStyle: FontStyle.italic),

      // Operators and punctuation
      'operator': TextStyle(color: primary),
      'punctuation': TextStyle(color: defaultText),

      // Annotations and decorators
      'annotation': TextStyle(color: quinary, fontStyle: FontStyle.italic),

      // Default text
      'default': TextStyle(color: defaultText),

      // Additional specific styles
      'constant': TextStyle(color: quinary, fontWeight: FontWeight.bold),
      'parameter': TextStyle(color: quaternary),
      'typeParameter': TextStyle(color: secondary, fontStyle: FontStyle.italic),
      'namespace': TextStyle(color: defaultText, fontWeight: FontWeight.bold),
      'constructor': TextStyle(color: tertiary, fontWeight: FontWeight.bold),
      'regexp': TextStyle(color: quinary),
      'modifier': TextStyle(color: primary, fontStyle: FontStyle.italic),
    };
  }

  List<TextSpan> highlightLine(String line, int lineNumber, int version) {
    if (_cachedHighlights.containsKey(lineNumber) &&
        version == _lastProcessedVersion) {
      return _cachedHighlights[lineNumber]!;
    }

    final spans = _processLine(line, lineNumber);
    _cachedHighlights[lineNumber] = spans;
    _lastProcessedVersion = version;

    if (_semanticTokensReady) {
      final semanticSpans = _getSemanticSpans(line, lineNumber, 0);
      spans.addAll(semanticSpans);
    }

    return spans;
  }

  Future<void> updateSemanticTokens(String uri) async {
    _semanticTokens = await _lspClient.getSemanticTokens(uri);
    _semanticTokensReady = true;
    print("Received ${_semanticTokens.length} semantic tokens");

    _updateAffectedLines();
    notifyListeners();
  }

  void _updateAffectedLines() {
    for (int i = 0; i < _semanticTokens.length; i += 5) {
      int lineNumber = _semanticTokens[i]; // Get affected line
      _cachedHighlights.remove(lineNumber); // Clear cache for affected lines
    }
  }

  List<TextSpan> _processLine(String line, int lineNumber) {
    final spans = <TextSpan>[];
    final fullPattern = _getFullPattern();
    int lastMatchEnd = 0;

    for (final match in fullPattern.allMatches(line)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: line.substring(lastMatchEnd, match.start),
          style: _styles['default'],
        ));
      }

      final matchedText = match.group(0)!;
      final type = _getHighlightType(matchedText, lineNumber, match.start);
      spans.add(TextSpan(
          text: matchedText, style: _styles[type] ?? _styles['default']));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < line.length) {
      spans.add(TextSpan(
        text: line.substring(lastMatchEnd),
        style: _styles['default'],
      ));
    }

    return spans;
  }

  void _addSpan(
      List<TextSpan> spans, String text, int lineNumber, int columnNumber) {
    final semanticSpans = _getSemanticSpans(text, lineNumber, columnNumber);
    if (semanticSpans.isNotEmpty) {
      spans.addAll(semanticSpans);
    } else {
      // Process the text to see if it matches any patterns
      final pattern = _getFullPattern();
      final matches = pattern.allMatches(text);
      if (matches.isNotEmpty) {
        int lastMatchEnd = 0;
        for (final match in matches) {
          if (match.start > lastMatchEnd) {
            spans.add(TextSpan(
              text: text.substring(lastMatchEnd, match.start),
              style: _styles['default'],
            ));
          }
          final matchedText = match.group(0)!;
          final type = _getHighlightType(
            matchedText,
            lineNumber,
            columnNumber + match.start,
          );
          spans.add(TextSpan(
            text: matchedText,
            style: _styles[type] ?? _styles['default'],
          ));
          lastMatchEnd = match.end;
        }
        if (lastMatchEnd < text.length) {
          spans.add(TextSpan(
            text: text.substring(lastMatchEnd),
            style: _styles['default'],
          ));
        }
      } else {
        spans.add(TextSpan(text: text, style: _styles['default']));
      }
    }
  }

  List<TextSpan> _getSemanticSpans(
      String text, int lineNumber, int startColumn) {
    final spans = <TextSpan>[];
    int currentColumn = startColumn;

    for (int i = 0; i < text.length; i++) {
      final semanticType = _getSemanticTokenType(lineNumber, currentColumn);
      if (semanticType != null) {
        spans.add(TextSpan(text: text[i], style: _styles[semanticType]));
      } else {
        if (spans.isEmpty || spans.last.style != _styles['default']) {
          spans.add(TextSpan(text: text[i], style: _styles['default']));
        } else {
          spans.last = TextSpan(
            text: spans.last.text! + text[i],
            style: _styles['default'],
          );
        }
      }
      currentColumn++;
    }

    return spans;
  }

  RegExp _getFullPattern() {
    final keywordPattern =
        RegExp(r'\b(?:' + _languageKeywords[_language]!.join('|') + r')\b');
    final typePattern =
        RegExp(r'\b(?:' + _languageTypes[_language]!.join('|') + r')\b');
    const commentPattern = r'//.*|/\*[\s\S]*?\*/';
    const stringPattern = '"(?:\\\\.|[^\\\\"])*"|\'(?:\\\\.|[^\\\\\'])*\'';
    const numberPattern = r'\b(?:0x[\da-fA-F]+|\d*\.?\d+(?:[eE][+-]?\d+)?)\b';
    const functionPattern = r'\b[a-zA-Z_]\w*\s*(?=\()';
    const classNamePattern = r'\b[A-Z][a-zA-Z0-9_]*\b';
    const genericTypePattern = r'<[^>]+>';
    const namedParameterPattern = r'\b\w+(?=\s*:)';
    const constantPattern = r'\b[A-Z][A-Z0-9_]*\b';
    const annotationPattern = r'@\w+';
    const operatorPattern = r'=>|\?\?|\.\.\.|\?\.|\?\?=';
    const builtInIdentifierPattern = r'\b(true|false|null|this|super)\b';
    const flutterWidgetPattern =
        r'\b(MultiProvider|ChangeNotifierProvider|Provider)\b';
    const asyncKeywordPattern = r'\b(async|await)\b';

    return RegExp(
      [
        keywordPattern.pattern,
        typePattern.pattern,
        commentPattern,
        stringPattern,
        numberPattern,
        functionPattern,
        classNamePattern,
        genericTypePattern,
        namedParameterPattern,
        constantPattern,
        annotationPattern,
        operatorPattern,
        builtInIdentifierPattern,
        flutterWidgetPattern,
        asyncKeywordPattern,
      ].join('|'),
      multiLine: true,
    );
  }

  String _getHighlightType(String text, int lineNumber, int columnNumber) {
    if (_languageKeywords[_language]!.contains(text)) return 'keyword';
    if (RegExp(r'\b(?:class|enum|mixin)\s+([A-Z]\w*)').hasMatch(text)) {
      return 'className';
    }
    if (RegExp(r'\b[A-Z]\w*\b(?!\s*\.)').hasMatch(text)) return 'type';
    if (_languageTypes[_language]!.contains(text)) return 'type';
    if (text.startsWith('"') || text.startsWith("'")) return 'string';
    if (RegExp(r'\b[a-z]\w*\s*(?=\.)').hasMatch(text)) return 'instance';
    if (RegExp(r'\b([A-Z]\w*)(?=\s*\.\s*\w+\s*\()').hasMatch(text)) {
      return 'constructor';
    }
    if (RegExp(r'\b[A-Z]\w*\s*\.\s*[a-z]\w*(?=\s*\()').hasMatch(text)) {
      return 'staticMethod';
    }
    if (text.startsWith('//') || text.startsWith('/*')) return 'comment';
    if (RegExp(r'\b(?:0x[\da-fA-F]+|\d*\.?\d+(?:[eE][+-]?\d+)?)\b')
        .hasMatch(text)) return 'number';
    if (RegExp(r'\b[a-zA-Z_]\w*\s*(?=\()|(?:get|set)\s+[a-zA-Z_]\w*\b')
        .hasMatch(text)) return 'function';
    if (text.startsWith('@')) {
      if (text == '@override') return 'override';
      return 'decorator';
    }
    if (text.startsWith(r'$')) return 'interpolation';
    if (RegExp(r'<[A-Z]\w*(?:,\s*[A-Z]\w*)*>').hasMatch(text)) return 'generic';
    if (RegExp(r'\{[^}]+\}').hasMatch(text)) return 'namedParameter';
    if (RegExp(r'(?:async\s*)?\([^)]*\)\s*async\s*=>').hasMatch(text)) {
      return 'asyncArrowFunction';
    }
    if (RegExp(r'\b[A-Z][a-zA-Z0-9_]*\b').hasMatch(text)) return 'className';
    if (RegExp(r'\b[A-Z][A-Z0-9_]*\b').hasMatch(text)) return 'constant';
    if (RegExp(r'=>|\?\?|\.\.\.|\?\.|\?\?=').hasMatch(text)) return 'operator';
    if (['true', 'false', 'null', 'this', 'super'].contains(text)) {
      return 'builtInIdentifier';
    }
    if (['MultiProvider', 'ChangeNotifierProvider', 'Provider']
        .contains(text)) {
      return 'flutterWidget';
    }
    if (['async', 'await'].contains(text)) return 'asyncKeyword';
    return 'default';
  }

  String? _getSemanticTokenType(int lineNumber, int columnNumber) {
    int currentLine = 0;
    int currentColumn = 0;
    int currentTokenIndex = 0;

    while (currentTokenIndex < _semanticTokens.length - 4) {
      int deltaLine = _semanticTokens[currentTokenIndex];
      int deltaColumn = _semanticTokens[currentTokenIndex + 1];
      int tokenLength = _semanticTokens[currentTokenIndex + 2];
      int tokenType = _semanticTokens[currentTokenIndex + 3];
      int tokenModifiers = _semanticTokens[currentTokenIndex + 4];

      currentLine += deltaLine;
      if (deltaLine > 0) {
        currentColumn = deltaColumn;
      } else {
        currentColumn += deltaColumn;
      }

      if (currentLine == lineNumber &&
          columnNumber >= currentColumn &&
          columnNumber < currentColumn + tokenLength) {
        return _mapTokenTypeToStyle(tokenType, tokenModifiers);
      }

      if (currentLine > lineNumber) {
        break;
      }

      currentTokenIndex += 5;
    }

    return null;
  }

  String _mapTokenTypeToStyle(int tokenType, int tokenModifiers) {
    switch (tokenType) {
      case 0:
        return 'namespace';
      case 1:
        return 'type';
      case 2:
        return 'class';
      case 3:
        return 'enum';
      case 4:
        return 'interface';
      case 5:
        return 'struct';
      case 6:
        return 'typeParameter';
      case 7:
        return 'parameter';
      case 8:
        return 'variable';
      case 9:
        return 'property';
      case 10:
        return 'enumMember';
      case 11:
        return 'event';
      case 12:
        return 'function';
      case 13:
        return 'method';
      case 14:
        return 'macro';
      case 15:
        return 'keyword';
      case 16:
        return 'modifier';
      case 17:
        return 'comment';
      case 18:
        return 'string';
      case 19:
        return 'number';
      case 20:
        return 'regexp';
      case 21:
        return 'operator';
      default:
        return 'default';
    }
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
