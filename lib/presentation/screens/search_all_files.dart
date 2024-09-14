import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class FileSearchResult {
  final String fileName;
  final String filePath;
  final String matchingLine;
  final int lineNumber;
  final int columnNumber;

  FileSearchResult({
    required this.fileName,
    required this.filePath,
    required this.matchingLine,
    required this.lineNumber,
    required this.columnNumber,
  });
}

class SearchAllFilesTab extends StatefulWidget {
  final String rootDirectory;
  final Function(File) onFileSelected;

  const SearchAllFilesTab({
    super.key,
    required this.rootDirectory,
    required this.onFileSelected,
  });

  @override
  _SearchAllFilesTabState createState() => _SearchAllFilesTabState();
}

class _SearchAllFilesTabState extends State<SearchAllFilesTab> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  final TextEditingController _includeController = TextEditingController();
  final TextEditingController _excludeController = TextEditingController();
  List<FileSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _isReplaceVisible = false;
  bool _isFiltersVisible = false;
  bool _matchCase = false;
  bool _matchWholeWord = false;
  bool _useRegex = false;
  Timer? _debounceTimer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCompactSearchBar(),
        if (_isFiltersVisible) _buildFiltersBar(),
        if (_isReplaceVisible) _buildReplaceBar(),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      title: Text(result.fileName),
                      subtitle: Text(
                          '${result.lineNumber}:${result.columnNumber} - ${result.matchingLine}'),
                      onTap: () => widget.onFileSelected(File(result.filePath)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Widget _buildCompactSearchBar() {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final Color defaultTextColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: _searchResults.isEmpty &&
                          _searchController.text.isNotEmpty
                      ? Colors.red
                      : defaultTextColor,
                ),
                decoration: InputDecoration(
                  hintText: 'Search in all files...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleButton(
                          'Aa', _matchCase, _toggleMatchCase, 'Match case'),
                      _buildToggleButton('W', _matchWholeWord,
                          _toggleMatchWholeWord, 'Match whole word'),
                      _buildToggleButton('.*', _useRegex, _toggleUseRegex,
                          'Use regular expression'),
                    ],
                  ),
                ),
                onChanged: _updateSearchTerm,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color: _isFiltersVisible
                    ? theme.colorScheme.primary
                    : defaultTextColor,
              ),
              onPressed: () =>
                  setState(() => _isFiltersVisible = !_isFiltersVisible),
              tooltip: _isFiltersVisible ? 'Hide filters' : 'Show filters',
            ),
            IconButton(
              icon: Icon(
                Icons.find_replace,
                color: _isReplaceVisible
                    ? theme.colorScheme.primary
                    : defaultTextColor,
              ),
              onPressed: () =>
                  setState(() => _isReplaceVisible = !_isReplaceVisible),
              tooltip: _isReplaceVisible ? 'Hide replace' : 'Show replace',
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: _cancelSearch,
              tooltip: 'Clear search',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _includeController,
              decoration: const InputDecoration(
                hintText: 'Include files (e.g., *.dart)',
                prefixIcon: Icon(Icons.add, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => _performSearch(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _excludeController,
              decoration: const InputDecoration(
                hintText: 'Exclude files (e.g., *.g.dart)',
                prefixIcon: Icon(Icons.remove, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => _performSearch(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplaceBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replaceController,
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: 'Replace...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.find_replace,
                    color: Colors.white, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: _updateReplaceTerm,
            ),
          ),
          TextButton(
            onPressed: _replaceAll,
            child: const Text('Replace All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
      String label, bool isActive, VoidCallback onPressed, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  void _cancelSearch() {
    setState(() {
      _isSearching = false;
      _searchResults = [];
      _searchController.clear();
    });
  }

  List<int> _findMatches(String text, String searchTerm) {
    List<int> positions = [];
    if (_useRegex) {
      try {
        RegExp regExp = RegExp(
          searchTerm,
          caseSensitive: _matchCase,
          multiLine: true,
        );
        for (Match match in regExp.allMatches(text)) {
          positions.add(match.start + 1);
        }
      } catch (e) {
        print('Invalid regex: $e');
      }
    } else {
      String pattern = _matchWholeWord
          ? r'\b' + RegExp.escape(searchTerm) + r'\b'
          : RegExp.escape(searchTerm);
      RegExp regExp = RegExp(
        pattern,
        caseSensitive: _matchCase,
        multiLine: true,
      );
      for (Match match in regExp.allMatches(text)) {
        positions.add(match.start + 1);
      }
    }
    return positions;
  }

  bool _matchesGlobPattern(String fileName, String pattern) {
    final regexPattern = pattern.replaceAll('.', '\\.').replaceAll('*', '.*');
    return RegExp('^$regexPattern\$', caseSensitive: false).hasMatch(fileName);
  }

  void _performSearch() async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      await for (final file
          in Directory(widget.rootDirectory).list(recursive: true)) {
        if (file is File && _shouldSearchFile(file)) {
          final matches = await _searchFile(file, searchTerm);
          if (matches.isNotEmpty) {
            setState(() {
              _searchResults.addAll(matches);
            });
          }
        }
      }
    } catch (e) {
      print('Error searching files: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _replaceAll() {
    // TODO
  }

  Future<List<FileSearchResult>> _searchFile(
      File file, String searchTerm) async {
    final List<FileSearchResult> results = [];
    try {
      final lines = await file.readAsLines();
      for (int i = 0; i < lines.length; i++) {
        final matches = _findMatches(lines[i], searchTerm);
        for (final match in matches) {
          results.add(FileSearchResult(
            fileName: path.basename(file.path),
            filePath: file.path,
            matchingLine: lines[i],
            lineNumber: i + 1,
            columnNumber: match,
          ));
        }
      }
    } catch (e) {
      print('Error reading file ${file.path}: $e');
    }
    return results;
  }

  bool _shouldSearchFile(File file) {
    final fileName = path.basename(file.path);
    final includePatterns = _includeController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    final excludePatterns = _excludeController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);

    if (includePatterns.isNotEmpty &&
        !includePatterns
            .any((pattern) => _matchesGlobPattern(fileName, pattern))) {
      return false;
    }

    if (excludePatterns.isNotEmpty &&
        excludePatterns
            .any((pattern) => _matchesGlobPattern(fileName, pattern))) {
      return false;
    }

    return true;
  }

  void _toggleMatchCase() {
    setState(() {
      _matchCase = !_matchCase;
      _performSearch();
    });
  }

  void _toggleMatchWholeWord() {
    setState(() {
      _matchWholeWord = !_matchWholeWord;
      _performSearch();
    });
  }

  void _toggleUseRegex() {
    setState(() {
      _useRegex = !_useRegex;
      _performSearch();
    });
  }

  void _updateReplaceTerm(String term) {
    // TODO
  }

  void _updateSearchTerm(String term) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }
}
