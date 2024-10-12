import 'package:flutter/material.dart';
import 'package:starlight/widgets/tab/tab.dart' as CustomTab;

class EditorHotbar extends StatelessWidget {
  final CustomTab.Tab? currentTab;
  final VoidCallback onSearch;
  final bool isSearchVisible;
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

  const EditorHotbar({
    super.key,
    required this.currentTab,
    required this.onSearch,
    required this.isSearchVisible,
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Colors.lightBlue[200]!),
              bottom: BorderSide(
                color: isSearchVisible
                    ? Colors.transparent
                    : Colors.lightBlue[200]!,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  currentTab?.path ?? '',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search, size: 18),
                onPressed: onSearch,
                tooltip: 'Search',
              ),
            ],
          ),
        ),
        if (isSearchVisible)
          SearchSubbar(
            onCloseSearch: onCloseSearch,
            onSearchChanged: onSearchChanged,
            onReplaceChanged: onReplaceChanged,
            onNextMatch: onNextMatch,
            onPreviousMatch: onPreviousMatch,
            onReplace: onReplace,
            onReplaceAll: onReplaceAll,
            onSelectAllMatches: onSelectAllMatches,
            currentMatch: currentMatch,
            totalMatches: totalMatches,
            showReplace: showReplace,
            onToggleReplace: onToggleReplace,
            matchCase: matchCase,
            matchWholeWord: matchWholeWord,
            useRegex: useRegex,
            onMatchCaseChanged: onMatchCaseChanged,
            onMatchWholeWordChanged: onMatchWholeWordChanged,
            onUseRegexChanged: onUseRegexChanged,
          ),
      ],
    );
  }
}

class SearchSubbar extends StatelessWidget {
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
  });

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
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 12),
                        onChanged: onSearchChanged,
                      ),
                    ),
                    _buildToggleButton(
                      label: 'Aa',
                      isSelected: matchCase,
                      onChanged: onMatchCaseChanged,
                    ),
                    _buildToggleButton(
                      label: '\\b',
                      isSelected: matchWholeWord,
                      onChanged: onMatchWholeWordChanged,
                    ),
                    _buildToggleButton(
                      label: '.*',
                      isSelected: useRegex,
                      onChanged: onUseRegexChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$currentMatch/$totalMatches',
                style: const TextStyle(fontSize: 10),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 16),
                onPressed: onPreviousMatch,
                tooltip: 'Previous match',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 20, height: 20),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                onPressed: onNextMatch,
                tooltip: 'Next match',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 20, height: 20),
              ),
              _buildReplaceToggle(),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onCloseSearch,
                tooltip: 'Close search',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 20, height: 20),
              ),
            ],
          ),
          if (showReplace)
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
                      onChanged: onReplaceChanged,
                    ),
                  ),
                  TextButton(
                    onPressed: onReplace,
                    child:
                        const Text('Replace', style: TextStyle(fontSize: 10)),
                  ),
                  TextButton(
                    onPressed: onReplaceAll,
                    child: const Text('Replace All',
                        style: TextStyle(fontSize: 10)),
                  ),
                  TextButton(
                    onPressed: onSelectAllMatches,
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
      onTap: onToggleReplace,
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        child: Text(
          'R',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: showReplace ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }
}
