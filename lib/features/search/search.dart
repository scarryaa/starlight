import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:async/async.dart';

class SearchPane extends StatefulWidget {
  final Function(File) onFileSelected;
  final String rootDirectory;

  const SearchPane({
    super.key,
    required this.onFileSelected,
    required this.rootDirectory,
  });

  @override
  _SearchPaneState createState() => _SearchPaneState();
}

class _SearchPaneState extends State<SearchPane> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;
  late String _currentRootDirectory;
  CancelableOperation<List<SearchResult>>? _currentSearch;
  final Map<String, List<String>> _fileIndex = {};
  bool _isIndexing = false;
  Isolate? _indexingIsolate;
  ReceivePort? _receivePort;
  final Set<int> _collapsedItems = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _currentRootDirectory = widget.rootDirectory;
    _startIndexing();
  }

  @override
  void didUpdateWidget(SearchPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rootDirectory != oldWidget.rootDirectory) {
      _cancelIndexing();
      _currentRootDirectory = widget.rootDirectory;
      _startIndexing();
    }
  }

  void _cancelIndexing() {
    _indexingIsolate?.kill(priority: Isolate.immediate);
    _indexingIsolate = null;
    _receivePort?.close();
    _receivePort = null;
    _isIndexing = false;
  }

  void _startIndexing() {
    _isIndexing = true;
    _fileIndex.clear();
    _buildFileIndex();
  }

  Future<void> _buildFileIndex() async {
    _receivePort = ReceivePort();
    _indexingIsolate = await Isolate.spawn(
      _indexFiles,
      [_receivePort!.sendPort, _currentRootDirectory],
    );

    _receivePort!.listen((message) {
      if (message is Map<String, List<String>>) {
        if (mounted) {
          setState(() {
            _fileIndex.addAll(message);
          });
        }
      } else if (message == "done") {
        if (mounted) {
          setState(() {
            _isIndexing = false;
          });
        }
        _receivePort?.close();
      }
    });
  }

  static void _indexFiles(List<dynamic> args) {
    SendPort sendPort = args[0];
    String rootDir = args[1];
    Map<String, List<String>> index = {};

    void indexDirectory(Directory dir) {
      try {
        for (var entity in dir.listSync(recursive: false, followLinks: false)) {
          if (entity is File) {
            String fileName = path.basename(entity.path).toLowerCase();
            index.putIfAbsent(fileName, () => []).add(entity.path);
            if (index.length % 100 == 0) {
              // Send partial results every 100 files
              sendPort.send(Map<String, List<String>>.from(index));
              index.clear();
            }
          } else if (entity is Directory) {
            indexDirectory(entity);
          }
        }
      } catch (e) {
        print("Error indexing directory ${dir.path}: $e");
      }
    }

    indexDirectory(Directory(rootDir));
    if (index.isNotEmpty) {
      sendPort.send(index);
    }
    sendPort.send("done");
  }

  void _onSearchChanged() {
    _cancelCurrentSearch();
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    } else {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _errorMessage = null;
      });
    }
  }

  void _cancelCurrentSearch() {
    _currentSearch?.cancel();
    _currentSearch = null;
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    _currentSearch = CancelableOperation.fromFuture(
      _searchIndexedFiles(query),
      onCancel: () {
        setState(() {
          _isSearching = false;
        });
      },
    );

    try {
      final results = await _currentSearch!.value;
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error during search. Please try again.";
          _isSearching = false;
        });
      }
      print("Error during search: $e");
    }
  }

  Future<List<SearchResult>> _searchIndexedFiles(String query) async {
    List<SearchResult> results = [];
    query = query.toLowerCase();

    // Search in the current index
    for (var entry in _fileIndex.entries) {
      if (entry.key.contains(query)) {
        for (var filePath in entry.value) {
          File file = File(filePath);
          results.add(SearchResult(
            file: file,
            matches: [], // Start with an empty list of matches
          ));
        }
      }
    }

    // If indexing is still in progress, also search the current directory
    if (_isIndexing) {
      results.addAll(await _searchCurrentDirectory(query));
    }

    // Search file contents in parallel
    final contentSearchFutures =
        results.map((result) => _searchFileContents(result.file, query));
    final contentSearchResults = await Future.wait(contentSearchFutures);

    // Filter out results with no content matches
    results = results.asMap().entries.where((entry) {
      return contentSearchResults[entry.key].isNotEmpty;
    }).map((entry) {
      entry.value.matches = contentSearchResults[entry.key];
      return entry.value;
    }).toList();

    return results;
  }

  Future<List<SearchResult>> _searchCurrentDirectory(String query) async {
    List<SearchResult> results = [];
    Directory currentDir = Directory(_currentRootDirectory);

    await for (var entity
        in currentDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        String fileName = path.basename(entity.path).toLowerCase();
        if (fileName.contains(query)) {
          results.add(SearchResult(
            file: entity,
            matches: [MatchResult(line: fileName, lineNumber: -1)],
          ));
        }
      }
    }

    return results;
  }

  Future<List<MatchResult>> _searchFileContents(File file, String query) async {
    List<MatchResult> matches = [];
    int lineNumber = 0;

    try {
      if (!await _isReadableFile(file) || !await _isUtf8File(file)) {
        return matches;
      }

      final lines = await file.readAsLines();
      for (var line in lines) {
        lineNumber++;
        if (line.toLowerCase().contains(query)) {
          matches.add(MatchResult(line: line.trim(), lineNumber: lineNumber));
        }
      }
    } catch (e) {
      print("Error reading file ${file.path}: $e");
    }

    return matches;
  }

  Future<bool> _isReadableFile(File file) async {
    try {
      final stat = await file.stat();
      return stat.type == FileSystemEntityType.file && await file.length() > 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isUtf8File(File file) async {
    try {
      final bytes = await file.openRead(0, 1024).first;
      return utf8.decoder.convert(bytes).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        SearchResult result = _searchResults[index];
        String fileName = path.basename(result.file.path);
        bool isCollapsed = _collapsedItems.contains(index);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HoverableHeader(
              isCollapsed: isCollapsed,
              fileName: fileName,
              onTap: () {
                setState(() {
                  if (isCollapsed) {
                    _collapsedItems.remove(index);
                  } else {
                    _collapsedItems.add(index);
                  }
                });
              },
            ),
            if (!isCollapsed) _buildFileMatches(result, _searchController.text),
          ],
        );
      },
    );
  }

  Widget _buildFileMatches(SearchResult result, String query) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: result.matches.map((match) {
        return _buildMatchTile(result.file, match, query);
      }).toList(),
    );
  }

  Widget _buildMatchTile(File file, MatchResult match, String query) {
    return HoverableMatchTile(
      file: file,
      match: match,
      query: query,
      onTap: _onMatchTap,
    );
  }

  void _onMatchTap(File file, MatchResult match) {
    widget.onFileSelected(file);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            cursorHeight: 12,
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _errorMessage = null;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _buildSearchResults(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _cancelIndexing();
    _cancelCurrentSearch();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}

class HoverableHeader extends StatefulWidget {
  final bool isCollapsed;
  final String fileName;
  final VoidCallback onTap;

  const HoverableHeader({
    super.key,
    required this.isCollapsed,
    required this.fileName,
    required this.onTap,
  });

  @override
  _HoverableHeaderState createState() => _HoverableHeaderState();
}

class _HoverableHeaderState extends State<HoverableHeader> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          decoration: BoxDecoration(
            color:
                _isHovered ? Colors.grey.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                widget.isCollapsed ? Icons.arrow_right : Icons.arrow_drop_down,
                size: 20,
              ),
              Expanded(
                child: Text(
                  widget.fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HoverableMatchTile extends StatefulWidget {
  final File file;
  final MatchResult match;
  final String query;
  final Function(File, MatchResult) onTap;

  const HoverableMatchTile({
    super.key,
    required this.file,
    required this.match,
    required this.query,
    required this.onTap,
  });

  @override
  _HoverableMatchTileState createState() => _HoverableMatchTileState();
}

class _HoverableMatchTileState extends State<HoverableMatchTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onTap(widget.file, widget.match),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
          decoration: BoxDecoration(
            color:
                _isHovered ? Colors.grey.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const SizedBox(width: 22),
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children:
                        _highlightMatches(widget.match.line, widget.query),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<TextSpan> _highlightMatches(String text, String query) {
    List<TextSpan> spans = [];
    int start = 0;
    int indexOfMatch;
    query = query.toLowerCase();
    String lowerText = text.toLowerCase();

    while ((indexOfMatch = lowerText.indexOf(query, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch)));
      }
      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + query.length),
        style: TextStyle(
            backgroundColor: Colors.orange.withOpacity(0.5),
            fontWeight: FontWeight.bold),
      ));
      start = indexOfMatch + query.length;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return spans;
  }
}

class SearchResult {
  final File file;
  List<MatchResult> matches;

  SearchResult({required this.file, required this.matches});
}

class MatchResult {
  final String line;
  final int lineNumber;

  MatchResult({required this.line, required this.lineNumber});
}
