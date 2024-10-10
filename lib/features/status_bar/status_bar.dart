import 'package:flutter/material.dart' hide Tab;
import 'package:starlight/services/tab_service.dart';
import 'package:starlight/services/config_service.dart';
import 'package:starlight/widgets/tab/tab.dart';
import 'package:starlight/features/editor/models/cursor_position.dart';

class StatusBar extends StatelessWidget {
  final TabService tabService;
  final ConfigService configService;

  const StatusBar({
    super.key,
    required this.tabService,
    required this.configService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border(
          top: BorderSide(
            color: Colors.lightBlue[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<int?>(
              valueListenable: tabService.currentTabIndexNotifier,
              builder: (context, currentTabIndex, child) {
                final Tab? currentTab = currentTabIndex != null
                    ? tabService.tabs[currentTabIndex]
                    : null;
                return Text(
                  currentTab?.path ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
          ValueListenableBuilder<CursorPosition>(
            valueListenable: tabService.cursorPositionNotifier,
            builder: (context, cursorPosition, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${cursorPosition.line + 1}:${cursorPosition.column + 1}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Tabs: ${configService.config['tabSize'] ?? 4}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
