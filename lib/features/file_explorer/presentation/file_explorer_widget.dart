import 'dart:io';

import 'package:flutter/material.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/features/file_explorer/presentation/file_explorer.dart';

class FileExplorerWidget extends StatelessWidget {
  final FileExplorerController controller;
  final Function(File) onFileSelected;
  final Function(String?) onDirectorySelected;

  const FileExplorerWidget({
    super.key,
    required this.controller,
    required this.onFileSelected,
    required this.onDirectorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: FileExplorer(
        controller: controller,
        onFileSelected: onFileSelected,
        onDirectorySelected: onDirectorySelected,
      ),
    );
  }
}
