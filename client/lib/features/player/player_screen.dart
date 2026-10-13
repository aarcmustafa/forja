import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// شاشة مشغل الفيديو - مصممة للتلفاز مع دعم الريموت
class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String channelName;
  final String? channelLogo;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.channelName,
    this.channelLogo,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player;
  late final VideoController controller;

  bool _isLoading = true;
  bool _showControls = true;
  String? _error;
  Timer? _hideControlsTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // ==========================================================
      //  إعدادات المشغل - محسّنة للبث المباشر IPTV
      // ==========================================================
      player = Player(
        configuration: const PlayerConfiguration(
          // حجم التخزين المؤقت: 64MB لاستقرار البث
          bufferSize: 64 * 1024 * 1024,
          // تجاهل الرسائل المزعجة
          logLevel: MPVLogLevel.error,
          // بروتوكولات مسموحة
          protocolWhitelist: [
            'http',
            'https',
            'hls',
            'tcp',
            'tls',
            'crypto',
            'file',
            'udp',
            'rtp',
            'rtsp',
            'rtmp',
          ],
        ),
      );

      controller = VideoController(player);

      // ============ الاستماع لحالة التشغيل ============
      player.stream.playing.listen((playing) {
        if (!mounted) return;
        setState(() => _isPlaying = playing);
      });

      player.stream.buffering.listen((buffering) {
        if (!mounted) return;
        setState(() {
          _isBuffering = buffering;
          if (!buffering) _isLoading = false;
        });
      });

      player.stream.position.listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
      });

      player.stream.duration.listen((dur) {
        if (!mounted) return;
        setState(() => _duration = dur);
      });

      player.stream.error.listen((error) {
        if (!mounted) return;
        setState(() {
          _error = error;
          _isLoading = false;
        });
      });

      // ============ تشغيل الرابط ============
      await player.open(
        Media(widget.streamUrl),
        play: true,
      );

      // إخفاء شاشة التحميل بعد 3 ثوانٍ كحد أقصى
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
        }
      });

      // تشغيل مؤقت إخفاء أزرار التحكم
      _startHideControlsTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    player.dispose();
    super.dispose();
  }

  // ==========================================================
  //  إدارة أزرار التحكم
  // ==========================================================
  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideControlsTimer();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      player.pause();
    } else {
      player.play();
    }
    _startHideControlsTimer();
  }
}

extension _PlayerScreenBuild on _PlayerScreenState {
  // ==========================================================
  //  الواجهة
  // ==========================================================
  Widget buildPlayer(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              final key = event.logicalKey.keyLabel;
              // زر الترجيع/الإيقاف
              if (key == 'Select' || key == 'Enter' || key == 'Media Play Pause') {
                _togglePlayPause();
                return KeyEventResult.handled;
              }
              // زر الرجوع
              if (key == 'Escape' || key == 'Go Back') {
                Navigator.pop(context);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              children: [
                // ============ الفيديو ============
                Center(
                  child: _error != null
                      ? _buildError()
                      : Video(
                          controller: controller,
                          controls: NoVideoControls,
                        ),
                ),

                // ============ شاشة التحميل ============
                if (_isLoading) _buildLoading(),

                // ============ شاشة التخزين المؤقت ============
                if (_isBuffering && !_isLoading) _buildBuffering(),

                // ============ أزرار التحكم العلوية ============
                if (_showControls) _buildTopBar(context),

                // ============ أزرار التحكم السفلية ============
                if (_showControls) _buildBottomBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  //  شاشة التحميل
  // ==========================================================
  Widget _buildLoading() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                color: Color(0xFF00C8FF),
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'جارٍ التحميل...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: Text(
                widget.channelName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  //  شاشة التخزين المؤقت
  // ==========================================================
  Widget _buildBuffering() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: const Center(
            child: SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                color: Color(0xFF00C8FF),
                strokeWidth: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  //  شاشة الخطأ
  // ==========================================================
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFFF5252),
              size: 80,
            ),
            const SizedBox(height: 20),
            const Text(
              'تعذر تشغيل القناة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _error ?? 'خطأ غير معروف',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _initializePlayer();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C8FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text(
                    'إغلاق',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension _PlayerScreenWidgets on _PlayerScreenState {
  // ==========================================================
  //  الشريط العلوي
  // ==========================================================
  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.85),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            // زر الإغلاق
            _CircleButton(
              icon: Icons.arrow_back,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 20),

            // شعار القناة (اختياري)
            if (widget.channelLogo != null && widget.channelLogo!.isNotEmpty)
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.network(
                  widget.channelLogo!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (widget.channelLogo != null && widget.channelLogo!.isNotEmpty)
              const SizedBox(width: 14),

            // اسم القناة
            Expanded(
              child: Text(
                widget.channelName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // مؤشر LIVE
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFF1744),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'مباشر',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  //  الشريط السفلي - أزرار التحكم
  // ==========================================================
  Widget _buildBottomBar(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.85),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // شريط التقدم
            _buildProgressBar(),
            const SizedBox(height: 16),

            // أزرار التحكم
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ترجيع 10 ثوان
                _CircleButton(
                  icon: Icons.replay_10,
                  size: 32,
                  onPressed: () {
                    final newPos =
                        _position - const Duration(seconds: 10);
                    player.seek(newPos.isNegative ? Duration.zero : newPos);
                    _startHideControlsTimer();
                  },
                ),
                const SizedBox(width: 20),

                // تشغيل/إيقاف
                _CircleButton(
                  icon: _isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 44,
                  filled: true,
                  onPressed: _togglePlayPause,
                ),
                const SizedBox(width: 20),

                // تقدم 10 ثوان
                _CircleButton(
                  icon: Icons.forward_10,
                  size: 32,
                  onPressed: () {
                    final newPos =
                        _position + const Duration(seconds: 10);
                    player.seek(
                      newPos > _duration ? _duration : newPos,
                    );
                    _startHideControlsTimer();
                  },
                ),
                const SizedBox(width: 30),

                // زر كتم الصوت
                _CircleButton(
                  icon: Icons.volume_up_rounded,
                  size: 28,
                  onPressed: () {
                    // TODO: كتم/تشغيل الصوت
                    _startHideControlsTimer();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  //  شريط التقدم
  // ==========================================================
  Widget _buildProgressBar() {
    final total = _duration.inMilliseconds.toDouble();
    final current = _position.inMilliseconds.toDouble();
    final max = total > 0 ? total : 1.0;
    final value = current.clamp(0.0, max);

    return Row(
      children: [
        // الوقت الحالي
        Text(
          _formatDuration(_position),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 12),

        // شريط التقدم
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: const Color(0xFF00C8FF),
              inactiveTrackColor: Colors.white24,
              thumbColor: const Color(0xFF00C8FF),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 16),
              overlayColor: const Color(0xFF00C8FF).withOpacity(0.2),
            ),
            child: Slider(
              value: value,
              max: max,
              onChanged: (v) {
                player.seek(Duration(milliseconds: v.toInt()));
                _startHideControlsTimer();
              },
            ),
          ),
        ),
        const SizedBox(width: 12),

        // المدة الكلية
        Text(
          _formatDuration(_duration),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  //  تنسيق الوقت
  // ==========================================================
  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes.toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }
}

// ==========================================================
//  زر دائري قابل للتركيز
// ==========================================================
class _CircleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final bool filled;

  const _CircleButton({
    required this.icon,
    required this.onPressed,
    this.size = 48,
    this.filled = false,
  });

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey.keyLabel;
          if (key == 'Select' ||
              key == 'Enter' ||
              key == 'Media Play Pause') {
            widget.onPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.filled
                ? const Color(0xFF00C8FF)
                : _isFocused
                    ? const Color(0xFF00C8FF)
                    : Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : Colors.white.withOpacity(0.2),
              width: _isFocused ? 3 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF00C8FF).withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Icon(
            widget.icon,
            color: widget.filled || _isFocused
                ? Colors.black
                : Colors.white,
            size: widget.size * 0.5,
          ),
        ),
      ),
    );
  }
}
