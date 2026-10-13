import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// شاشة المشغل — محسّنة للتلفاز مع دعم الريموت
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
  Timer? _retryTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;

  // ====== تحسينات جديدة ======
  double _volume = 100.0;      // الصوت (0-100)
  bool _isMuted = false;
  double _playbackSpeed = 1.0; // سرعة التشغيل
  int _aspectMode = 0;         // 0=contain, 1=cover, 2=fill
  bool _showVolumeBar = false;
  Timer? _volumeBarTimer;

  // ====== إعادة المحاولة ======
  int _retryCount = 0;
  static const int _maxRetries = 3;
  bool _isReconnecting = false;

  final List<double> _speedOptions = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  final List<String> _aspectLabels = const ['ملائم', 'تغطية', 'تعبئة'];

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _retryTimer?.cancel();
    _volumeBarTimer?.cancel();
    player.dispose();
    super.dispose();
  }

  // ==========================================================
  //  التهيئة
  // ==========================================================
  Future<void> _initializePlayer() async {
    try {
      player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 64 * 1024 * 1024,
          logLevel: MPVLogLevel.error,
          protocolWhitelist: [
            'http', 'https', 'hls', 'tcp', 'tls',
            'crypto', 'file', 'udp', 'rtp', 'rtsp', 'rtmp',
          ],
        ),
      );

      controller = VideoController(player);

      // ====== الاستماع للحالات ======
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
        _handleError(error);
      });

      // ====== تشغيل ======
      await _openStream();

      _startHideControlsTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// فتح البث
  Future<void> _openStream() async {
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

    _retryCount = 0;
  }

  /// معالج الأخطاء مع إعادة المحاولة
  void _handleError(String error) {
    if (!mounted) return;

    // إذا كان الخطأ مؤقتاً → حاول مرة أخرى
    if (_retryCount < _maxRetries) {
      _retryCount++;
      setState(() {
        _isReconnecting = true;
        _error = null;
      });

      // انتظر 3 ثواني ثم أعد المحاولة
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 3), () async {
        if (!mounted) return;
        try {
          await _openStream();
          if (mounted) {
            setState(() => _isReconnecting = false);
          }
        } catch (_) {
          if (mounted && _retryCount >= _maxRetries) {
            setState(() {
              _error = error;
              _isLoading = false;
              _isReconnecting = false;
            });
          }
        }
      });
    } else {
      // استنفدت المحاولات
      setState(() {
        _error = error;
        _isLoading = false;
        _isReconnecting = false;
      });
    }
  }

  // ==========================================================
  //  دوال التحكم
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

  void _seekBackward() {
    final newPos = _position - const Duration(seconds: 10);
    player.seek(newPos.isNegative ? Duration.zero : newPos);
    _startHideControlsTimer();
  }

  void _seekForward() {
    final newPos = _position + const Duration(seconds: 10);
    player.seek(newPos > _duration ? _duration : newPos);
    _startHideControlsTimer();
  }

  void _setVolume(double v) {
    setState(() {
      _volume = v;
      _isMuted = v == 0;
    });
    player.setVolume(v);
    _showVolumeIndicator();
  }

  void _toggleMute() {
    if (_isMuted) {
      _setVolume(_volume > 0 ? _volume : 50);
    } else {
      _setVolume(0);
    }
  }

  void _showVolumeIndicator() {
    setState(() => _showVolumeBar = true);
    _volumeBarTimer?.cancel();
    _volumeBarTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showVolumeBar = false);
    });
  }

  void _changeSpeed() {
    // دورة بين الخيارات
    final idx = _speedOptions.indexOf(_playbackSpeed);
    final nextIdx = (idx + 1) % _speedOptions.length;
    final newSpeed = _speedOptions[nextIdx];
    player.setRate(newSpeed);
    setState(() => _playbackSpeed = newSpeed);
    _startHideControlsTimer();
  }

  void _changeAspect() {
    setState(() => _aspectMode = (_aspectMode + 1) % 3);
    _startHideControlsTimer();
  }

  BoxFit _getBoxFit() {
    switch (_aspectMode) {
      case 0:
        return BoxFit.contain;
      case 1:
        return BoxFit.cover;
      case 2:
        return BoxFit.fill;
      default:
        return BoxFit.contain;
    }
  }
}

// ==========================================================
//  BUILD — الواجهة الرئيسية
// ==========================================================
extension _PlayerBuild on _PlayerScreenState {
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

              // تشغيل / إيقاف
              if (key == 'Select' ||
                  key == 'Enter' ||
                  key == 'Media Play Pause') {
                _togglePlayPause();
                return KeyEventResult.handled;
              }
              // رجوع
              if (key == 'Escape' || key == 'Go Back') {
                Navigator.pop(context);
                return KeyEventResult.handled;
              }
              // يمين (تقديم)
              if (key == 'Arrow Right') {
                _seekForward();
                return KeyEventResult.handled;
              }
              // يسار (ترجيع)
              if (key == 'Arrow Left') {
                _seekBackward();
                return KeyEventResult.handled;
              }
              // أعلى (رفع الصوت)
              if (key == 'Arrow Up') {
                _setVolume((_volume + 10).clamp(0, 100));
                return KeyEventResult.handled;
              }
              // أسفل (خفض الصوت)
              if (key == 'Arrow Down') {
                _setVolume((_volume - 10).clamp(0, 100));
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
                      : SizedBox.expand(
                          child: FittedBox(
                            fit: _getBoxFit(),
                            child: SizedBox(
                              width: controller.value.size.width,
                              height: controller.value.size.height,
                              child: Video(
                                controller: controller,
                                controls: NoVideoControls,
                              ),
                            ),
                          ),
                        ),
                ),

                // ============ شاشة التحميل ============
                if (_isLoading && _error == null) _buildLoading(),

                // ============ إشعار إعادة الاتصال ============
                if (_isReconnecting) _buildReconnecting(),

                // ============ التخزين المؤقت ============
                if (_isBuffering && !_isLoading && !_isReconnecting)
                  _buildBuffering(),

                // ============ مؤشر الصوت ============
                if (_showVolumeBar) _buildVolumeOverlay(),

                // ============ أزرار التحكم ============
                if (_showControls && _error == null) ...[
                  _buildTopBar(context),
                  _buildBottomBar(context),
                ],
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
  //  إشعار إعادة الاتصال
  // ==========================================================
  Widget _buildReconnecting() {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withOpacity(0.95),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'جارٍ إعادة الاتصال ($_retryCount/$_maxRetries)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  //  التخزين المؤقت
  // ==========================================================
  Widget _buildBuffering() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withOpacity(0.4),
          child: const Center(
            child: SizedBox(
              width: 55,
              height: 55,
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
  //  مؤشر الصوت (يظهر عند تغيير الصوت)
  // ==========================================================
  Widget _buildVolumeOverlay() {
    return Positioned(
      top: 40,
      left: 40,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isMuted || _volume == 0
                  ? Icons.volume_off_rounded
                  : _volume < 50
                      ? Icons.volume_down_rounded
                      : Icons.volume_up_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 100,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _volume / 100,
                  minHeight: 6,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(
                    Color(0xFF00C8FF),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${_volume.toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
//  الشريط العلوي
// ==========================================================
extension _PlayerTopBar on _PlayerScreenState {
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
            _CircleButton(
              icon: Icons.arrow_back,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 20),

            // شعار القناة
            if (widget.channelLogo != null &&
                widget.channelLogo!.isNotEmpty)
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
            if (widget.channelLogo != null &&
                widget.channelLogo!.isNotEmpty)
              const SizedBox(width: 14),

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

            // سرعة التشغيل
            if (_playbackSpeed != 1.0)
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C8FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_playbackSpeed}x',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // مؤشر LIVE
            Container(
              margin: const EdgeInsets.only(left: 12),
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
}

// ==========================================================
//  الشريط السفلي
// ==========================================================
extension _PlayerBottomBar on _PlayerScreenState {
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
            _buildProgressBar(),
            const SizedBox(height: 18),
            _buildControlRow(),
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
        Text(
          _formatDuration(_position),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 12),
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
  //  أزرار التحكم
  // ==========================================================
  Widget _buildControlRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // صوت
        _CircleButton(
          icon: _isMuted || _volume == 0
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
          size: 40,
          onPressed: _toggleMute,
        ),
        const SizedBox(width: 18),

        // ترجيع 10
        _CircleButton(
          icon: Icons.replay_10,
          size: 40,
          onPressed: _seekBackward,
        ),
        const SizedBox(width: 18),

        // تشغيل/إيقاف
        _CircleButton(
          icon: _isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          size: 56,
          filled: true,
          onPressed: _togglePlayPause,
        ),
        const SizedBox(width: 18),

        // تقديم 10
        _CircleButton(
          icon: Icons.forward_10,
          size: 40,
          onPressed: _seekForward,
        ),
        const SizedBox(width: 18),

        // سرعة
        _CircleButton(
          icon: Icons.speed_rounded,
          size: 40,
          onPressed: _changeSpeed,
        ),
        const SizedBox(width: 18),

        // أبعاد
        _CircleButton(
          icon: Icons.aspect_ratio_rounded,
          size: 40,
          onPressed: _changeAspect,
        ),
      ],
    );
  }
}

// ==========================================================
//  أدوات مساعدة
// ==========================================================
extension _PlayerHelpers on _PlayerScreenState {
  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes.toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
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
                      _retryCount = 0;
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

// ==========================================================
//  زر دائري
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
