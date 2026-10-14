import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/local/playback_position_service.dart';

/// شاشة المشغل — Retry + Redirects + Resume Position
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
  Timer? _volumeBarTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;

  double _volume = 100.0;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  int _aspectMode = 0;
  bool _showVolumeBar = false;

  int _retryCount = 0;
  static const int _maxRetries = 5;
  bool _isReconnecting = false;
  DateTime? _lastErrorTime;

  final PlaybackPositionService _positionService = PlaybackPositionService();
  DateTime _lastPositionSave = DateTime.now();
  bool _hasRestoredPosition = false;

  final List<double> _speedOptions = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _saveCurrentPosition();
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
          bufferSize: 96 * 1024 * 1024,
          logLevel: MPVLogLevel.error,
          protocolWhitelist: [
            'http', 'https', 'hls', 'm3u8',
            'mpegts', 'ts', 'dash', 'mpd',
            'rtsp', 'rtsps', 'rtmp', 'rtmps', 'rtmpt', 'rtmpe',
            'udp', 'rtp', 'mms', 'mmsh', 'mmst',
            'tcp', 'tls', 'crypto', 'file', 'concat', 'data',
            'srt', 'rist',
          ],
        ),
      );

      controller = VideoController(player);

      // ✅ ضبط خصائص mpv (Redirects + Reconnect + Headers)
      await _configurePlayerProperties();

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

        final now = DateTime.now();
        if (now.difference(_lastPositionSave).inSeconds >= 10) {
          _lastPositionSave = now;
          _saveCurrentPosition();
        }
      });

      player.stream.duration.listen((dur) {
        if (!mounted) return;
        setState(() => _duration = dur);
      });

      player.stream.error.listen((error) {
        if (!mounted) return;
        _handleError(error);
      });

      await _openStream();
      _startHideControlsTimer();
      await _restoreSavedPosition();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ==========================================================
  //  ضبط خصائص mpv لحل مشاكل التحويلات والاتصال
  // ==========================================================
  Future<void> _configurePlayerProperties() async {
    // ✅ 1) متابعة التحويلات عبر البروتوكولات (HTTP ↔ HTTPS)
    try {
      await player.setProperty('stream-lavf-o', 'reconnect=1,reconnect_at_eof=1,reconnect_streamed=1,reconnect_delay_max=5,timeout=30');
    } catch (_) {}

    // ✅ 2) User-Agent (VLC مقبول من كل السيرفرات)
    try {
      await player.setProperty('user-agent', 'VLC/3.0.20 LibVLC/3.0.20');
    } catch (_) {}

    // ✅ 3) HTTP Headers
    try {
      await player.setProperty(
        'http-header-fields',
        'Accept: */*,Connection: keep-alive,Icy-MetaData: 1',
      );
    } catch (_) {}

    // ✅ 4) مهلة الشبكة
    try {
      await player.setProperty('network-timeout', '30');
    } catch (_) {}

    // ✅ 5) تحسينات البث المباشر
    try {
      await player.setProperty('cache', 'yes');
      await player.setProperty('cache-pause', 'no');
      await player.setProperty('cache-pause-initial', 'no');
    } catch (_) {}
  }

  // ==========================================================
  //  فتح البث
  // ==========================================================
  Future<void> _openStream() async {
    final headers = _buildHeaders(widget.streamUrl);

    await player.open(
      Media(
        widget.streamUrl,
        httpHeaders: headers,
      ),
      play: true,
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  Map<String, String> _buildHeaders(String url) {
    final headers = <String, String>{
      'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20',
      'Accept': '*/*',
      'Connection': 'keep-alive',
      'Icy-MetaData': '1',
    };

    try {
      final uri = Uri.parse(url);
      final origin = '${uri.scheme}://${uri.host}';
      headers['Referer'] = '$origin/';
      headers['Origin'] = origin;
    } catch (_) {}

    return headers;
  }

  // ==========================================================
  //  إعادة المحاولة مع Exponential Backoff
  // ==========================================================
  void _handleError(String error) {
    if (!mounted) return;

    final now = DateTime.now();
    if (_lastErrorTime != null &&
        now.difference(_lastErrorTime!).inSeconds > 30) {
      _retryCount = 0;
    }
    _lastErrorTime = now;

    if (_retryCount < _maxRetries) {
      _retryCount++;

      setState(() {
        _isReconnecting = true;
        _error = null;
      });

      final delayMs = 300 * _retryCount;

      _retryTimer?.cancel();
      _retryTimer = Timer(Duration(milliseconds: delayMs), () async {
        if (!mounted) return;
        try {
          final savedPos = _position;
          await _openStream();

          if (savedPos > Duration.zero && _duration > Duration.zero) {
            await player.seek(savedPos);
          }

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
    if (mounted && _showControls) setState(() => _showControls = false);
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

String _formatDuration(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }
  return '${d.inMinutes.toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

// ==========================================================
//  حفظ/استئناف الموضع
// ==========================================================
Future<void> _saveCurrentPosition() async {
  try {
    if (_duration == Duration.zero) return;
    if (_position < const Duration(seconds: 30)) return;

    await _positionService.save(
      itemId: widget.streamUrl,
      position: _position,
      duration: _duration,
    );
  } catch (_) {}
}

Future<void> _restoreSavedPosition() async {
  if (_hasRestoredPosition) return;
  _hasRestoredPosition = true;

  try {
    final saved = await _positionService.load(widget.streamUrl);
    if (saved == null) return;
    if (saved < const Duration(seconds: 30)) return;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    await player.seek(saved);
  } catch (_) {}
}

// ==========================================================
//  BUILD
// ==========================================================
@override
Widget build(BuildContext context) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final key = event.logicalKey.keyLabel;
            if (key == 'Select' || key == 'Enter' ||
                key == 'Media Play Pause') {
              _togglePlayPause();
              return KeyEventResult.handled;
            }
            if (key == 'Escape' || key == 'Go Back') {
              Navigator.pop(context);
              return KeyEventResult.handled;
            }
            if (key == 'Arrow Right') {
              _seekForward();
              return KeyEventResult.handled;
            }
            if (key == 'Arrow Left') {
              _seekBackward();
              return KeyEventResult.handled;
            }
            if (key == 'Arrow Up') {
              _setVolume((_volume + 10).clamp(0, 100));
              return KeyEventResult.handled;
            }
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
              Center(
                child: _error != null
                    ? _buildError()
                    : SizedBox.expand(
                        child: FittedBox(
                          fit: _getBoxFit(),
                          child: SizedBox(
                            width: (player.state.width ?? 1920).toDouble(),
                            height:
                                (player.state.height ?? 1080).toDouble(),
                            child: Video(
                              controller: controller,
                              controls: NoVideoControls,
                            ),
                          ),
                        ),
                      ),
              ),
              if (_isLoading && _error == null) _buildLoading(),
              if (_isReconnecting) _buildReconnecting(),
              if (_isBuffering && !_isLoading && !_isReconnecting)
                _buildBuffering(),
              if (_showVolumeBar) _buildVolumeOverlay(),
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

Widget _buildReconnecting() {
  return Positioned(
    top: 100,
    left: 0,
    right: 0,
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9800).withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
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
              'إعادة الاتصال ($_retryCount/$_maxRetries)',
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
