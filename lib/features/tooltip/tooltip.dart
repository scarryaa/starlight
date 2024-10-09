import 'package:flutter/material.dart';

class CustomTooltip extends StatelessWidget {
  final Widget child;
  final String message;
  final Duration waitDuration;

  const CustomTooltip({
    Key? key,
    required this.child,
    required this.message,
    this.waitDuration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      waitDuration: waitDuration,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      preferBelow: true,
      child: child,
    );
  }
}
