import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:starlight/services/file_explorer_service.dart';
import 'package:starlight/themes/theme_provider.dart';
import 'package:window_manager/window_manager.dart';

class UIService extends ChangeNotifier {
  bool _showFileExplorer = true;
  bool get showFileExplorer => _showFileExplorer;

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
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingSpace(bool isFullscreen) {
    if (kIsWeb) {
      return const SizedBox(width: 16);
    } else if (Platform.isMacOS && !isFullscreen) {
      return const SizedBox(
          width: 78); // Space for traffic lights when not fullscreen
    } else {
      return const SizedBox(width: 16);
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

  Widget buildStatusBar(BuildContext context) {
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
    );
  }

  void toggleFileExplorer() {
    _showFileExplorer = !_showFileExplorer;
    notifyListeners();
  }
}
