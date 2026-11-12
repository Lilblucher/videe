import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Underline tab row: active tab is #f3f4f6 text with a 2px accent
/// underline; inactive tabs are dim text with no underline. No pills,
/// no segmented controls.
class UnderlineTabs extends StatelessWidget {
  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final double gap;

  const UnderlineTabs({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
    this.gap = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 2,
                    color: i == activeIndex
                        ? AppColors.accent
                        : Colors.transparent,
                  ),
                ),
              ),
              child: Text(
                labels[i],
                style: AppText.sans(
                  size: 14,
                  weight: FontWeight.w500,
                  color: i == activeIndex ? AppColors.text : AppColors.textDim,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
