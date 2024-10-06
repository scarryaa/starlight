import 'dart:io';
import 'package:flutter/material.dart';

class FileSystemNode {
  final FileSystemEntity entity;
  bool isExpanded;
  List<FileSystemNode> children;

  FileSystemNode(this.entity,
      {this.isExpanded = false, this.children = const []});
}

class FileExplorer extends StatefulWidget {
  final String initialDirectory;

  const FileExplorer({super.key, required this.initialDirectory});

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<FileExplorer> {
  final double fileHeight = 25.0;
  late List<FileSystemNode> rootNodes;

  @override
  void initState() {
    super.initState();
    _initializeRootNodes();
  }

  void _initializeRootNodes() {
    final directory = Directory(widget.initialDirectory);
    rootNodes =
        directory.listSync().map((entity) => FileSystemNode(entity)).toList();
  }

  void _toggleDirectory(FileSystemNode node) {
    setState(() {
      if (node.isExpanded) {
        node.isExpanded = false;
        node.children.clear();
      } else {
        try {
          node.isExpanded = true;
          final directory = Directory(node.entity.path);
          node.children = directory
              .listSync()
              .map((entity) => FileSystemNode(entity))
              .toList();
        } catch (e) {
          print(e);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(width: 1, color: Colors.black)),
      ),
      width: 250,
      child: ListView(
        children: rootNodes.map((node) => _buildFileItem(node, 0)).toList(),
      ),
    );
  }

  Widget _buildFileItem(FileSystemNode node, int depth) {
    final isDirectory = node.entity is Directory;
    final fileName = node.entity.path.split("/").last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: isDirectory ? () => _toggleDirectory(node) : () {},
          splashFactory: NoSplash.splashFactory,
          child: Container(
            height: fileHeight,
            padding: EdgeInsets.only(left: 15.0 * depth),
            child: Row(
              children: [
                Icon(
                  isDirectory
                      ? (node.isExpanded ? Icons.folder_open : Icons.folder)
                      : Icons.insert_drive_file,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(fileName, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
        if (node.isExpanded)
          ...node.children.map((child) => _buildFileItem(child, depth + 1)),
      ],
    );
  }
}
