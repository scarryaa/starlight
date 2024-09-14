import 'package:flutter/material.dart';

class PinButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isPinned;
  final Color? color;

  const PinButton({
    super.key,
    required this.onTap,
    required this.isPinned,
    this.color,
  });

  @override
  State<PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<PinButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: _isHovered ? theme.hoverColor : Colors.transparent,
          ),
          child: Icon(
            widget.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            size: 14,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
