import 'package:flutter/material.dart';

class DirectorySelectionPrompt extends StatelessWidget {
  final Function() onSelectDirectory;

  const DirectorySelectionPrompt({
    super.key,
    required this.onSelectDirectory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: theme.iconTheme.color?.withOpacity(0.7),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: onSelectDirectory,
            style: TextButton.styleFrom(
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Select Directory',
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
