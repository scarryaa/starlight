import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/command_palette/command_palette.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';
import 'package:starlight/features/file_explorer/domain/models/git_status.dart';
import 'package:starlight/services/editor_service.dart';
import 'package:starlight/services/file_explorer_service.dart';
import 'package:starlight/services/lsp_service.dart';
import 'package:starlight/features/file_explorer/infrastructure/services/git_service.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final fileExplorerService = Provider.of<FileExplorerService>(context);
    final lspService = Provider.of<LspService>(context);
    final editorService = Provider.of<EditorService>(context);
    final gitService = Provider.of<GitService?>(context, listen: false);

    return ValueListenableBuilder<FileTreeItem?>(
      valueListenable: fileExplorerService.currentFileNotifier,
      builder: (context, currentFile, _) {
        if (currentFile != null) {
          lspService.updateForFile(currentFile.path);
        }
        return Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              _buildLanguageSelector(context, lspService),
              const SizedBox(width: 16),
              _buildCursorPosition(editorService),
              const SizedBox(width: 16),
              _buildFileInfo(context, currentFile),
              if (gitService != null) ...[
                const SizedBox(width: 16),
                _buildGitInfo(gitService, currentFile),
              ],
              const Spacer(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCursorPosition(EditorService editorService) {
    return StreamBuilder<String>(
      stream: editorService.editorKey.currentState?.cursorPositionStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text(
            snapshot.data!,
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Text(
          'Ln 1, Col 1',
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
    );
  }

  Widget _buildFileInfo(BuildContext context, FileTreeItem? currentFile) {
    if (currentFile == null) {
      return Text(
        'No file selected',
        style: Theme.of(context).textTheme.bodySmall,
      );
    } else {
      return Text(
        currentFile.name,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
  }

  Widget _buildGitInfo(GitService gitService, FileTreeItem? currentFile) {
    if (currentFile == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, GitStatus>>(
      future: gitService.getDirectoryGitStatus(currentFile.path),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.containsKey(currentFile.path)) {
          final status = snapshot.data![currentFile.path];
          return Row(
            children: [
              const Icon(Icons.source_rounded, size: 16),
              const SizedBox(width: 4),
              Text(
                status.toString().split('.').last,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLanguageSelector(BuildContext context, LspService lspService) {
    return TextButton(
      onPressed: () => _showLanguageCommandPalette(context, lspService),
      child: Text(
        lspService.currentLanguage,
        style: TextStyle(fontSize: 12),
      ),
    );
  }

  void _showLanguageCommandPalette(
      BuildContext context, LspService lspService) {
    final commands = lspService.supportedLanguages
        .map((lang) => Command(
              name: lang,
              description: 'Set language to $lang',
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
