import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';

class QuickActionBar extends StatelessWidget {
  final Function() onNewFolder;
  final Function() onNewFile;
  final Function(BuildContext, FileExplorerController) onCopy;
  final Function(BuildContext, FileExplorerController) onCut;
  final Function(FileExplorerController) onPaste;
  final Function() onRefresh;

  const QuickActionBar({
    super.key,
    required this.onNewFolder,
    required this.onNewFile,
    required this.onCopy,
    required this.onCut,
    required this.onPaste,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<FileExplorerController>(context);

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
          _buildActionButton(
            icon: Icons.create_new_folder_outlined,
            tooltip: 'New Folder',
            onPressed: onNewFolder,
          ),
          _buildActionButton(
            icon: Icons.note_add_outlined,
            tooltip: 'New File',
            onPressed: onNewFile,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.content_copy,
            tooltip: 'Copy',
            onPressed: () => onCopy(context, controller),
          ),
          _buildActionButton(
            icon: Icons.content_cut,
            tooltip: 'Cut',
            onPressed: () => onCut(context, controller),
          ),
          _buildActionButton(
            icon: Icons.content_paste,
            tooltip: 'Paste',
            onPressed: () {
              onPaste(controller);
            },
          ),
          const Spacer(),
          _buildActionButton(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            onPressed: onRefresh,
          ),
        ],
      ),
    );
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
