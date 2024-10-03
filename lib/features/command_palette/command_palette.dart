import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Command {
  final String name;
  final IconData icon;
  final VoidCallback action;

  Command({
    required this.name,
    required this.icon,
    required this.action,
  });
}

class CommandPalette extends StatefulWidget {
  final List<Command> commands;
  final Function(Command) onCommandSelected;
  final VoidCallback onClose;

  const CommandPalette({
    super.key,
    required this.commands,
    required this.onCommandSelected,
    required this.onClose,
  });

  @override
  _CommandPaletteState createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  List<Command> _filteredCommands = [];
  int _selectedIndex = 0;
  FocusNode? _previousFocus;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final screenWidth = constraints.maxWidth;
        final maxHeight = screenHeight * 0.7;
        final width = min(500.0, screenWidth * 0.95);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                behavior: HitTestBehavior.opaque,
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.15,
              left: 0,
              right: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxHeight,
                    maxWidth: width,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSearchBar(),
                          Flexible(
                            child: _buildCommandList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.unfocus();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _restorePreviousFocus();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _filteredCommands = widget.commands;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previousFocus = FocusManager.instance.primaryFocus;
      _searchFocusNode.requestFocus();
    });
  }

  Widget _buildCommandList() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shrinkWrap: true,
        itemCount: _filteredCommands.length,
        itemBuilder: (context, index) {
          final command = _filteredCommands[index];
          final isSelected = _selectedIndex == index;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.2)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Icon(
                command.icon,
                size: 28,
                color:
                    isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(
                command.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
              onTap: () => widget.onCommandSelected(command),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: _handleKeyEvent,
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search commands...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
            prefixIcon: const Icon(Icons.search),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          onChanged: _filterCommands,
        ),
      ),
    );
  }

  void _filterCommands(String query) {
    setState(() {
      _filteredCommands = widget.commands
          .where((command) =>
              command.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      _selectedIndex = 0;
      _scrollToSelected();
    });
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _filteredCommands.length;
          _scrollToSelected();
        });
        _preventDefaultKeyEvent(event);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1 + _filteredCommands.length) %
              _filteredCommands.length;
          _scrollToSelected();
        });
        _preventDefaultKeyEvent(event);
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_filteredCommands.isNotEmpty) {
          widget.onCommandSelected(_filteredCommands[_selectedIndex]);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _restorePreviousFocus();
        widget.onClose();
      }
    }
  }

  void _restorePreviousFocus() {
    if (_previousFocus != null && _previousFocus!.canRequestFocus) {
      _previousFocus!.requestFocus();
    }
  }

  void _preventDefaultKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown) {
        _searchFocusNode.unfocus();
        _searchFocusNode.requestFocus();
      }
    }
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        const itemHeight = 76.0;
        final offset = _selectedIndex * itemHeight;
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 20),
          curve: Curves.easeInOut,
        );
      }
    });
  }
}
