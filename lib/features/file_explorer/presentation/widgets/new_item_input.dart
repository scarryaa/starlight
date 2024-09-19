import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';

class NewItemInput extends StatefulWidget {
  final Function(String, bool) onItemCreated;
  final VoidCallback onCancel;
  final FileTreeItem? parent;
  final bool isCreatingFile;

  const NewItemInput({
    super.key,
    required this.onItemCreated,
    required this.onCancel,
    this.parent,
    required this.isCreatingFile,
  });

  @override
  _NewItemInputState createState() => _NewItemInputState();
}

class _NewItemInputState extends State<NewItemInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus && !_isSubmitting) {
          _handleSubmit(_controller.text);
        }
      },
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onCancel();
          }
        },
        child: Container(
          padding:
              EdgeInsets.only(left: 8.0 + (widget.parent?.level ?? 0) * 16.0),
          height: 24,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              prefixIcon: Icon(
                widget.isCreatingFile ? Icons.insert_drive_file : Icons.folder,
                size: 14,
              ),
            ),
            onSubmitted: _handleSubmit,
          ),
        ),
      ),
    );
  }

  void _handleSubmit(String value) {
    final name = value.trim();
    if (name.isNotEmpty) {
      setState(() {
        _isSubmitting = true;
      });
      widget.onItemCreated(name, widget.isCreatingFile);
    } else {
      widget.onCancel();
    }
  }
}
