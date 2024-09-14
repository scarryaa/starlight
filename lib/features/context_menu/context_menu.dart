import 'package:flutter/material.dart';

class ContextMenuItem {
  final String title;
  final VoidCallback onTap;

  ContextMenuItem({required this.title, required this.onTap});
}

class ContextMenu extends StatelessWidget {
  final List<ContextMenuItem> items;

  const ContextMenu({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2.0,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                items.map((item) => _buildMenuItem(context, item)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, ContextMenuItem item) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        item.onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        width: double.infinity,
        child: Text(
          item.title,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ),
    );
  }
}
