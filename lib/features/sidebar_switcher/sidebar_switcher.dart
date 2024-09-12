import 'dart:io';

import 'package:flutter/material.dart';
import 'package:starlight/features/file_explorer/file_explorer.dart';
import 'package:starlight/features/file_explorer/file_Explorer_controller.dart';

enum SidebarOption { fileExplorer, settings }

class SidebarSwitcher extends StatefulWidget {
  final Function(File) onFileSelected;
  final Function(String?) onDirectorySelected;
  final FileExplorerController fileExplorerController;

  const SidebarSwitcher({
    super.key,
    required this.onFileSelected,
    required this.onDirectorySelected,
    required this.fileExplorerController,
  });

  @override
  _SidebarSwitcherState createState() => _SidebarSwitcherState();
}

class _SidebarSwitcherState extends State<SidebarSwitcher> {
  SidebarOption _selectedOption = SidebarOption.fileExplorer;

  Widget _buildSidebarContent() {
    switch (_selectedOption) {
      case SidebarOption.fileExplorer:
        return FileExplorer(
          onFileSelected: widget.onFileSelected,
          onDirectorySelected: widget.onDirectorySelected,
          controller: widget.fileExplorerController,
        );
      case SidebarOption.settings:
        return const Center(
            child: Text('Settings')); // Placeholder for settings
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSidebarHeader(),
        Expanded(child: _buildSidebarContent()),
      ],
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      height: 40,
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSidebarButton(SidebarOption.fileExplorer, Icons.folder),
          _buildSidebarButton(SidebarOption.settings, Icons.settings),
        ],
      ),
    );
  }

  Widget _buildSidebarButton(SidebarOption option, IconData icon) {
    final isSelected = _selectedOption == option;
    return IconButton(
      icon: Icon(icon),
      color: isSelected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).iconTheme.color,
      onPressed: () => setState(() => _selectedOption = option),
    );
  }
}
