import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/services/theme_manager.dart';

class CustomTooltip extends StatelessWidget {
  final Widget child;
  final String message;
  final Duration waitDuration;
  final TextStyle? textStyle;

  const CustomTooltip({
    Key? key,
    required this.child,
    required this.message,
    this.waitDuration = const Duration(milliseconds: 500),
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final theme = Theme.of(context);
    final isDarkMode = themeManager.themeMode == ThemeMode.dark ||
        (themeManager.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Tooltip(
      message: message,
      waitDuration: waitDuration,
      decoration: BoxDecoration(
        color: isDarkMode
            ? theme.colorScheme.surface
            : theme.colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: TextStyle(
        color: isDarkMode
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onInverseSurface,
        fontSize: textStyle?.fontSize ?? 12,
        fontWeight: textStyle?.fontWeight ?? FontWeight.w400,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      preferBelow: true,
      child: child,
    );
  }
}

