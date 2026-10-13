import 'package:flutter/material.dart';
import '../../../data/models/category.dart';

/// شرائح الباقات الفرعية
/// تظهر عند اختيار تصنيف رئيسي (مثل رياضة)
/// وتعرض: beIN Sports | AD Sports | Al Kass | SSC | ...
class SubCategoryChips extends StatelessWidget {
  final List<SubCategory> subCategories;
  final String? selectedSlug;
  final ValueChanged<String?> onSelected;

  const SubCategoryChips({
    super.key,
    required this.subCategories,
    required this.selectedSlug,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // إذا لا توجد باقات فرعية، نُخفي الشريط
    if (subCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: subCategories.length + 1, // +1 لزر "الكل"
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          // زر "الكل" في البداية
          if (index == 0) {
            return _SubChip(
              label: 'كل الباقات',
              isSelected: selectedSlug == null,
              onTap: () => onSelected(null),
            );
          }

          final sub = subCategories[index - 1];
          return _SubChip(
            label: sub.name,
            logo: sub.logo,
            count: sub.channelsCount,
            isSelected: selectedSlug == sub.slug,
            onTap: () => onSelected(sub.slug),
          );
        },
      ),
    );
  }
}

/// شريحة واحدة
class _SubChip extends StatefulWidget {
  final String label;
  final String? logo;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.logo,
    this.count,
  });

  @override
  State<_SubChip> createState() => _SubChipState();
}

class _SubChipState extends State<_SubChip> {
  bool _isFocused = false;
  bool _logoError = false;

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
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: _isFocused ? 18 : 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFFFB800)
                : const Color(0xFF1A2238),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : active
                      ? const Color(0xFFFFB800)
                      : const Color(0xFF2A3350),
              width: _isFocused ? 2.5 : 1.5,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFB800).withOpacity(0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : active
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFB800).withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // الشعار أو نقطة ملونة
              if (widget.logo != null &&
                  widget.logo!.isNotEmpty &&
                  !_logoError) ...[
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Image.network(
                    widget.logo!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_logoError) {
                          setState(() => _logoError = true);
                        }
                      });
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ] else ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? Colors.black : const Color(0xFFFFB800),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 8),

              // الاسم
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  color: active ? Colors.black : Colors.white70,
                ),
              ),

              // العدد
              if (widget.count != null && widget.count! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.black.withOpacity(0.2)
                        : const Color(0xFFFFB800).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: active
                          ? Colors.white
                          : const Color(0xFFFFB800),
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
