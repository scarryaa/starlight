import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/context_menu/context_menu.dart';
import 'package:starlight/features/file_explorer/quick_access_bar.dart';
import 'package:starlight/services/tab_service.dart';
import 'package:starlight/services/file_service.dart';
import 'package:path/path.dart' as p;

class FileExplorer extends StatefulWidget {
  final String initialDirectory;
  final TabService tabService;
  final FileService fileService;

  const FileExplorer({
    Key? key,
    required this.initialDirectory,
    required this.tabService,
    required this.fileService,
  }) : super(key: key);

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class FileSystemNode {
  final FileSystemEntity entity;
  bool isExpanded;
  List<FileSystemNode> children;
  FileSystemNode(this.entity, {this.isExpanded = false}) : children = [];
}

class _FileExplorerState extends State<FileExplorer> {
  static const double fileHeight = 25.0;
  static const double bottomPadding = 25.0;

  late List<FileSystemNode> rootNodes;
  final ScrollController _scrollController = ScrollController();
  Set<String> selectedPaths = {};
  String? lastSelectedPath;
  Timer? _expandTimer;
  String? _hoveredFolderPath;
  Set<String> expandedDirectories = {};
  String? lastClickedDirectory;
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  List<FileSystemNode> _filteredNodes = [];
  Timer? _debounce;
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _explorerFocusNode = FocusNode();
  final FocusNode _explorerChildFocusNode = FocusNode();
  bool _isShiftPressed = false;

  @override
  void initState() {
    super.initState();
    _initializeRootNodes();
    _filteredNodes = List.from(rootNodes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    _expandTimer?.cancel();
    _explorerFocusNode.dispose();
    _explorerChildFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: _explorerFocusNode,
      autofocus: true,
      actions: {
        DeleteIntent: CallbackAction<DeleteIntent>(
          onInvoke: (_) => _handleDelete(),
        ),
      },
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.delete): DeleteIntent(),
      },
      child: _buildExplorerContent(),
    );
  }

  Widget _buildExplorerContent() {
    return Focus(
      focusNode: _explorerChildFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: _handleEmptySpaceClick,
        onSecondaryTapDown: (details) => _showEmptySpaceContextMenu(context, details),
        child: Container(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(width: 1, color: Colors.blue[200]!)),
          ),
          width: 250,
          child: Column(
            children: [
              QuickAccessBar(
                onNewFile: () => _createNew(lastClickedDirectory ?? widget.initialDirectory, isFile: true),
                onNewFolder: () => _createNew(lastClickedDirectory ?? widget.initialDirectory, isFile: false),
                onRefresh: _refreshDirectory,
                onCollapseAll: _collapseAll,
                onExpandAll: _expandAll,
                onSearch: _toggleSearch,
                isSearchVisible: _isSearchVisible,
              ),
              if (_isSearchVisible) _buildSearchBar(),
              Expanded(child: _buildFileList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search files and folders',
          border: InputBorder.none,
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.lightBlue[200]!),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.lightBlue[400]!),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, size: 16),
            onPressed: _clearSearch,
            splashRadius: 12,
          ),
        ),
        style: const TextStyle(fontSize: 14),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildFileList() {
    return DragTarget<String>(
      onWillAccept: (_) => true,
      onAccept: (data) => _handleFileDrop(data, widget.initialDirectory),
      builder: (context, _, __) {
        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  if (index < _filteredNodes.length) {
                    return _buildFileItem(_filteredNodes[index], 0);
                  } else if (index == _filteredNodes.length) {
                    return SizedBox(height: bottomPadding);
                  }
                  return null;
                },
                childCount: _filteredNodes.length + 1,
              ),
            ),
          ],
        );
      },
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
          onSecondaryTapDown: (details) => _handleSecondaryTap(node, details),
          child: Draggable<String>(
            data: node.entity.path,
            feedback: Material(
              elevation: 4.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                color: Colors.blue.withOpacity(0.8),
                child: Text(fileName, style: const TextStyle(color: Colors.white)),
              ),
            ),
            child: _buildDragTarget(node, isDirectory, fileName, isSelected, depth),
          ),
        ),
        if (node.isExpanded)
          ...node.children.map((child) => _buildFileItem(child, depth + 1)),
      ],
    );
  }

  Widget _buildDragTarget(FileSystemNode node, bool isDirectory, String fileName, bool isSelected, int depth) {
    return DragTarget<String>(
      onWillAccept: (data) {
        if (data != node.entity.path && isDirectory) {
          _startExpandTimer(node);
        }
        return data != node.entity.path;
      },
      onLeave: (_) => _cancelExpandTimer(),
      onAccept: (data) => _handleFileDrop(data, node.entity.path),
      builder: (context, _, __) {
        return InkWell(
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
        );
      },
    );
  }

  void _initializeRootNodes() {
    rootNodes = widget.fileService
        .listDirectory(widget.initialDirectory)
        .map((entity) => FileSystemNode(entity))
        .toList();
    _sortNodes(rootNodes);
    _restoreExpandedState(rootNodes);
  }

  void _refreshDirectory() {
    setState(() {
      _initializeRootNodes();
      _updateFilteredNodes(_searchController.text);
    });
  }

  void _toggleDirectory(FileSystemNode node) {
    setState(() {
      if (node.isExpanded) {
        node.isExpanded = false;
        expandedDirectories.remove(node.entity.path);
        node.children.clear();
      } else {
        try {
          node.isExpanded = true;
          expandedDirectories.add(node.entity.path);
          node.children = widget.fileService
              .listDirectory(node.entity.path)
              .map((entity) => FileSystemNode(entity))
              .toList();
          _sortNodes(node.children);
          _restoreExpandedState(node.children);
        } catch (e) {
          print('Error accessing directory: $e');
          // TODO: implement toast
        }
      }
    });
  }

  void _restoreExpandedState(List<FileSystemNode> nodes) {
    for (var node in nodes) {
      if (node.entity is Directory &&
          expandedDirectories.contains(node.entity.path)) {
        node.isExpanded = true;
        node.children = widget.fileService
            .listDirectory(node.entity.path)
            .map((entity) => FileSystemNode(entity))
            .toList();
        _sortNodes(node.children);
        _restoreExpandedState(node.children);
      }
    }
  }

  void _handleTap(FileSystemNode node) {
    final bool isCommandPressed = RawKeyboard.instance.keysPressed
        .contains(LogicalKeyboardKey.metaLeft) ||
        RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.metaRight) ||
        RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
        RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.controlRight);

    final bool isShiftPressed = RawKeyboard.instance.keysPressed
        .contains(LogicalKeyboardKey.shiftLeft) ||
        RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftRight);

    setState(() {
      if (isCommandPressed) {
        _toggleSelection(node.entity.path);
      } else if (isShiftPressed && lastSelectedPath != null) {
        _selectRange(lastSelectedPath!, node.entity.path);
      } else {
        _selectSingle(node.entity.path);
      }

      if (node.entity is Directory && !isCommandPressed && !isShiftPressed) {
        _toggleDirectory(node);
      }

      lastClickedDirectory = node.entity is Directory
          ? node.entity.path
          : p.dirname(node.entity.path);
    });

    if (node.entity is! Directory && !isCommandPressed && !isShiftPressed) {
      _openFile(node.entity.path);
    }
  }

  void _handleSecondaryTap(FileSystemNode node, TapDownDetails details) {
    setState(() {
      if (!selectedPaths.contains(node.entity.path)) {
        selectedPaths.clear();
        selectedPaths.add(node.entity.path);
        lastSelectedPath = node.entity.path;
      }
    });
    _showContextMenu(context, [node], details);
  }

  void _handleFileDrop(String sourcePath, String targetPath) {
    _cancelExpandTimer();
    if (sourcePath == targetPath) return;

    final targetIsDirectory = FileSystemEntity.isDirectorySync(targetPath);
    final String destinationPath = targetIsDirectory ? targetPath : p.dirname(targetPath);
    final String newPath = p.join(destinationPath, p.basename(sourcePath));

    if (newPath != sourcePath) {
      widget.fileService.renameFile(sourcePath, newPath);
      _updateExpandedDirectories(sourcePath, newPath);
      _refreshDirectory();
    }
  }

  void _updateExpandedDirectories(String oldPath, String newPath) {
    if (FileSystemEntity.isDirectorySync(oldPath)) {
      final oldPrefix = oldPath + p.separator;
      final newPrefix = newPath + p.separator;
      expandedDirectories = expandedDirectories.map((path) {
        if (path.startsWith(oldPrefix)) {
          return newPrefix + path.substring(oldPrefix.length);
        }
        return path;
      }).toSet();
    }
  }

  void _showContextMenu(BuildContext context, List<FileSystemNode> nodes, TapDownDetails details) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    final List<ContextMenuItem> menuItems = _buildContextMenuItems(nodes);

    showCommonContextMenu(
      context: context,
      position: position,
      items: menuItems,
    );
  }

  List<ContextMenuItem> _buildContextMenuItems(List<FileSystemNode> nodes) {
    if (selectedPaths.length == 1) {
      return _buildSingleSelectionMenu(nodes.first);
    } else if (selectedPaths.isNotEmpty) {
      return _buildMultiSelectionMenu(nodes.first);
    }
    return [];
  }

  List<ContextMenuItem> _buildSingleSelectionMenu(FileSystemNode node) {
    final String path = node.entity.path;
    final bool isDirectory = node.entity is Directory;

    return [
      ContextMenuItem(label: 'New File', onTap: () => _createNew(path, isFile: true)),
      ContextMenuItem(label: 'New Folder', onTap: () => _createNew(path, isFile: false)),
      const ContextMenuItem(isDivider: true, label: ''),
      ContextMenuItem(label: 'Reveal In Finder', onTap: () => _revealFileInFinder(path)),
      const ContextMenuItem(isDivider: true, label: ''),
      ContextMenuItem(label: 'Copy', onTap: () => _copyFiles([path])),
      ContextMenuItem(label: 'Cut', onTap: () => _cutFiles([path])),
      ContextMenuItem(label: 'Paste', onTap: () => _pasteFiles(isDirectory ? path : p.dirname(path))),
      const ContextMenuItem(isDivider: true, label: ''),
      ContextMenuItem(label: 'Copy Path', onTap: () => _copyPath(path)),
      ContextMenuItem(label: 'Copy Relative Path', onTap: () => _copyRelativePath(path)),
      const ContextMenuItem(isDivider: true, label: ''),
      ContextMenuItem(label: 'Rename', onTap: () => _renameFile(node)),
      ContextMenuItem(label: 'Delete', onTap: () => _deleteFile(path)),
    ];
  }

  List<ContextMenuItem> _buildMultiSelectionMenu(FileSystemNode node) {
    return [
      ContextMenuItem(label: 'Copy', onTap: () => _copyFiles(selectedPaths.toList())),
      ContextMenuItem(label: 'Cut', onTap: () => _cutFiles(selectedPaths.toList())),
      ContextMenuItem(
        label: 'Paste',
        onTap: () {
          final path = node.entity.path;
          final pasteDir = node.entity is Directory ? path : p.dirname(path);
          _pasteFiles(pasteDir);
        },
      ),
      const ContextMenuItem(isDivider: true, label: ''),
      ContextMenuItem(label: 'Delete Selected', onTap: () => _deleteMultipleFiles(selectedPaths.toList())),
    ];
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
            decoration: InputDecoration(hintText: isFile ? 'file.txt' : 'New Folder'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final path = p.join(parentPath, controller.text);
                isFile ? widget.fileService.createFile(path) : widget.fileService.createFolder(path);
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
        final TextEditingController controller = TextEditingController(text: p.basename(node.entity.path));
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
                final newPath = p.join(p.dirname(node.entity.path), controller.text);
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

  void _openFile(String path) {
    widget.fileService.openFile(path);
    widget.tabService.addTab(p.basename(path), path, widget.fileService.getAbsolutePath(path));
  }

  void _copyFiles(List<String> paths) => widget.fileService.copyFiles(paths);
  void _cutFiles(List<String> paths) => widget.fileService.cutFiles(paths);

  void _pasteFiles(String destinationPath) {
    widget.fileService.pasteFiles(destinationPath, onNameConflict: _handleNameConflict);
    _refreshDirectory();
  }

  String _handleNameConflict(String path) {
    String baseName = p.basenameWithoutExtension(path);
    String extension = p.extension(path);
    int copyNumber = 1;
    String newPath = path;
    while (FileSystemEntity.typeSync(newPath) != FileSystemEntityType.notFound) {
      newPath = p.join(p.dirname(path), '$baseName - Copy $copyNumber$extension');
      copyNumber++;
    }
    return newPath;
  }

  void _copyPath(String path) => widget.fileService.copyPath(path);
  void _copyRelativePath(String path) => widget.fileService.copyRelativePath(path, widget.initialDirectory);
  void _revealFileInFinder(String path) => widget.fileService.revealInFinder(path);

  void _deleteFile(String path) {
    _isShiftPressed ? _performDelete([path]) : _showDeleteConfirmation([path]);
  }

  void _deleteMultipleFiles(List<String> paths) {
    _isShiftPressed ? _performDelete(paths) : _showDeleteConfirmation(paths);
  }

  void _showDeleteConfirmation(List<String> paths) {
    final int itemCount = paths.length;
    final String itemType = itemCount == 1
        ? (FileSystemEntity.isDirectorySync(paths.first) ? 'folder' : 'file')
        : 'items';
    final String itemName = itemCount == 1 ? p.basename(paths.first) : '$itemCount $itemType';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Are you sure you want to delete ${itemCount == 1 ? 'the $itemType' : ''} "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performDelete(paths);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _performDelete(List<String> paths) {
    for (var path in paths) {
      widget.fileService.deleteFile(path);
    }
    _refreshDirectory();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (_isSearchVisible) {
        _searchFocusNode.requestFocus();
      } else {
        _clearSearch();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _updateFilteredNodes('');
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _updateFilteredNodes(query);
    });
  }

  void _updateFilteredNodes(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredNodes = List.from(rootNodes);
      } else {
        _filteredNodes = _searchNodes(rootNodes, query.toLowerCase());
      }
    });
  }

  List<FileSystemNode> _searchNodes(List<FileSystemNode> nodes, String query) {
    List<FileSystemNode> results = [];
    for (var node in nodes) {
      if (p.basename(node.entity.path).toLowerCase().contains(query)) {
        results.add(node);
      }
      if (node.entity is Directory && node.children.isNotEmpty) {
        results.addAll(_searchNodes(node.children, query));
      }
    }
    return results;
  }

  void _collapseAll() {
    setState(() {
      _collapseNodes(rootNodes);
      expandedDirectories.clear();
    });
  }

  void _collapseNodes(List<FileSystemNode> nodes) {
    for (var node in nodes) {
      if (node.entity is Directory) {
        node.isExpanded = false;
        node.children.clear();
      }
    }
  }

  void _expandAll() {
    setState(() {
      _expandNodes(rootNodes);
    });
  }

  void _expandNodes(List<FileSystemNode> nodes) {
    for (var node in nodes) {
      if (node.entity is Directory) {
        node.isExpanded = true;
        expandedDirectories.add(node.entity.path);
        node.children = widget.fileService
            .listDirectory(node.entity.path)
            .map((entity) => FileSystemNode(entity))
            .toList();
        _sortNodes(node.children);
        _expandNodes(node.children);
      }
    }
  }

  void _toggleSelection(String path) {
    selectedPaths.contains(path) ? selectedPaths.remove(path) : selectedPaths.add(path);
    lastSelectedPath = path;
  }

  void _selectSingle(String path) {
    selectedPaths
      ..clear()
      ..add(path);
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

  void _handleEmptySpaceClick() {
    setState(() {
      selectedPaths.clear();
      lastSelectedPath = null;
    });
  }

  void _showEmptySpaceContextMenu(BuildContext context, TapDownDetails details) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    final List<ContextMenuItem> menuItems = [
      ContextMenuItem(label: 'New File', onTap: () => _createNew(widget.initialDirectory, isFile: true)),
      ContextMenuItem(label: 'New Folder', onTap: () => _createNew(widget.initialDirectory, isFile: false)),
      const ContextMenuItem(isDivider: true, label: ''),
      ContextMenuItem(label: 'Paste', onTap: () => _pasteFiles(widget.initialDirectory)),
    ];

    showCommonContextMenu(
      context: context,
      position: position,
      items: menuItems,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
          event.logicalKey == LogicalKeyboardKey.shiftRight) {
        setState(() => _isShiftPressed = true);
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
          event.logicalKey == LogicalKeyboardKey.shiftRight) {
        setState(() => _isShiftPressed = false);
      }
    }
    return KeyEventResult.ignored;
  }

  void _startExpandTimer(FileSystemNode node) {
    _cancelExpandTimer();
    _hoveredFolderPath = node.entity.path;
    _expandTimer = Timer(const Duration(milliseconds: 500), () {
      if (_hoveredFolderPath == node.entity.path) {
        setState(() {
          if (!node.isExpanded) {
            _toggleDirectory(node);
          }
        });
      }
    });
  }

  void _cancelExpandTimer() {
    _expandTimer?.cancel();
    _hoveredFolderPath = null;
  }

  void _handleDelete() {
    if (selectedPaths.isNotEmpty) {
      _deleteMultipleFiles(selectedPaths.toList());
    }
  }

  void _sortNodes(List<FileSystemNode> nodes) {
    nodes.sort((a, b) {
      if (a.entity is Directory && b.entity is! Directory) {
        return -1;
      } else if (a.entity is! Directory && b.entity is Directory) {
        return 1;
      } else {
        return p.basename(a.entity.path).toLowerCase().compareTo(p.basename(b.entity.path).toLowerCase());
      }
    });
  }
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}
