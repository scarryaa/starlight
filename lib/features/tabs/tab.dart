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
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE0E0E0),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        margin: const EdgeInsets.only(left: 4, top: 4, right: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F5F5) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFFE0E0E0) : Colors.transparent,
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
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.black87 : Colors.black54,
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
                    color: isSelected ? Colors.black54 : Colors.black38,
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
