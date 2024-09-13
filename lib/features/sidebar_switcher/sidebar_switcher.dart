import 'dart:io';
import 'package:flutter/material.dart';
import 'package:starlight/features/file_explorer/file_Explorer_controller.dart';
import 'package:starlight/features/file_explorer/file_explorer.dart';
import 'package:starlight/features/search/search.dart';

enum SidebarOption { fileExplorer, search, settings }

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
  bool _isSidebarExpanded = true;

  Widget _buildSidebarContent() {
    switch (_selectedOption) {
      case SidebarOption.fileExplorer:
        return FileExplorer(
          onFileSelected: widget.onFileSelected,
          onDirectorySelected: widget.onDirectorySelected,
          controller: widget.fileExplorerController,
        );
      case SidebarOption.search:
        return SearchPane(
          onFileSelected: widget.onFileSelected,
          rootDirectory:
              widget.fileExplorerController.currentDirectory?.path ?? '/',
        );
      case SidebarOption.settings:
        return const Center(child: Text('Settings'));
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildSidebarIcons(),
        if (_isSidebarExpanded)
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: _buildSidebarContent(),
            ),
          ),
      ],
    );
  }

  Widget _buildSidebarIcons() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        border: Border(
          right: BorderSide(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      width: 48,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildSidebarIconButton(
              SidebarOption.fileExplorer, Icons.folder_outlined),
          _buildSidebarIconButton(SidebarOption.search, Icons.search),
          const Spacer(),
          _buildSidebarIconButton(
              SidebarOption.settings, Icons.settings_outlined),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSidebarIconButton(SidebarOption option, IconData icon) {
    final isSelected = _selectedOption == option;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: IconButton(
        icon: Icon(icon),
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).iconTheme.color,
        onPressed: () => setState(() {
          _selectedOption = option;
          _isSidebarExpanded = true;
        }),
      ),
    );
  }

  Widget _buildSidebarToggleButton() {
    return IconButton(
      icon: Icon(_isSidebarExpanded ? Icons.chevron_left : Icons.chevron_right),
      onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
    );
  }
}
