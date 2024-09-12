import 'package:flutter/material.dart';

class MenuActions {
  static void about(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Starlight',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2024 Starlight Team',
    );
  }

  static void copy(BuildContext context) {
    // CodeEditor.of(context).copySelection();
  }

  static void cut(BuildContext context) {
    // CodeEditor.of(context).cutSelection();
  }

  static void paste(BuildContext context) {
    // CodeEditor.of(context).pasteAtCursor();
  }

  static void redo(BuildContext context) {
    // CodeEditor.of(context).redo();
  }

  static void undo(BuildContext context) {
    // CodeEditor.of(context).undo();
  }
}
