import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/channel.dart';
import '../../../data/services/channel_logo_service.dart';

/// بطاقة قناة — تستخدم شعاراً من الإنترنت إذا لم يوجد شعار محلي
class ChannelCard extends StatefulWidget {
  final Channel channel;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const ChannelCard({
    super.key,
    required this.channel,
    this.width = 180,
    this.height = 200,
    this.onTap,
  });

  @override
  State<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<ChannelCard> {
  bool _isFocused = false;
  bool _localLogoFailed = false;

  String? get _logoUrl {
    // 1) جرّب الشعار المحلي أولاً
    if (widget.channel.logo.isNotEmpty && !_localLogoFailed) {
      return widget.channel.logo;
    }
    // 2) إذا فشل، استخدم الإنترنت
    return ChannelLogoService.getLogo(widget.channel.name);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (h) => setState(() => _isFocused = h),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey.keyLabel;
          if (key == 'Select' || key == 'Enter' || key == 'Space') {
            widget.onTap?.call();
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused
                  ? const Color(0xFF00C8FF)
                  : const Color(0xFF2A3350),
              width: _isFocused ? 2.5 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF00C8FF).withOpacity(0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _buildLogo(),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF0A0E1A),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(11),
                  ),
                ),
                child: Text(
                  widget.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isFocused ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight:
                        _isFocused ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final url = _logoUrl;
    if (url == null || url.isEmpty) {
      return _buildPlaceholder();
    }

    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Color(0xFF00C8FF),
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) {
        // إذا فشل الشعار المحلي → جرّب الإنترنت
        if (!_localLogoFailed && widget.channel.logo.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _localLogoFailed = true);
          });
        }
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.live_tv_rounded,
          color: Colors.white24,
          size: 40,
        ),
      ),
    );
  }
}
