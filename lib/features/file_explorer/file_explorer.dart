import 'dart:io';
import 'package:flutter/material.dart';
import 'package:starlight/features/file_explorer/services/file_service.dart';
import 'package:starlight/utils/constants.dart';
import 'file_tree_item.dart';

class FileExplorer extends StatefulWidget {
  final Function(File) onFileSelected;

  const FileExplorer({super.key, required this.onFileSelected});

  @override
  FileExplorerState createState() => FileExplorerState();
}

class FileExplorerState extends State<FileExplorer>
    with AutomaticKeepAliveClientMixin {
  Directory? _currentDirectory;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  Future<void> _pickDirectory() async {
    try {
      String? selectedDirectory = await FileService.pickDirectory();
      setState(() {
        _currentDirectory = Directory(selectedDirectory ?? "./");
        _isLoading = false;
      });
    } catch (e) {
      print('Error picking directory: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting directory: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildFileExplorer(),
          ),
        ],
      ),
    );
  }

  Widget _buildFileExplorer() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_currentDirectory == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: textColor.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _pickDirectory,
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: const Text(
                'Select Directory',
                style: TextStyle(color: textColor),
              ),
            ),
          ],
        ),
      );
    }
    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(Colors.grey[600]),
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
              key: ValueKey(_currentDirectory?.path),
              entity: _currentDirectory!,
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
