import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:starlight/features/command_palette/command_palette.dart';
import 'package:starlight/features/file_explorer/infrastructure/services/git_service.dart';
import 'package:starlight/features/status_bar/status_bar.dart';
import 'package:starlight/services/file_explorer_service.dart';
import 'package:starlight/themes/theme_provider.dart';
import 'package:window_manager/window_manager.dart';

class UIService extends ChangeNotifier {
  bool _showFileExplorer = true;
  String? _currentDirectoryPath;
  bool get showFileExplorer => _showFileExplorer;

  late GitService _gitService;

  UIService(GitService gitService) {
    _gitService = gitService;
  }

  set currentDirectoryPath(String? path) {
    _currentDirectoryPath = path;
    if (path != null) {
      _gitService.getCurrentBranch(path);
      _gitService.fetchBranches(path);
    }
    notifyListeners();
  }

  Widget buildAppBar(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDarkMode,
    bool isFullscreen,
  ) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
            ),
          ),
          Row(
            children: [
              _buildLeadingSpace(isFullscreen),
              _buildDirectoryButton(context),
              _buildBranchSelector(context),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingSpace(bool isFullscreen) {
    if (kIsWeb) {
      return const SizedBox(width: 0);
    } else if (Platform.isMacOS && !isFullscreen) {
      return const SizedBox(width: 68);
    } else {
      return const SizedBox(width: 0);
    }
  }

  Widget _buildDirectoryButton(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable:
          Provider.of<FileExplorerService>(context).selectedDirectory,
      builder: (context, directory, _) {
        return directory != null
            ? TextButton(
                onPressed: () =>
                    Provider.of<FileExplorerService>(context, listen: false)
                        .pickDirectory(),
                child: Text(
                  directory.split('/').last,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              )
            : const SizedBox.shrink();
      },
    );
  }

  Widget _buildBranchSelector(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: _gitService.currentBranch,
      builder: (context, currentBranch, _) {
        return TextButton(
          onPressed: _currentDirectoryPath != null
              ? () => _openBranchSelector(context)
              : null,
          child: Row(
            children: [
              const Icon(Icons.call_split, size: 16),
              const SizedBox(width: 4),
              Text(
                currentBranch.isNotEmpty ? currentBranch : 'No branch',
                style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.color
                      ?.withOpacity(0.8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openBranchSelector(BuildContext context) {
    if (_currentDirectoryPath == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CommandPalette(
          commands: _getBranchCommands(),
          onCommandSelected: (command) {
            Navigator.of(context).pop();
            command.action();
          },
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  List<Command> _getBranchCommands() {
    if (_currentDirectoryPath == null) return [];

    return _gitService.branches.map((branch) {
      return Command(
        name: branch,
        icon: Icons.call_split,
        action: () {
          if (_currentDirectoryPath != null) {
            _gitService.switchBranch(branch, _currentDirectoryPath!);
          }
        },
      );
    }).toList();
  }

  Widget buildStatusBar(BuildContext context) {
    return const StatusBar();
  }

  void toggleFileExplorer() {
    _showFileExplorer = !_showFileExplorer;
    notifyListeners();
  }
}
