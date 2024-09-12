import 'package:flutter/material.dart';
import 'dart:io';

class FileTab {
  final String filePath;
  String content;
  bool isModified;

  FileTab({
    required this.filePath,
    required this.content,
    this.isModified = false,
  });

  String get fileName => filePath.split(Platform.pathSeparator).last;

  void updateContent(String newContent) {
    if (content != newContent) {
      content = newContent;
      isModified = true;
    }
  }
}

class TabBar extends StatelessWidget {
  final List<FileTab> tabs;
  final int selectedIndex;
  final Function(int) onTabSelected;
  final Function(int) onTabClosed;

  const TabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onTabClosed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          return Tab(
            text: tabs[index].fileName,
            isSelected: selectedIndex == index,
            isModified: tabs[index].isModified,
            onTap: () => onTabSelected(index),
            onClose: () => onTabClosed(index),
          );
        },
      ),
    );
  }
}

class Tab extends StatelessWidget {
  final String text;
  final bool isSelected;
  final bool isModified;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const Tab({
    super.key,
    required this.text,
    required this.isSelected,
    required this.isModified,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        margin: const EdgeInsets.only(left: 4, top: 4, right: 4),
        decoration: BoxDecoration(
          color: isSelected ? theme.hoverColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? theme.dividerColor : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (isModified)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? theme.textTheme.bodyLarge?.color
                    : theme.textTheme.bodyMedium?.color,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: isSelected
                        ? theme.iconTheme.color
                        : theme.iconTheme.color?.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
