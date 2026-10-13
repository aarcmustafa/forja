import 'package:flutter/material.dart';
import '../../../data/models/category.dart';

/// شريط التصنيفات الرئيسية - مصمم للتلفاز
/// يعرض: رياضة | أفلام | مسلسلات | أخبار | أطفال | عام
/// يدعم التنقل بالريموت (Focus) + التنقل الأفقي
class CategoryTabs extends StatelessWidget {
  final List<Category> categories;
  final String? selectedSlug;
  final ValueChanged<String?> onSelected;
  final VoidCallback? onAllSelected;
  final bool showAllButton;

  const CategoryTabs({
    super.key,
    required this.categories,
    required this.selectedSlug,
    required this.onSelected,
    this.onAllSelected,
    this.showAllButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: categories.length + (showAllButton ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          // زر "الكل" في البداية
          if (showAllButton && index == 0) {
            return _CategoryTab(
              label: 'الكل',
              icon: Icons.apps_rounded,
              isSelected: selectedSlug == null,
              onTap: () {
                onAllSelected?.call();
                onSelected(null);
              },
            );
          }

          final catIndex = showAllButton ? index - 1 : index;
          final cat = categories[catIndex];

          return _CategoryTab(
            label: cat.name,
            icon: _getIcon(cat.iconName),
            isSelected: selectedSlug == cat.slug,
            channelsCount: cat.channelsCount,
            onTap: () => onSelected(cat.slug),
          );
        },
      ),
    );
  }

  IconData _getIcon(String name) {
    switch (name) {
      case 'sports':
        return Icons.sports_soccer_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'series':
        return Icons.tv_rounded;
      case 'news':
        return Icons.newspaper_rounded;
      case 'kids':
        return Icons.child_care_rounded;
      case 'general':
        return Icons.live_tv_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}

/// تبويب واحد داخل الشريط
class _CategoryTab extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final int? channelsCount;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.channelsCount,
  });

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _isFocused;

    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey.keyLabel == 'Select' ||
              event.logicalKey.keyLabel == 'Enter' ||
              event.logicalKey.keyLabel == 'Space') {
            widget.onTap();
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: _isFocused ? 20 : 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF00C8FF), Color(0xFF0090D4)],
                  )
                : null,
            color: active ? null : const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : active
                      ? const Color(0xFF00C8FF)
                      : const Color(0xFF2A3350),
              width: _isFocused ? 3 : 1.5,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF00C8FF).withOpacity(0.6),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ]
                : active
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00C8FF).withOpacity(0.25),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: active ? Colors.black : Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  color: active ? Colors.black : Colors.white70,
                ),
              ),
              if (widget.channelsCount != null &&
                  widget.channelsCount! > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.black.withOpacity(0.25)
                        : const Color(0xFF00C8FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.channelsCount}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.white : const Color(0xFF00C8FF),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
