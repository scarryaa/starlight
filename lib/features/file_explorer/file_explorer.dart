import 'dart:io';
import 'package:flutter/material.dart';
import 'package:starlight/features/file_explorer/file_Explorer_controller.dart';
import 'package:starlight/features/file_explorer/services/file_service.dart';
import 'file_tree_item.dart';

import 'package:provider/provider.dart';

class FileExplorer extends StatefulWidget {
  final Function(File) onFileSelected;
  final Function(String?) onDirectorySelected;
  final FileExplorerController controller;

  const FileExplorer({
    super.key,
    required this.onFileSelected,
    required this.onDirectorySelected,
    required this.controller,
  });

  @override
  FileExplorerState createState() => FileExplorerState();
}

class FileExplorerState extends State<FileExplorer> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.controller,
      child: _FileExplorerContent(
        onFileSelected: widget.onFileSelected,
        onDirectorySelected: widget.onDirectorySelected,
      ),
    );
  }

  @override
  void didUpdateWidget(FileExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      setState(() {});
    }
  }
}

class _FileExplorerContent extends StatefulWidget {
  final Function(File) onFileSelected;
  final Function(String?) onDirectorySelected;

  const _FileExplorerContent({
    required this.onFileSelected,
    required this.onDirectorySelected,
  });

  @override
  _FileExplorerContentState createState() => _FileExplorerContentState();
}

class _FileExplorerContentState extends State<_FileExplorerContent>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  Future<void> _pickDirectory() async {
    final controller = context.read<FileExplorerController>();
    try {
      String? selectedDirectory = await FileService.pickDirectory();
      if (selectedDirectory != null) {
        controller.setDirectory(Directory(selectedDirectory));
        widget.onDirectorySelected(selectedDirectory);
      }
    } catch (e) {
      print('Error picking directory: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting directory: $e')),
      );
    } finally {
      controller.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Consumer<FileExplorerController>(
              builder: (context, controller, child) =>
                  _buildFileExplorer(theme, controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileExplorer(
      ThemeData theme, FileExplorerController controller) {
    if (controller.isLoading) {
      return Center(
          child: CircularProgressIndicator(color: theme.primaryColor));
    }
    if (controller.currentDirectory == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: theme.iconTheme.color?.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _pickDirectory,
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: Text(
                'Select Directory',
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              ),
            ),
          ],
        ),
      );
    }
    return Theme(
      data: theme.copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(
              theme.colorScheme.secondary.withOpacity(0.6)),
          thickness: WidgetStateProperty.all(6.0),
          radius: const Radius.circular(0),
        ),
      ),
      child: Scrollbar(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          children: [
            FileTreeItem(
              key: ValueKey(controller.currentDirectory?.path),
              entity: controller.currentDirectory!,
              onFileSelected: widget.onFileSelected,
              level: 0,
              isInitiallyExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}
