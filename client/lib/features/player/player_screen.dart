import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/providers/playlist_provider.dart';

/// شاشة المشغل — دائرة تحميل فقط حتى تظهر القناة
/// - إعادة محاولة صامتة (بدون إشعارات)
/// - علّم القناة كـ ميتة بعد 3 محاولات فاشلة
class PlayerScreen extends ConsumerStatefulWidget {
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
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final Player player;
  late final VideoController controller;

  bool _isLoading = true;
  bool _showControls = true;
  bool _firstFrameReady = false;
  String? _error;
  Timer? _hideControlsTimer;
  Timer? _retryTimer;
  Timer? _volumeBarTimer;
  Timer? _maxLoadTimer;

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
  static const int _maxRetries = 3;
  bool _markedDead = false;

  List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack? _currentSubtitleTrack;

  final List<double> _speedOptions = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

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
    _maxLoadTimer?.cancel();
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

      // playing → إخفاء الدائرة عند التشغيل الفعلي
      player.stream.playing.listen((playing) {
        if (!mounted) return;
        setState(() {
          _isPlaying = playing;
          if (playing) {
            _firstFrameReady = true;
            _isLoading = false;
          }
        });
      });

      player.stream.buffering.listen((buffering) {
        if (!mounted) return;
        setState(() {
          _isBuffering = buffering;
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

      // الأخطاء → إعادة محاولة صامتة
      player.stream.error.listen((error) {
        if (!mounted) return;
        _handleErrorSilently(error);
      });

      player.stream.tracks.listen((tracks) {
        if (!mounted) return;
        setState(() => _subtitleTracks = tracks.subtitle);
      });

      player.stream.track.listen((track) {
        if (!mounted) return;
        setState(() => _currentSubtitleTrack = track.subtitle);
      });

      await _openStream();
      _startHideControlsTimer();

      // مهلة قصوى: إذا لم تفتح القناة خلال 25 ثانية → خطأ
      _maxLoadTimer = Timer(const Duration(seconds: 25), () {
        if (mounted && _isLoading && !_firstFrameReady && !_markedDead) {
          _handleErrorSilently('Timeout');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openStream() async {
    final headers = _buildHeaders(widget.streamUrl);
    await player.open(
      Media(widget.streamUrl, httpHeaders: headers),
      play: true,
    );
    _retryCount = 0;
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
  //  إعادة محاولة صامتة (بدون إشعار)
  // ==========================================================
  Future<void> _handleErrorSilently(String error) async {
    if (!mounted) return;
    if (_firstFrameReady) return; // بعد التشغيل، تجاهل
    if (_markedDead) return;

    if (_retryCount < _maxRetries) {
      _retryCount++;
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 2), () async {
        if (!mounted) return;
        try {
          await _openStream();
        } catch (_) {
          if (_retryCount >= _maxRetries) {
            await _markDeadAndShowError();
          }
        }
      });
    } else {
      await _markDeadAndShowError();
    }
  }

  /// ✅ علّم القناة كـ ميتة + أظهر الخطأ
  Future<void> _markDeadAndShowError() async {
    if (_markedDead) return;
    _markedDead = true;

    // علّمها كـ ميتة في playlist_provider
    try {
      final playlist = ref.read(playlistProvider.notifier);
      await playlist.markDeadByUrl(widget.streamUrl);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _error = 'تعذر تشغيل القناة';
      _isLoading = false;
    });
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
      case 0: return BoxFit.contain;
      case 1: return BoxFit.cover;
      case 2: return BoxFit.fill;
      default: return BoxFit.contain;
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes.toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }
  
// ==========================================================
//  قائمة الترجمة
// ==========================================================
void _showSubtitleSheet() {
  _hideControlsTimer?.cancel();
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF141A2E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            constraints: const BoxConstraints(maxHeight: 500),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.subtitles_rounded,
                        color: Color(0xFF00C8FF), size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      'الترجمة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C8FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _subtitleTracks.isEmpty
                            ? 'لا توجد'
                            : '${_subtitleTracks.length} خيارات',
                        style: const TextStyle(
                          color: Color(0xFF00C8FF),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _subtitleOption(
                          label: 'بلا ترجمة',
                          isSelected: _currentSubtitleTrack == null ||
                              _currentSubtitleTrack!.id == 'no',
                          onTap: () async {
                            await player
                                .setSubtitleTrack(SubtitleTrack.no());
                            setSheetState(() {});
                            _startHideControlsTimer();
                          },
                        ),
                        if (_subtitleTracks.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(color: Color(0xFF2A3350)),
                          const SizedBox(height: 10),
                          ..._subtitleTracks.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final track = entry.value;
                            final isSelected =
                                _currentSubtitleTrack?.id == track.id;
                            return _subtitleOption(
                              label: _subtitleTrackLabel(track, idx),
                              isSelected: isSelected,
                              onTap: () async {
                                await player.setSubtitleTrack(track);
                                setSheetState(() {});
                                _startHideControlsTimer();
                              },
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  ).then((_) {
    if (mounted) _startHideControlsTimer();
  });
}

Widget _subtitleOption({
  required String label,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Material(
      color: isSelected
          ? const Color(0xFF00C8FF).withOpacity(0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00C8FF)
                  : const Color(0xFF2A3350),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? const Color(0xFF00C8FF)
                    : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _subtitleTrackLabel(SubtitleTrack track, int index) {
  final lang = track.language ?? '';
  String? langName;
  if (lang.startsWith('ar')) langName = 'عربي';
  else if (lang.startsWith('en')) langName = 'إنجليزي';
  else if (lang.startsWith('fr')) langName = 'فرنسي';
  else if (lang.startsWith('es')) langName = 'إسباني';
  else if (lang.startsWith('de')) langName = 'ألماني';
  else if (lang.startsWith('tr')) langName = 'تركي';
  else if (lang.startsWith('hi')) langName = 'هندي';

  if (track.title != null && track.title!.isNotEmpty) {
    return track.title! + (langName != null ? ' ($langName)' : '');
  }
  if (langName != null) return langName;
  if (lang.isNotEmpty) return lang.toUpperCase();
  return 'ترجمة ${index + 1}';
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
            if (key == 'Select' ||
                key == 'Enter' ||
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
              // الفيديو
              Center(
                child: _error != null
                    ? _buildError()
                    : SizedBox.expand(
                        child: FittedBox(
                          fit: _getBoxFit(),
                          child: SizedBox(
                            width:
                                (player.state.width ?? 1920).toDouble(),
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

              // دائرة التحميل (تبقى حتى تشغيل القناة)
              if (_isLoading && _error == null) _buildLoading(),

              // Buffering (فقط بعد أول إطار)
              if (_isBuffering &&
                  !_isLoading &&
                  _firstFrameReady &&
                  _error == null)
                _buildBufferingIndicator(),

              // مؤشر الصوت
              if (_showVolumeBar) _buildVolumeOverlay(),

              // أزرار التحكم
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
    color: Colors.black.withOpacity(0.9),
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

Widget _buildBufferingIndicator() {
  return Positioned.fill(
    child: IgnorePointer(
      child: Container(
        color: Colors.black.withOpacity(0.3),
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

Widget _buildVolumeOverlay() {
  return Positioned(
    top: 40,
    left: 40,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF00C8FF)),
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
            colors: [Colors.black.withOpacity(0.85), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            _CircleButton(
              icon: Icons.arrow_back,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 20),
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
            if (_playbackSpeed != 1.0)
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
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
            Container(
              margin: const EdgeInsets.only(left: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            colors: [Colors.black.withOpacity(0.85), Colors.transparent],
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

  Widget _buildControlRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleButton(
          icon: _isMuted || _volume == 0
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
          size: 40,
          onPressed: _toggleMute,
        ),
        const SizedBox(width: 18),
        _CircleButton(
          icon: Icons.replay_10,
          size: 40,
          onPressed: _seekBackward,
        ),
        const SizedBox(width: 18),
        _CircleButton(
          icon: _isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          size: 56,
          filled: true,
          onPressed: _togglePlayPause,
        ),
        const SizedBox(width: 18),
        _CircleButton(
          icon: Icons.forward_10,
          size: 40,
          onPressed: _seekForward,
        ),
        const SizedBox(width: 18),
        _CircleButton(
          icon: Icons.speed_rounded,
          size: 40,
          onPressed: _changeSpeed,
        ),
        const SizedBox(width: 18),
        _CircleButton(
          icon: Icons.aspect_ratio_rounded,
          size: 40,
          onPressed: _changeAspect,
        ),
        const SizedBox(width: 18),
        _CircleButton(
          icon: Icons.subtitles_rounded,
          size: 40,
          onPressed: _showSubtitleSheet,
          hasBadge: _subtitleTracks.isNotEmpty,
        ),
      ],
    );
  }

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
                      _markedDead = false;
                      _firstFrameReady = false;
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
//  زر دائري قابل للتركيز
// ==========================================================
class _CircleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final bool filled;
  final bool hasBadge;

  const _CircleButton({
    required this.icon,
    required this.onPressed,
    this.size = 48,
    this.filled = false,
    this.hasBadge = false,
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
        child: Stack(
          children: [
            AnimatedContainer(
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
            if (widget.hasBadge)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
