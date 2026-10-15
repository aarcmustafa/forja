import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/channel.dart';
import '../../../data/providers/tv_focus_provider.dart';

/// بطاقة عرض القناة — مع شعار تلقائي ملوّن + إضاءة دائمة
class ChannelCard extends ConsumerStatefulWidget {
  final Channel channel;
  final VoidCallback? onTap;
  final bool isFocused;
  final double width;
  final double height;

  const ChannelCard({
    super.key,
    required this.channel,
    this.onTap,
    this.isFocused = false,
    this.width = 180,
    this.height = 180,
  });

  @override
  ConsumerState<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends ConsumerState<ChannelCard> {
  bool _isFocused = false;
  bool _imageError = false;

  void _setAsSelected() {
    setSelectedItem(ref, widget.channel.id);
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.isFocused || _isFocused;
    final isSelected = isItemSelected(ref, widget.channel.id);

    Color borderColor;
    double borderWidth;
    List<BoxShadow> shadows;
    double scale;

    if (focused) {
      borderColor = const Color(0xFF00C8FF);
      borderWidth = 3;
      scale = 1.08;
      shadows = [
        BoxShadow(
          color: const Color(0xFF00C8FF).withOpacity(0.7),
          blurRadius: 24,
          spreadRadius: 3,
        ),
        BoxShadow(
          color: const Color(0xFF00C8FF).withOpacity(0.3),
          blurRadius: 40,
          spreadRadius: 6,
        ),
      ];
    } else if (isSelected) {
      borderColor = const Color(0xFF00C8FF);
      borderWidth = 2;
      scale = 1.0;
      shadows = [
        BoxShadow(
          color: const Color(0xFF00C8FF).withOpacity(0.4),
          blurRadius: 16,
          spreadRadius: 1,
        ),
      ];
    } else {
      borderColor = const Color(0xFF2A3350);
      borderWidth = 1;
      scale = 1.0;
      shadows = [];
    }

    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
        if (hasFocus) _setAsSelected();
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey.keyLabel;
          if (key == 'Select' ||
              key == 'Enter' ||
              key == 'Space') {
            _setAsSelected();
            widget.onTap?.call();
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          _setAsSelected();
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFF141A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
              boxShadow: shadows,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Column(
                children: [
                  // ====== الشعار ======
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      color: Colors.black26,
                      child: _buildLogo(focused, isSelected),
                    ),
                  ),

                  // ====== اسم القناة ======
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.channel.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: focused
                                  ? Colors.white
                                  : isSelected
                                      ? Colors.white
                                      : Colors.white70,
                              fontSize: 12,
                              fontWeight: focused || isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (widget.channel.group.isNotEmpty)
                            Text(
                              widget.channel.group,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(
                                  focused || isSelected ? 0.6 : 0.4,
                                ),
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  //  الشعار — مع fallback تلقائي
  // ==========================================================
  Widget _buildLogo(bool focused, bool isSelected) {
    // إذا كان هناك رابط شعار
    if (widget.channel.logo.isNotEmpty && !_imageError) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Image.network(
          widget.channel.logo,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_imageError) {
                setState(() => _imageError = true);
              }
            });
            return _buildAutoLogo(focused, isSelected);
          },
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    focused || isSelected
                        ? const Color(0xFF00C8FF)
                        : Colors.white30,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // ✅ شعار تلقائي ملوّن
    return _buildAutoLogo(focused, isSelected);
  }

  // ==========================================================
  //  شعار تلقائي ملوّن بناءً على اسم القناة
  // ==========================================================
  Widget _buildAutoLogo(bool focused, bool isSelected) {
    final initials = _getInitials(widget.channel.name);
    final color = _getColorFromName(widget.channel.name);
    final icon = _getCategoryIcon();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(focused ? 0.5 : 0.35),
                color.withOpacity(focused ? 0.2 : 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(focused ? 0.8 : 0.4),
              width: focused ? 2 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: focused ? 42 : 36,
                color: color.withOpacity(focused ? 1.0 : 0.8),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  initials,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(focused ? 0.95 : 0.8),
                    fontSize: focused ? 13 : 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  //  استخراج الأحرف الأولى
  // ==========================================================
  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return '?';

    if (words.length == 1) {
      final w = words[0];
      if (w.length <= 3) return w;
      return w.substring(0, 3);
    }

    if (words.length == 2) {
      return '${words[0][0]}${words[1][0]}';
    }

    return '${words[0][0]}${words[1][0]}';
  }

  // ==========================================================
  //  توليد لون فريد من اسم القناة
  // ==========================================================
  Color _getColorFromName(String name) {
    const colors = [
      Color(0xFF00C8FF),
      Color(0xFF4CAF50),
      Color(0xFFFFB800),
      Color(0xFFE91E63),
      Color(0xFF9C27B0),
      Color(0xFF00BCD4),
      Color(0xFFFF5722),
      Color(0xFF795548),
      Color(0xFF2196F3),
      Color(0xFF8BC34A),
      Color(0xFFF44336),
      Color(0xFF3F51B5),
      Color(0xFF009688),
      Color(0xFFFF9800),
      Color(0xFF673AB7),
    ];

    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }

    final index = hash.abs() % colors.length;
    return colors[index];
  }
  
  IconData _getCategoryIcon() {
    switch (widget.channel.category.toLowerCase()) {
      case 'sport':
        return Icons.sports_soccer_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'series':
        return Icons.tv_rounded;
      case 'news':
        return Icons.newspaper_rounded;
      case 'kids':
        return Icons.child_care_rounded;
      default:
        return Icons.live_tv_rounded;
    }
  }
}
