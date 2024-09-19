import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/features/file_explorer/presentation/widgets/file_explorer_content.dart';

class FileExplorer extends StatelessWidget {
  final Function(File) onFileSelected;
  final Function(String?) onDirectorySelected;
  final FileExplorerController controller;
  final Function(String) onOpenInTerminal;

  const FileExplorer({
    super.key,
    required this.onFileSelected,
    required this.onDirectorySelected,
    required this.controller,
    required this.onOpenInTerminal,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: FileExplorerContent(
        onFileSelected: onFileSelected,
        onDirectorySelected: onDirectorySelected,
        onOpenInTerminal: onOpenInTerminal,
      ),
    );
  }
}
