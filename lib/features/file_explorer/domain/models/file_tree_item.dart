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
}
