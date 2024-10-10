import 'package:flutter/material.dart';

class QuickAccessBar extends StatelessWidget {
  final VoidCallback onNewFile;
  final VoidCallback onNewFolder;
  final VoidCallback onRefresh;
  final VoidCallback onCollapseAll;
  final VoidCallback onExpandAll;
  final VoidCallback onSearch;
  final bool isSearchVisible;

  const QuickAccessBar({
    Key? key,
    required this.onNewFile,
    required this.onNewFolder,
    required this.onRefresh,
    required this.onCollapseAll,
    required this.onExpandAll,
    required this.onSearch,
    required this.isSearchVisible,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                isSearchVisible ? Colors.transparent : Colors.lightBlue[200]!,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildIconButton(Icons.add, 'New File', onNewFile),
          _buildIconButton(Icons.create_new_folder, 'New Folder', onNewFolder),
          _buildIconButton(Icons.refresh, 'Refresh', onRefresh),
          _buildIconButton(Icons.unfold_less, 'Collapse All', onCollapseAll),
          _buildIconButton(Icons.unfold_more, 'Expand All', onExpandAll),
          _buildIconButton(Icons.search, 'Search', onSearch),
        ],
      ),
    );
  }

  Widget _buildIconButton(
      IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 20,
        height: 20,
        child: IconButton(
          padding: const EdgeInsets.all(0),
          icon: Icon(icon, size: 16),
          onPressed: onPressed,
          splashRadius: 5,
        ),
      ),
    );
  }
}

