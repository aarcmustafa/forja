import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../data/models/channel.dart';
import '../../../data/providers/tv_focus_provider.dart';

/// بطاقة عرض القناة — مصممة للتلفاز
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

    // الألوان حسب الحالة
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
          if (key == 'Select' || key == 'Enter' || key == 'Space') {
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
  //  الشعار مع Cached Network Image
  // ==========================================================
  Widget _buildLogo(bool focused, bool isSelected) {
    if (widget.channel.logo.isEmpty || _imageError) {
      return Center(
        child: Icon(
          _getCategoryIcon(),
          size: focused ? 50 : 44,
          color: focused
              ? const Color(0xFF00C8FF)
              : isSelected
                  ? const Color(0xFF00C8FF).withOpacity(0.7)
                  : Colors.white.withOpacity(0.3),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: CachedNetworkImage(
        imageUrl: widget.channel.logo,
        fit: BoxFit.contain,
        // ✅ Cache: أسرع 10x من Image.network
        memCacheWidth: 200,
        memCacheHeight: 200,
        // ====== عند الخطأ ======
        errorWidget: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_imageError) {
              setState(() => _imageError = true);
            }
          });
          return Center(
            child: Icon(
              _getCategoryIcon(),
              size: focused ? 50 : 44,
              color: focused
                  ? const Color(0xFF00C8FF)
                  : isSelected
                      ? const Color(0xFF00C8FF).withOpacity(0.7)
                      : Colors.white.withOpacity(0.3),
            ),
          );
        },
        // ====== عند التحميل ======
        placeholder: (_, __) {
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
