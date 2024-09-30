import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:path/path.dart' as path;

class SearchHandler {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final Function(bool) setSearching;
  final Function(List<FileTreeItem>) setFilteredItems;

  SearchHandler({
    required this.searchController,
    required this.searchFocusNode,
    required this.setSearching,
    required this.setFilteredItems,
  }) {
    searchController.addListener(_onSearchChanged);
    searchFocusNode.addListener(_onSearchFocusChanged);
  }

  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchFocusNode.removeListener(_onSearchFocusChanged);
  }

  void _onSearchFocusChanged() {
    if (!searchFocusNode.hasFocus) {
      if (searchController.text.isEmpty) {
        setSearching(false);
        setFilteredItems([]);
      }
    }
  }

  Future<void> _onSearchChanged() async {
    final controller = searchController.text.toLowerCase();
    final query = controller.toLowerCase();

    if (query.isEmpty) {
      setSearching(false);
      setFilteredItems([]);
    } else {
      setSearching(true);
      final results = await _performSearch(query);
      setFilteredItems(results);
    }
  }

  Future<List<FileTreeItem>> _performSearch(String query) async {
    final fileExplorerController =
        FileExplorerController(); // You might need to inject this
    List<FileTreeItem> results = [];
    for (var rootItem in fileExplorerController.rootItems) {
      results.addAll(await _searchAllItems(rootItem, query));
    }
    return results;
  }

  Future<List<FileTreeItem>> _searchAllItems(
      FileTreeItem item, String query) async {
    List<FileTreeItem> results = [];
    final fileName = path.basename(item.name).toLowerCase();
    if (fileName.contains(query.toLowerCase())) {
      results.add(item);
    }

    if (item.isDirectory) {
      // Load directory contents if not already loaded
      if (item.children.isEmpty) {
        await FileExplorerController().loadDirectoryContents(item);
      }

      for (var child in item.children) {
        results.addAll(await _searchAllItems(child, query));
      }
    }

    return results;
  }

  Widget buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            closeSearch();
          }
        },
        child: TextField(
          controller: searchController,
          focusNode: searchFocusNode,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search files and folders',
            hintStyle: const TextStyle(fontSize: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: closeSearch,
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          ),
          onSubmitted: (_) => closeSearch(),
          onEditingComplete: () {
            _onSearchChanged();
            // You might want to request focus for the file explorer here
          },
        ),
      ),
    );
  }

  void closeSearch() {
    searchController.clear();
    setSearching(false);
    setFilteredItems([]);
    // You might want to request focus for the file explorer here
  }

  void toggleSearchBar() {
    if (searchController.text.isEmpty) {
      closeSearch();
    } else {
      searchFocusNode.requestFocus();
    }
  }
}
