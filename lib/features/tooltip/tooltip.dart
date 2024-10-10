import 'package:flutter/material.dart';

enum TooltipTheme {
  light,
  dark,
}

class CustomTooltip extends StatelessWidget {
  final Widget child;
  final String message;
  final Duration waitDuration;
  final TooltipTheme theme;
  final TextStyle? textStyle;

  const CustomTooltip({
    super.key,
    required this.child,
    required this.message,
    this.waitDuration = const Duration(milliseconds: 500),
    this.theme = TooltipTheme.dark,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = theme == TooltipTheme.dark;

    return Tooltip(
      message: message,
      waitDuration: waitDuration,
      decoration: BoxDecoration(
        color: isDarkTheme ? Colors.grey[850] : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: TextStyle(
        color: isDarkTheme ? Colors.white : Colors.black87,
        fontSize: textStyle?.fontSize,
        fontWeight: FontWeight.w400,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      preferBelow: true,
      child: child,
    );
  }
}
