import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/context_menu/context_menu.dart';
import 'package:starlight/services/tab_service.dart';
import 'package:starlight/services/file_service.dart';
import 'package:path/path.dart' as p;

class FileExplorer extends StatefulWidget {
  final String initialDirectory;
  final TabService tabService;
  final FileService fileService;

  const FileExplorer({
    super.key,
    required this.initialDirectory,
    required this.tabService,
    required this.fileService,
  });

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class FileSystemNode {
  final FileSystemEntity entity;
  bool isExpanded;
  List<FileSystemNode> children;
  FileSystemNode(
    this.entity, {
    this.isExpanded = false,
  }) : children = [];
}

class _FileExplorerState extends State<FileExplorer> {
  final double fileHeight = 25.0;
  late List<FileSystemNode> rootNodes;
  final double bottomPadding = 25.0;
  final ScrollController _scrollController = ScrollController();
  Set<String> selectedPaths = {};
  String? lastSelectedPath;

  @override
  void initState() {
    super.initState();
    _initializeRootNodes();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleEmptySpaceClick,
      onSecondaryTapDown: (details) =>
          _showEmptySpaceContextMenu(context, details),
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(width: 1, color: Colors.blue[200]!)),
        ),
        width: 250,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  if (index < rootNodes.length) {
                    return _buildFileItem(rootNodes[index], 0);
                  } else if (index == rootNodes.length) {
                    return SizedBox(height: bottomPadding);
                  }
                  return null;
                },
                childCount: rootNodes.length + 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(FileSystemNode node, int depth) {
    final isDirectory = node.entity is Directory;
    final fileName = p.basename(node.entity.path);
    final isSelected = selectedPaths.contains(node.entity.path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: (details) {
            setState(() {
              if (!isSelected) {
                selectedPaths.clear();
                selectedPaths.add(node.entity.path);
                lastSelectedPath = node.entity.path;
              }
            });
            _showContextMenu(context, [node], details);
          },
          child: InkWell(
            splashFactory: NoSplash.splashFactory,
            onTap: () => _handleTap(node),
            child: Container(
              height: fileHeight,
              padding: EdgeInsets.only(left: 15.0 * depth + 4),
              color: isSelected ? Colors.blue.withOpacity(0.2) : null,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: isDirectory ? () => _toggleDirectory(node) : null,
                    child: Icon(
                      isDirectory
                          ? (node.isExpanded ? Icons.folder_open : Icons.folder)
                          : Icons.insert_drive_file,
                      size: 16,
                      color: isSelected ? Colors.blue : null,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? Colors.blue : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (node.isExpanded)
          ...node.children.map((child) => _buildFileItem(child, depth + 1)),
      ],
    );
  }

  void _handleEmptySpaceClick() {
    setState(() {
      selectedPaths.clear();
      lastSelectedPath = null;
    });
  }

  void _showEmptySpaceContextMenu(
      BuildContext context, TapDownDetails details) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    final List<ContextMenuItem> menuItems = [
      ContextMenuItem(
          label: 'New File',
          onTap: () => _createNew(widget.initialDirectory, isFile: true)),
      ContextMenuItem(
          label: 'New Folder',
          onTap: () => _createNew(widget.initialDirectory, isFile: false)),
      const ContextMenuItem(isDivider: true, label: ''),
      ContextMenuItem(
          label: 'Paste', onTap: () => _pasteFiles(widget.initialDirectory)),
    ];

    showCommonContextMenu(
      context: context,
      position: position,
      items: menuItems,
    );
  }

  void _handleTap(FileSystemNode node) {
    final bool isCommandPressed = RawKeyboard.instance.keysPressed
            .contains(LogicalKeyboardKey.metaLeft) ||
        RawKeyboard.instance.keysPressed
            .contains(LogicalKeyboardKey.metaRight) ||
        RawKeyboard.instance.keysPressed
            .contains(LogicalKeyboardKey.controlLeft) ||
        RawKeyboard.instance.keysPressed
            .contains(LogicalKeyboardKey.controlRight);

    final bool isShiftPressed = RawKeyboard.instance.keysPressed
            .contains(LogicalKeyboardKey.shiftLeft) ||
        RawKeyboard.instance.keysPressed
            .contains(LogicalKeyboardKey.shiftRight);

    setState(() {
      if (isCommandPressed) {
        _toggleSelection(node.entity.path);
      } else if (isShiftPressed && lastSelectedPath != null) {
        _selectRange(lastSelectedPath!, node.entity.path);
      } else {
        _selectSingle(node.entity.path);
      }

      // Only toggle directory if it's not a multi-select operation
      if (node.entity is Directory && !isCommandPressed && !isShiftPressed) {
        _toggleDirectory(node);
      }
    });

    // Open file if it's not a directory and it's a single click without modifiers
    if (node.entity is! Directory && !isCommandPressed && !isShiftPressed) {
      _openFile(node.entity.path);
    }
  }

  void _toggleDirectory(FileSystemNode node) {
    setState(() {
      if (node.isExpanded) {
        node.isExpanded = false;
        node.children.clear();
      } else {
        try {
          node.isExpanded = true;
          node.children = widget.fileService
              .listDirectory(node.entity.path)
              .map((entity) => FileSystemNode(entity))
              .toList();
          _sortNodes(node.children);
        } catch (e) {
          print('Error accessing directory: $e');
          // TODO implement toast
        }
      }
    });
  }

  void _toggleSelection(String path) {
    if (selectedPaths.contains(path)) {
      selectedPaths.remove(path);
    } else {
      selectedPaths.add(path);
    }
    lastSelectedPath = path;
  }

  void _selectSingle(String path) {
    selectedPaths.clear();
    selectedPaths.add(path);
    lastSelectedPath = path;
  }

  void _selectRange(String start, String end) {
    List<String> allPaths = _getAllPaths();
    int startIndex = allPaths.indexOf(start);
    int endIndex = allPaths.indexOf(end);
    if (startIndex == -1 || endIndex == -1) return;

    if (startIndex > endIndex) {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
    }

    selectedPaths.addAll(allPaths.sublist(startIndex, endIndex + 1));
    lastSelectedPath = end;
  }

  List<String> _getAllPaths() {
    List<String> paths = [];
    void traverse(List<FileSystemNode> nodes) {
      for (var node in nodes) {
        paths.add(node.entity.path);
        if (node.isExpanded) {
          traverse(node.children);
        }
      }
    }

    traverse(rootNodes);
    return paths;
  }

  void _showContextMenu(BuildContext context, List<FileSystemNode> nodes,
      TapDownDetails details) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    final List<ContextMenuItem> menuItems = [];

    if (selectedPaths.length == 1) {
      final FileSystemNode node = nodes.first;
      final String path = node.entity.path;
      final bool isDirectory = node.entity is Directory;

      menuItems.addAll([
        ContextMenuItem(
            label: 'New File', onTap: () => _createNew(path, isFile: true)),
        ContextMenuItem(
            label: 'New Folder', onTap: () => _createNew(path, isFile: false)),
        const ContextMenuItem(isDivider: true, label: ''),
        ContextMenuItem(
            label: 'Reveal In Finder', onTap: () => _revealFileInFinder(path)),
        const ContextMenuItem(isDivider: true, label: ''),
        ContextMenuItem(label: 'Copy', onTap: () => _copyFiles([path])),
        ContextMenuItem(label: 'Cut', onTap: () => _cutFiles([path])),
        ContextMenuItem(
            label: 'Paste',
            onTap: () => _pasteFiles(isDirectory ? path : p.dirname(path))),
        const ContextMenuItem(isDivider: true, label: ''),
        ContextMenuItem(label: 'Copy Path', onTap: () => _copyPath(path)),
        ContextMenuItem(
            label: 'Copy Relative Path', onTap: () => _copyRelativePath(path)),
        const ContextMenuItem(isDivider: true, label: ''),
        ContextMenuItem(label: 'Rename', onTap: () => _renameFile(node)),
        ContextMenuItem(label: 'Delete', onTap: () => _deleteFile(path)),
      ]);
    } else if (selectedPaths.isNotEmpty) {
      menuItems.addAll([
        ContextMenuItem(
            label: 'Copy', onTap: () => _copyFiles(selectedPaths.toList())),
        ContextMenuItem(
            label: 'Cut', onTap: () => _cutFiles(selectedPaths.toList())),
        ContextMenuItem(
            label: 'Paste',
            onTap: () {
              final path = nodes.first.entity.path;
              final pasteDir =
                  nodes.first.entity is Directory ? path : p.dirname(path);
              _pasteFiles(pasteDir);
            }),
        const ContextMenuItem(isDivider: true, label: ''),
        ContextMenuItem(
            label: 'Delete Selected',
            onTap: () => _deleteMultipleFiles(selectedPaths.toList())),
      ]);
    }

    showCommonContextMenu(
      context: context,
      position: position,
      items: menuItems,
    );
  }

  void _createNew(String parentPath, {required bool isFile}) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: Text(isFile ? 'New File' : 'New Folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                InputDecoration(hintText: isFile ? 'file.txt' : 'New Folder'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final path = p.join(parentPath, controller.text);
                if (isFile) {
                  widget.fileService.createFile(path);
                } else {
                  widget.fileService.createFolder(path);
                }
                Navigator.of(context).pop();
                _refreshDirectory();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _renameFile(FileSystemNode node) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController controller =
            TextEditingController(text: p.basename(node.entity.path));
        return AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'New name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newPath =
                    p.join(p.dirname(node.entity.path), controller.text);
                widget.fileService.renameFile(node.entity.path, newPath);
                Navigator.of(context).pop();
                _refreshDirectory();
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _deleteFile(String path) {
    final bool isDirectory = FileSystemEntity.isDirectorySync(path);
    final String itemName = p.basename(path);
    final String itemType = isDirectory ? 'folder' : 'file';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content:
            Text('Are you sure you want to delete the $itemType "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.fileService.deleteFile(path);
              Navigator.of(context).pop();
              _refreshDirectory();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteMultipleFiles(List<String> paths) {
    final int itemCount = paths.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Are you sure you want to delete $itemCount items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              for (var path in paths) {
                widget.fileService.deleteFile(path);
              }
              Navigator.of(context).pop();
              _refreshDirectory();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openFile(String path) {
    widget.fileService.openFile(path);
    widget.tabService.addTab(
        p.basename(path), path, widget.fileService.getAbsolutePath(path));
  }

  void _copyFiles(List<String> paths) {
    widget.fileService.copyFiles(paths);
  }

  void _cutFiles(List<String> paths) {
    widget.fileService.cutFiles(paths);
  }

  void _pasteFiles(String destinationPath) {
    widget.fileService.pasteFiles(destinationPath,
        onNameConflict: (String path) {
      String baseName = p.basenameWithoutExtension(path);
      String extension = p.extension(path);
      int copyNumber = 1;
      String newPath = path;
      while (
          FileSystemEntity.typeSync(newPath) != FileSystemEntityType.notFound) {
        newPath =
            p.join(p.dirname(path), '$baseName - Copy $copyNumber$extension');
        copyNumber++;
      }
      return newPath;
    });
    _refreshDirectory();
  }

  void _copyPath(String path) {
    widget.fileService.copyPath(path);
  }

  void _copyRelativePath(String path) {
    widget.fileService.copyRelativePath(path, widget.initialDirectory);
  }

  void _revealFileInFinder(String path) {
    widget.fileService.revealInFinder(path);
  }

  void _initializeRootNodes() {
    rootNodes = widget.fileService
        .listDirectory(widget.initialDirectory)
        .map((entity) => FileSystemNode(entity))
        .toList();
    _sortNodes(rootNodes);
  }

  void _sortNodes(List<FileSystemNode> nodes) {
    nodes.sort((a, b) {
      if (a.entity is Directory && b.entity is! Directory) {
        return -1;
      } else if (a.entity is! Directory && b.entity is Directory) {
        return 1;
      } else {
        return p
            .basename(a.entity.path)
            .toLowerCase()
            .compareTo(p.basename(b.entity.path).toLowerCase());
      }
    });
  }

  void _refreshDirectory() {
    setState(() {
      _initializeRootNodes();
    });
  }
}

