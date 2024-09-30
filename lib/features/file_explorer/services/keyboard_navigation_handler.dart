import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';

class KeyboardNavigationHandler {
  final Function(ScrollDirection) scrollToSelectedItem;
  final Function(FileTreeItem) onFileSelected;
  final Function() toggleSearchBar;

  KeyboardNavigationHandler({
    required this.scrollToSelectedItem,
    required this.onFileSelected,
    required this.toggleSearchBar,
  });

  KeyEventResult handleKeyPress(
      RawKeyEvent event, FileExplorerController controller) {
    if (event is RawKeyDownEvent) {
      final bool isShiftPressed = event.isShiftPressed;
      final bool isCtrlPressed = event.isControlPressed || event.isMetaPressed;

      if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
        _selectAll(controller);
        return KeyEventResult.handled;
      }

      if (isShiftPressed &&
          (event.logicalKey == LogicalKeyboardKey.arrowUp ||
              event.logicalKey == LogicalKeyboardKey.arrowDown)) {
        _handleShiftArrowSelection(
            controller, event.logicalKey == LogicalKeyboardKey.arrowUp);
        return KeyEventResult.handled;
      }

      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          _navigateUp(controller);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowDown:
          _navigateDown(controller);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowLeft:
          _navigateLeft(controller);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
          _navigateRight(controller);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.enter:
          _handleEnter(controller);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.space:
          _handleSpace(controller);
          return KeyEventResult.handled;
      }

      // Handle typing to trigger search
      if (!_isModifierKey(event.logicalKey) &&
          !_isSpecialKey(event.logicalKey) &&
          event.character != null &&
          event.character!.isNotEmpty &&
          !isCtrlPressed) {
        toggleSearchBar();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _selectAll(FileExplorerController controller) {
    controller.enterMultiSelectMode();
    final allItems = _flattenItems(controller.rootItems);
    for (var item in allItems) {
      controller.selectItem(item);
    }
  }

  void _handleShiftArrowSelection(
      FileExplorerController controller, bool isUpArrow) {
    if (!controller.isMultiSelectMode) {
      controller.enterMultiSelectMode();
    }

    final allItems = _flattenItems(controller.rootItems);
    final currentIndex = controller.selectedItem != null
        ? allItems.indexOf(controller.selectedItem!)
        : -1;

    if (currentIndex != -1) {
      int newIndex = isUpArrow ? currentIndex - 1 : currentIndex + 1;
      if (newIndex >= 0 && newIndex < allItems.length) {
        final itemsToSelect = isUpArrow
            ? allItems.sublist(newIndex, currentIndex + 1).reversed
            : allItems.sublist(currentIndex, newIndex + 1);

        for (var item in itemsToSelect) {
          controller.selectItem(item);
        }

        controller.setSelectedItem(allItems[newIndex]);
        scrollToSelectedItem(
            isUpArrow ? ScrollDirection.reverse : ScrollDirection.forward);
      }
    }
  }

  void _navigateUp(FileExplorerController controller) {
    final allItems = _flattenItems(controller.rootItems);
    final currentIndex = controller.selectedItem != null
        ? allItems.indexOf(controller.selectedItem!)
        : -1;
    if (currentIndex > 0) {
      controller.clearSelectedItems();
      controller.setSelectedItem(allItems[currentIndex - 1]);
      scrollToSelectedItem(ScrollDirection.reverse);
    } else if (currentIndex == -1) {
      controller.clearSelectedItems();
      controller.setSelectedItem(allItems.last);
      scrollToSelectedItem(ScrollDirection.reverse);
    }
  }

  void _navigateDown(FileExplorerController controller) {
    final allItems = _flattenItems(controller.rootItems);
    final currentIndex = controller.selectedItem != null
        ? allItems.indexOf(controller.selectedItem!)
        : -1;
    if (currentIndex < allItems.length - 1) {
      controller.clearSelectedItems();
      controller.setSelectedItem(allItems[currentIndex + 1]);
      scrollToSelectedItem(ScrollDirection.forward);
    } else if (currentIndex == -1) {
      controller.clearSelectedItems();
      controller.setSelectedItem(allItems.first);
      scrollToSelectedItem(ScrollDirection.forward);
    }
  }

  void _navigateLeft(FileExplorerController controller) {
    if (controller.selectedItem?.isDirectory == true &&
        controller.selectedItem!.isExpanded) {
      controller.toggleDirectoryExpansion(controller.selectedItem!);
    } else if (controller.selectedItem?.parent != null) {
      controller.clearSelectedItems();
      controller.setSelectedItem(controller.selectedItem!.parent!);
      scrollToSelectedItem(ScrollDirection.reverse);
    }
  }

  void _navigateRight(FileExplorerController controller) {
    if (controller.selectedItem?.isDirectory == true) {
      if (!controller.selectedItem!.isExpanded) {
        controller.toggleDirectoryExpansion(controller.selectedItem!);
      } else if (controller.selectedItem!.children.isNotEmpty) {
        controller.clearSelectedItems();
        controller.setSelectedItem(controller.selectedItem!.children.first);
        scrollToSelectedItem(ScrollDirection.forward);
      }
    }
  }

  void _handleEnter(FileExplorerController controller) {
    if (controller.selectedItem != null) {
      if (controller.selectedItem!.isDirectory) {
        controller.toggleDirectoryExpansion(controller.selectedItem!);
      } else {
        onFileSelected(controller.selectedItem!);
      }
    }
  }

  void _handleSpace(FileExplorerController controller) {
    if (controller.selectedItem != null) {
      controller.toggleItemSelection(controller.selectedItem!);
    }
  }

  List<FileTreeItem> _flattenItems(List<FileTreeItem> items) {
    return items.expand((item) {
      final flattened = [item];
      if (item.isDirectory && item.isExpanded) {
        flattened.addAll(_flattenItems(item.children));
      }
      return flattened;
    }).toList();
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  bool _isSpecialKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown;
  }
}
