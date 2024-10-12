import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

class CommandPalette extends StatefulWidget {
  final Function(String) onCommandSelected;
  final VoidCallback onClose;
  final List<CommandItem> commands;

  const CommandPalette({
    super.key,
    required this.onCommandSelected,
    required this.onClose,
    required this.commands,
  });

  @override
  _CommandPaletteState createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardListenerFocusNode = FocusNode();
  List<CommandItem> _filteredCommands = [];
  int _selectedIndex = 0;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _filteredCommands = widget.commands;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchFocusNode.dispose();
    _keyboardListenerFocusNode.dispose();
    super.dispose();
  }

  void _filterCommands(String query) {
    setState(() {
      _filteredCommands = widget.commands
          .where((command) =>
              command.label.toLowerCase().contains(query.toLowerCase()) ||
              command.category.toLowerCase().contains(query.toLowerCase()))
          .toList();
      _selectedIndex = 0;
      _scrollOffset = 0.0;
    });
  }

  void _handleSpecialKeys(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      setState(() {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _selectedIndex = (_selectedIndex + 1) % _filteredCommands.length;
          _ensureItemVisible();
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _selectedIndex = (_selectedIndex - 1 + _filteredCommands.length) %
              _filteredCommands.length;
          _ensureItemVisible();
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose();
        }
      });
    }
  }

  void _ensureItemVisible() {
    const itemHeight = 56.0; // Approximate height of a ListTile
    const viewportHeight = 400.0 - 72.0; // Total height minus TextField height
    final itemOffset = _selectedIndex * itemHeight;

    if (itemOffset < _scrollOffset) {
      setState(() {
        _scrollOffset = itemOffset;
      });
    } else if (itemOffset + itemHeight > _scrollOffset + viewportHeight) {
      setState(() {
        _scrollOffset = itemOffset + itemHeight - viewportHeight;
      });
    }
  }

  void _handleScroll(double delta) {
    setState(() {
      _scrollOffset += delta;
      _scrollOffset =
          _scrollOffset.clamp(0.0, (_filteredCommands.length * 56.0) - 328.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 600,
          height: 450,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: RawKeyboardListener(
                  focusNode: _keyboardListenerFocusNode,
                  onKey: (RawKeyEvent event) {
                    if (event is RawKeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        setState(() {
                          _selectedIndex =
                              (_selectedIndex + 1) % _filteredCommands.length;
                          _ensureItemVisible();
                        });
                      } else if (event.logicalKey ==
                          LogicalKeyboardKey.arrowUp) {
                        setState(() {
                          _selectedIndex =
                              (_selectedIndex - 1 + _filteredCommands.length) %
                                  _filteredCommands.length;
                          _ensureItemVisible();
                        });
                      } else if (event.logicalKey ==
                          LogicalKeyboardKey.escape) {
                        widget.onClose();
                      }
                    }
                  },
                  child: TextField(
                    autofocus: true,
                    focusNode: _searchFocusNode,
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a command...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surface
                          .withOpacity(0.8),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: _filterCommands,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface),
                    onSubmitted: (value) {
                      if (_filteredCommands.isNotEmpty) {
                        widget.onCommandSelected(
                            _filteredCommands[_selectedIndex].label);
                      }
                    },
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(8)),
                  child: Listener(
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        _handleScroll(pointerSignal.scrollDelta.dy);
                      }
                    },
                    child: CustomScrollView(
                      scrollOffset: _scrollOffset,
                      itemCount: _filteredCommands.length,
                      itemBuilder: (context, index) {
                        final command = _filteredCommands[index];
                        final isSelected = index == _selectedIndex;
                        return Container(
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 4,
                              ),
                            ),
                          ),
                          child: InkWell(
                            onTap: () =>
                                widget.onCommandSelected(command.label),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    command.icon,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          command.label,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        Text(
                                          command.category,
                                          style: TextStyle(
                                            color: (isSelected
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface)
                                                .withOpacity(0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommandItem {
  final IconData icon;
  final String label;
  final String category;

  CommandItem({
    required this.icon,
    required this.label,
    required this.category,
  });
}

class CustomScrollView extends StatelessWidget {
  final double scrollOffset;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const CustomScrollView({
    super.key,
    required this.scrollOffset,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const itemHeight = 56.0;
        final viewportHeight = constraints.maxHeight;
        final contentHeight = itemCount * itemHeight;
        final maxScrollOffset = contentHeight > viewportHeight
            ? contentHeight - viewportHeight
            : 0.0;
        final effectiveScrollOffset = scrollOffset.clamp(0.0, maxScrollOffset);

        return Stack(
          children: List.generate(
            itemCount,
            (index) {
              return Positioned(
                top: index * itemHeight - effectiveScrollOffset,
                left: 0,
                right: 0,
                height: itemHeight,
                child: HoverableCommandItem(
                  child: itemBuilder(context, index),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class HoverableCommandItem extends StatefulWidget {
  final Widget child;

  const HoverableCommandItem({super.key, required this.child});

  @override
  _HoverableCommandItemState createState() => _HoverableCommandItemState();
}

class _HoverableCommandItemState extends State<HoverableCommandItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: _isHovered
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
