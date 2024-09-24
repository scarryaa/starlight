import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';

class QuickActionBar extends StatefulWidget {
  final Function() onNewFolder;
  final Function() onNewFile;
  final Function(BuildContext, FileExplorerController) onCopy;
  final Function(BuildContext, FileExplorerController) onCut;
  final Function(FileExplorerController) onPaste;
  final Function() onExpandAll;
  final Function() onCollapseAll;
  final Function() onSearch;
  final Function() onToggleSystemFiles;

  const QuickActionBar({
    super.key,
    required this.onNewFolder,
    required this.onNewFile,
    required this.onCopy,
    required this.onCut,
    required this.onPaste,
    required this.onExpandAll,
    required this.onCollapseAll,
    required this.onSearch,
    required this.onToggleSystemFiles,
  });

  @override
  State<QuickActionBar> createState() => _QuickActionBarState();
}

class _QuickActionBarState extends State<QuickActionBar> {
  String? _expandedCategory;

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<FileExplorerController>(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMainBar(context),
        if (_expandedCategory != null) _buildSubBar(context, controller),
      ],
    );
  }

  Widget _buildMainBar(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildToggleButton(
            icon: Icons.folder_outlined,
            tooltip: 'File Actions',
            category: 'File',
          ),
          _buildToggleButton(
            icon: Icons.visibility_outlined,
            tooltip: 'View Actions',
            category: 'View',
          ),
          _buildToggleButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit Actions',
            category: 'Edit',
          ),
          const Spacer(),
          _buildActionButton(
            icon: Icons.search,
            tooltip: 'Search',
            onPressed: widget.onSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String tooltip,
    required String category,
  }) {
    final isSelected = _expandedCategory == category;
    final color = isSelected ? Theme.of(context).primaryColor : Colors.grey;
    final backgroundColor = isSelected
        ? Theme.of(context).primaryColor.withOpacity(0.1)
        : Colors.transparent;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedCategory = isSelected ? null : category;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildSubBar(BuildContext context, FileExplorerController controller) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: _buildActionButtonsForCategory(context, controller),
      ),
    );
  }

  List<Widget> _buildActionButtonsForCategory(
      BuildContext context, FileExplorerController controller) {
    switch (_expandedCategory) {
      case 'File':
        return [
          _buildActionButton(
            icon: Icons.create_new_folder_outlined,
            tooltip: 'New Folder',
            onPressed: widget.onNewFolder,
          ),
          _buildActionButton(
            icon: Icons.note_add_outlined,
            tooltip: 'New File',
            onPressed: widget.onNewFile,
          ),
        ];
      case 'View':
        return [
          _buildActionButton(
            icon: Icons.expand,
            tooltip: 'Expand All',
            onPressed: widget.onExpandAll,
          ),
          _buildActionButton(
            icon: Icons.compress,
            tooltip: 'Collapse All',
            onPressed: widget.onCollapseAll,
          ),
          _buildActionButton(
            icon: controller.hideSystemFiles
                ? Icons.visibility_off
                : Icons.visibility,
            tooltip: controller.hideSystemFiles
                ? 'Show System Files'
                : 'Hide System Files',
            onPressed: widget.onToggleSystemFiles,
          ),
        ];
      case 'Edit':
        return [
          _buildActionButton(
            icon: Icons.content_copy,
            tooltip: 'Copy',
            onPressed: () => widget.onCopy(context, controller),
          ),
          _buildActionButton(
            icon: Icons.content_cut,
            tooltip: 'Cut',
            onPressed: () => widget.onCut(context, controller),
          ),
          _buildActionButton(
            icon: Icons.content_paste,
            tooltip: 'Paste',
            onPressed: () => widget.onPaste(controller),
          ),
        ];
      default:
        return [];
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
