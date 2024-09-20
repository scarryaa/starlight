import 'dart:io';
// ignore: no_leading_underscores_for_library_prefixes
import 'package:path/path.dart' as _path;
import 'package:flutter/material.dart';

class FileTreeItem {
  final FileSystemEntity entity;
  final int level;
  bool isExpanded;
  List<FileTreeItem> children;
  RenderBox? renderBox;
  final FileTreeItem? parent;

  FileTreeItem(this.entity, this.level, this.isExpanded, this.parent)
      : children = [];

  bool get isDirectory => entity is Directory;
  String get name => _path.basename(path);
  String get path => entity.path;

  void setRenderBox(RenderBox box) {
    renderBox = box;
  }

  void addChild(FileTreeItem child) {
    children.add(child);
  }

  List<FileTreeItem> getParentPath() {
    List<FileTreeItem> parentPath = [];
    FileTreeItem? currentParent = parent;
    while (currentParent != null) {
      parentPath.insert(0, currentParent);
      currentParent = currentParent.parent;
    }
    return parentPath;
  }

  FileTreeItem getRootItem() {
    FileTreeItem current = this;
    while (current.parent != null) {
      current = current.parent!;
    }
    return current;
  }

  String getFullPath() {
    return path;
  }

  bool isDescendantOf(FileTreeItem potentialAncestor) {
    FileTreeItem? current = parent;
    while (current != null) {
      if (current == potentialAncestor) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}
