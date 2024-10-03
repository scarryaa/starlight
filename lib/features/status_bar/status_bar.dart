import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/command_palette/command_palette.dart';
import 'package:starlight/features/editor/presentation/editor_widget.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';
import 'package:starlight/features/file_explorer/domain/models/git_status.dart';
import 'package:starlight/services/editor_service.dart';
import 'package:starlight/services/file_explorer_service.dart';
import 'package:starlight/services/lsp_service.dart';
import 'package:starlight/features/file_explorer/infrastructure/services/git_service.dart';
import 'package:starlight/services/settings_service.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final fileExplorerService = Provider.of<FileExplorerService>(context);
    final lspService = Provider.of<LspService>(context);
    final gitService = Provider.of<GitService?>(context, listen: false);
    final settingsService = Provider.of<SettingsService>(context);

    return ValueListenableBuilder<FileTreeItem?>(
      valueListenable: fileExplorerService.currentFileNotifier,
      builder: (context, currentFile, _) {
        if (currentFile != null) {
          lspService.updateForFile(currentFile.path);
        }
        return Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              _buildFileExplorerToggle(context, settingsService),
              const Spacer(),
              _buildLanguageSelector(context, lspService),
              const SizedBox(width: 16),
              _buildFileInfo(context, currentFile),
              if (gitService != null) ...[
                const SizedBox(width: 16),
                _buildGitInfo(gitService, currentFile),
              ],
              const SizedBox(width: 16),
              _buildCursorPosition(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFileExplorerToggle(
      BuildContext context, SettingsService settingsService) {
    return IconButton(
      icon: Icon(
        settingsService.showFileExplorer ? Icons.folder : Icons.folder_outlined,
      ),
      iconSize: 16,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () {
        settingsService.setShowFileExplorer(!settingsService.showFileExplorer);
      },
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      tooltip: settingsService.showFileExplorer
          ? 'Hide File Explorer'
          : 'Show File Explorer',
    );
  }

  Widget _buildCursorPosition(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: EditorWidget.cursorPositionNotifier,
      builder: (context, position, _) {
        return Text(
          position,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        );
      },
    );
  }

  Widget _buildFileInfo(BuildContext context, FileTreeItem? currentFile) {
    final text = currentFile?.name ?? 'No file selected';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          currentFile != null ? Icons.insert_drive_file : Icons.folder_open,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildGitInfo(GitService gitService, FileTreeItem? currentFile) {
    if (currentFile == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, GitStatus>>(
      future: gitService.getDirectoryGitStatus(currentFile.path),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.containsKey(currentFile.path)) {
          final status = snapshot.data![currentFile.path];
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.source_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                status.toString().split('.').last,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLanguageSelector(BuildContext context, LspService lspService) {
    return ValueListenableBuilder<bool>(
      valueListenable: lspService.isLspRunningNotifier,
      builder: (context, isLspRunning, _) {
        return InkWell(
          onTap: () => _showLanguageCommandPalette(context, lspService),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLspRunning ? Icons.code : Icons.code_off,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  lspService.currentLanguage,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageCommandPalette(
      BuildContext context, LspService lspService) {
    final commands = lspService.supportedLanguages
        .map((lang) => Command(
              name: lang,
              icon: Icons.language,
              action: () => lspService.setLanguage(lang),
            ))
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CommandPalette(
          commands: commands,
          onCommandSelected: (command) {
            command.action();
            Navigator.of(context).pop();
          },
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}
