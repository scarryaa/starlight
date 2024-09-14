import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/services/file_explorer_service.dart';
import 'package:starlight/themes/theme_provider.dart';
import 'package:window_manager/window_manager.dart';

class UIService {
  Widget buildAppBar(
      BuildContext context, ThemeProvider themeProvider, bool isDarkMode) {
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
              const SizedBox(width: 70),
              const SizedBox(width: 8),
              ValueListenableBuilder<String?>(
                valueListenable:
                    Provider.of<FileExplorerService>(context).selectedDirectory,
                builder: (context, directory, _) {
                  return directory != null
                      ? TextButton(
                          onPressed: () => Provider.of<FileExplorerService>(
                                  context,
                                  listen: false)
                              .pickDirectory(),
                          child: Text(
                            directory.split('/').last,
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                },
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: Theme.of(context).appBarTheme.iconTheme?.color,
                  size: 14,
                ),
                onPressed: () => themeProvider.toggleTheme(),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
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
}
