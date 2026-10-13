import 'package:flutter/material.dart';
import '../../../data/models/channel.dart';

/// بطاقة عرض القناة - مصممة خصيصاً للتلفاز
/// تدعم:
/// - التكبير عند Focus (الريموت)
/// - عرض الشعار
/// - اسم القناة والباقة
/// - حالات التحميل والخطأ
class ChannelCard extends StatefulWidget {
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
  State<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<ChannelCard> {
  bool _isFocused = false;
  bool _imageError = false;

  @override
  Widget build(BuildContext context) {
    // إما isFocused من الأب أو حالتنا الداخلية
    final focused = widget.isFocused || _isFocused;

    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
      },
      onKeyEvent: (node, event) {
        // دعم زر Enter/OK على الريموت
        if (event is KeyDownEvent) {
          // ignore: avoid_print
          if (event.logicalKey.keyLabel == 'Select' ||
              event.logicalKey.keyLabel == 'Enter' ||
              event.logicalKey.keyLabel == 'Space') {
            widget.onTap?.call();
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: focused ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFF141A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: focused
                    ? const Color(0xFF00C8FF)
                    : const Color(0xFF2A3350),
                width: focused ? 3 : 1,
              ),
              boxShadow: focused
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00C8FF).withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
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
                      child: _buildLogo(focused),
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
                              color: focused ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: focused
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
                                color: Colors.white.withOpacity(0.4),
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

  Widget _buildLogo(bool focused) {
    if (widget.channel.logo.isEmpty || _imageError) {
      // أيقونة بديلة عند عدم وجود شعار
      return Center(
        child: Icon(
          _getCategoryIcon(),
          size: focused ? 50 : 44,
          color: focused
              ? const Color(0xFF00C8FF)
              : Colors.white.withOpacity(0.3),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Image.network(
        widget.channel.logo,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          // عند فشل تحميل الصورة
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
                  : Colors.white.withOpacity(0.3),
            ),
          );
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
                  focused ? const Color(0xFF00C8FF) : Colors.white30,
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
