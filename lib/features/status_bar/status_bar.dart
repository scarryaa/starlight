import 'package:flutter/material.dart' hide Tab;
import 'package:provider/provider.dart';
import 'package:starlight/services/tab_service.dart';
import 'package:starlight/services/config_service.dart';
import 'package:starlight/features/editor/models/cursor_position.dart';

class StatusBar extends StatelessWidget {
  final TabService tabService;
  final ConfigService configService;

  const StatusBar({
    super.key,
    required this.tabService,
    required this.configService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<TabService>(
      builder: (context, tabService, child) {
        return Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Colors.lightBlue[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // File Explorer Toggle
              ValueListenableBuilder<bool>(
                valueListenable: configService.fileExplorerVisibilityNotifier,
                builder: (context, isVisible, child) {
                  return IconButton(
                    icon: Icon(
                      isVisible ? Icons.folder : Icons.folder_outlined,
                      size: 16,
                    ),
                    onPressed: configService.toggleFileExplorerVisibility,
                    tooltip:
                        isVisible ? 'Hide File Explorer' : 'Show File Explorer',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 24, height: 24),
                  );
                },
              ),
              const Spacer(), // This pushes the following items to the right
              // Cursor Position and Tab Size
              ValueListenableBuilder<CursorPosition>(
                valueListenable: tabService.cursorPositionNotifier,
                builder: (context, cursorPosition, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _showChangeTabSizeDialog(context),
                        child: Text(
                          'Tabs: ${configService.config['tabSize'] ?? 4}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (tabService.tabs.isNotEmpty)
                        GestureDetector(
                          onTap: () =>
                              _showJumpToLineDialog(context, cursorPosition),
                          child: Text(
                            '${cursorPosition.line + 1}:${cursorPosition.column + 1}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showJumpToLineDialog(
      BuildContext context, CursorPosition currentPosition) {
    final controller = TextEditingController(
        text: '${currentPosition.line + 1}:${currentPosition.column + 1}');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Jump to Line:Column'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
                hintText: 'Enter line:column (e.g., 1:1)'),
            keyboardType: TextInputType.text,
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Jump'),
              onPressed: () {
                final parts = controller.text.split(':');
                if (parts.length == 2) {
                  final line = int.tryParse(parts[0]);
                  final column = int.tryParse(parts[1]);
                  if (line != null && column != null) {
                    tabService.jumpToCursorPosition(line - 1, column - 1);
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showChangeTabSizeDialog(BuildContext context) {
    final controller =
        TextEditingController(text: '${configService.config['tabSize'] ?? 4}');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Tab Size'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter new tab size'),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Change'),
              onPressed: () {
                final newSize = int.tryParse(controller.text);
                if (newSize != null && newSize > 0) {
                  configService.config['tabSize'] = newSize;
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}
