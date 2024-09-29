import 'package:flutter/material.dart';

const double kCompletionItemHeight = 24.0;
const int kMaxVisibleItems = 6;

class CompletionItem {
  final String label;
  final String? detail;
  final String? insertText;

  CompletionItem({required this.label, this.detail, this.insertText});

  factory CompletionItem.fromJson(Map<String, dynamic> json) {
    return CompletionItem(
      label: json['label'] as String,
      detail: json['detail'] as String?,
      insertText: json['insertText'] as String? ?? json['label'] as String,
    );
  }
}

class CompletionsWidget extends StatelessWidget {
  final List<CompletionItem> completions;
  final Function(CompletionItem) onSelected;
  final Offset position;
  final int selectedIndex;
  final ScrollController scrollController;

  const CompletionsWidget({
    Key? key,
    required this.completions,
    required this.onSelected,
    required this.position,
    required this.selectedIndex,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final itemCount = completions.length;
    final height = (itemCount * kCompletionItemHeight).clamp(
      kCompletionItemHeight,
      kMaxVisibleItems * kCompletionItemHeight,
    );

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: height,
            maxWidth: 300,
            minWidth: 200,
          ),
          child: ListView.builder(
            controller: scrollController,
            itemCount: itemCount,
            itemExtent: kCompletionItemHeight,
            itemBuilder: (context, index) {
              final completion = completions[index];
              final isSelected = index == selectedIndex;
              return SizedBox(
                height: kCompletionItemHeight,
                child: InkWell(
                  onTap: () => onSelected(completion),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            completion.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (completion.detail != null)
                          Flexible(
                            child: Text(
                              completion.detail!,
                              style: TextStyle(
                                color: (isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface)
                                    .withOpacity(0.7),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
