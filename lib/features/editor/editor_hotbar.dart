import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/services/search_service.dart';
import 'package:starlight/widgets/tab/tab.dart' as CustomTab;

class EditorHotbar extends StatefulWidget {
  final CustomTab.Tab? currentTab;
  final SearchService searchService;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onReplaceChanged;
  final VoidCallback onNextMatch;
  final VoidCallback onPreviousMatch;
  final VoidCallback onReplace;
  final VoidCallback onReplaceAll;
  final VoidCallback onSelectAllMatches;
  final int currentMatch;
  final int totalMatches;
  final bool showReplace;
  final VoidCallback onToggleReplace;
  final bool matchCase;
  final bool matchWholeWord;
  final bool useRegex;
  final ValueChanged<bool> onMatchCaseChanged;
  final ValueChanged<bool> onMatchWholeWordChanged;
  final ValueChanged<bool> onUseRegexChanged;
  final bool isSearchVisible;

  const EditorHotbar({
    super.key,
    required this.currentTab,
    required this.searchService,
    required this.onSearchChanged,
    required this.onReplaceChanged,
    required this.onNextMatch,
    required this.onPreviousMatch,
    required this.onReplace,
    required this.onReplaceAll,
    required this.onSelectAllMatches,
    required this.currentMatch,
    required this.totalMatches,
    required this.showReplace,
    required this.onToggleReplace,
    required this.matchCase,
    required this.matchWholeWord,
    required this.useRegex,
    required this.onMatchCaseChanged,
    required this.onMatchWholeWordChanged,
    required this.onUseRegexChanged,
    required this.isSearchVisible,
  });

  @override
  EditorHotbarState createState() => EditorHotbarState();
}

class EditorHotbarState extends State<EditorHotbar> {
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _replaceFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.searchService.isSearchVisibleNotifier
        .addListener(_handleSearchVisibilityChange);
    widget.searchService.isReplaceVisibleNotifier
        .addListener(_handleReplaceVisibilityChange);
  }

  void _handleSearchVisibilityChange() {
    if (widget.searchService.isSearchVisibleNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  void _handleReplaceVisibilityChange() {
    if (widget.searchService.isReplaceVisibleNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _replaceFocusNode.requestFocus();
      });
    }
  }

  void refocusSearch() {
    _searchFocusNode.requestFocus();
  }

  void refocusReplace() {
    if (!widget.searchService.isReplaceVisibleNotifier.value) {
      widget.searchService.toggleReplace();
    }
    _replaceFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: _handleKeyPress,
      child: Column(
        children: [
          _buildHotbarHeader(),
          if (widget.isSearchVisible) _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildHotbarHeader() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.lightBlue[200]!),
          bottom: BorderSide(
            color: widget.isSearchVisible
                ? Colors.transparent
                : Colors.lightBlue[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.currentTab?.path ?? '',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 18),
            onPressed: widget.searchService.toggleSearch,
            tooltip: 'Search',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.lightBlue[200]!),
        ),
      ),
      child: Column(
        children: [
          _buildSearchInput(),
          if (widget.showReplace) _buildReplaceInput(),
          _buildSearchOptions(),
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    return Row(
      children: [
        Expanded(
          child: RawKeyboardListener(
            focusNode: FocusNode(),
            onKey: _handleSearchKeyPress,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                hintText: 'Search',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: widget.onSearchChanged,
            ),
          ),
        ),
        Text(
          widget.totalMatches > 0
              ? '${widget.currentMatch}/${widget.totalMatches}'
              : '0/0',
          style: const TextStyle(fontSize: 10),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up, size: 16),
          onPressed: widget.totalMatches > 0 ? widget.onPreviousMatch : null,
          tooltip: 'Previous match',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 20, height: 20),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          onPressed: widget.totalMatches > 0 ? widget.onNextMatch : null,
          tooltip: 'Next match',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 20, height: 20),
        ),
        _buildReplaceToggle(),
        IconButton(
          icon: const Icon(Icons.close, size: 16),
          onPressed: widget.searchService.closeSearch,
          tooltip: 'Close search',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 20, height: 20),
        ),
      ],
    );
  }

  Widget _buildReplaceInput() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: _handleReplaceKeyPress,
              child: TextField(
                controller: _replaceController,
                focusNode: _replaceFocusNode,
                decoration: const InputDecoration(
                  hintText: 'Replace',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
                onChanged: widget.onReplaceChanged,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.onReplace,
            child: const Text('Replace', style: TextStyle(fontSize: 10)),
          ),
          TextButton(
            onPressed: widget.onReplaceAll,
            child: const Text('Replace All', style: TextStyle(fontSize: 10)),
          ),
          TextButton(
            onPressed: widget.onSelectAllMatches,
            child: const Text('Select All', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  void _handleSearchKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final bool isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
      final bool isMetaOrControl =
          isMacOS ? event.isMetaPressed : event.isControlPressed;

      if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.searchService.closeSearch();
      } else if (event.logicalKey == LogicalKeyboardKey.keyF &&
          isMetaOrControl) {
        widget.searchService.closeSearch();
      } else if (event.logicalKey == LogicalKeyboardKey.keyH &&
          event.isShiftPressed &&
          isMetaOrControl) {
        _toggleReplace();
      }
    }
  }

  void _handleReplaceKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final bool isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
      final bool isMetaOrControl =
          isMacOS ? event.isMetaPressed : event.isControlPressed;

      if (event.logicalKey == LogicalKeyboardKey.keyF && isMetaOrControl) {
        // Ctrl+F or Cmd+F: Hide search
        widget.searchService.closeSearch();
      } else if (event.logicalKey == LogicalKeyboardKey.keyH &&
          event.isShiftPressed &&
          isMetaOrControl) {
        // Ctrl+Shift+H or Cmd+Shift+H: Toggle replace
        _toggleReplace();
      }
    }
  }

  void _toggleReplace() {
    widget.onToggleReplace();
    if (widget.showReplace) {
      // If replace is being shown, focus the replace input
      _replaceFocusNode.requestFocus();
    } else {
      // If replace is being hidden, focus the search input
      _searchFocusNode.requestFocus();
    }
  }

  void _handleKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.searchService.closeSearch();
      }
    }
  }

  Widget _buildSearchOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildToggleButton(
          label: 'Aa',
          isSelected: widget.matchCase,
          onChanged: widget.onMatchCaseChanged,
        ),
        _buildToggleButton(
          label: '\\b',
          isSelected: widget.matchWholeWord,
          onChanged: widget.onMatchWholeWordChanged,
        ),
        _buildToggleButton(
          label: '.*',
          isSelected: widget.useRegex,
          onChanged: widget.onUseRegexChanged,
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => onChanged(!isSelected),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.blue : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplaceToggle() {
    return InkWell(
      onTap: widget.onToggleReplace,
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        child: Text(
          'R',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: widget.showReplace ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.searchService.isSearchVisibleNotifier
        .removeListener(_handleSearchVisibilityChange);
    widget.searchService.isReplaceVisibleNotifier
        .removeListener(_handleReplaceVisibilityChange);
    _searchFocusNode.dispose();
    _replaceFocusNode.dispose();
    _searchController.dispose();
    _replaceController.dispose();
    super.dispose();
  }
}

class SearchSubbar extends StatefulWidget {
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onReplaceChanged;
  final VoidCallback onNextMatch;
  final VoidCallback onPreviousMatch;
  final VoidCallback onReplace;
  final VoidCallback onReplaceAll;
  final VoidCallback onSelectAllMatches;
  final int currentMatch;
  final int totalMatches;
  final bool showReplace;
  final VoidCallback onToggleReplace;
  final bool matchCase;
  final bool matchWholeWord;
  final bool useRegex;
  final ValueChanged<bool> onMatchCaseChanged;
  final ValueChanged<bool> onMatchWholeWordChanged;
  final ValueChanged<bool> onUseRegexChanged;
  final bool isVisible;

  const SearchSubbar({
    super.key,
    required this.onCloseSearch,
    required this.onSearchChanged,
    required this.onReplaceChanged,
    required this.onNextMatch,
    required this.onPreviousMatch,
    required this.onReplace,
    required this.onReplaceAll,
    required this.onSelectAllMatches,
    required this.currentMatch,
    required this.totalMatches,
    required this.showReplace,
    required this.onToggleReplace,
    required this.matchCase,
    required this.matchWholeWord,
    required this.useRegex,
    required this.onMatchCaseChanged,
    required this.onMatchWholeWordChanged,
    required this.onUseRegexChanged,
    required this.isVisible,
  });

  @override
  _SearchSubbarState createState() => _SearchSubbarState();
}

class _SearchSubbarState extends State<SearchSubbar> {
  final FocusNode _searchFocusNode = FocusNode();
  bool _hasFocused = false;

  @override
  void initState() {
    super.initState();
    _updateFocus();
  }

  @override
  void didUpdateWidget(SearchSubbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _hasFocused = false;
    }
    _updateFocus();
  }

  void _updateFocus() {
    if (widget.isVisible && !_hasFocused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
          _hasFocused = true;
        }
      });
    }
  }

  void refocusSearch() {
    _searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.lightBlue[200]!),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 12),
                        onChanged: widget.onSearchChanged,
                      ),
                    ),
                    _buildToggleButton(
                      label: 'Aa',
                      isSelected: widget.matchCase,
                      onChanged: widget.onMatchCaseChanged,
                    ),
                    _buildToggleButton(
                      label: '\\b',
                      isSelected: widget.matchWholeWord,
                      onChanged: widget.onMatchWholeWordChanged,
                    ),
                    _buildToggleButton(
                      label: '.*',
                      isSelected: widget.useRegex,
                      onChanged: widget.onUseRegexChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.currentMatch}/${widget.totalMatches}',
                style: const TextStyle(fontSize: 10),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 16),
                onPressed: widget.onPreviousMatch,
                tooltip: 'Previous match',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 20, height: 20),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                onPressed: widget.onNextMatch,
                tooltip: 'Next match',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 20, height: 20),
              ),
              _buildReplaceToggle(),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: widget.onCloseSearch,
                tooltip: 'Close search',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 20, height: 20),
              ),
            ],
          ),
          if (widget.showReplace)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Replace',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: widget.onReplaceChanged,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onReplace,
                    child:
                        const Text('Replace', style: TextStyle(fontSize: 10)),
                  ),
                  TextButton(
                    onPressed: widget.onReplaceAll,
                    child: const Text('Replace All',
                        style: TextStyle(fontSize: 10)),
                  ),
                  TextButton(
                    onPressed: widget.onSelectAllMatches,
                    child: const Text('Select All',
                        style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => onChanged(!isSelected),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.blue : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplaceToggle() {
    return InkWell(
      onTap: widget.onToggleReplace,
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        child: Text(
          'R',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: widget.showReplace ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }
}
