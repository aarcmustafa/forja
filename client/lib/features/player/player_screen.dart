import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/providers/playlist_provider.dart';

/// شاشة المشغل — محاولات صامتة (دائرة تحميل فقط) + إخفاء القنوات المتعثرة نهائياً
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
  late final PlaylistNotifier _playlist;

  bool _isLoading = true;
  bool _showControls = true;
  Timer? _hideControlsTimer;
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

  // ✅ مسارات الترجمة فقط
  List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack? _currentSubtitleTrack;

  final List<double> _speedOptions = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // ==========================================================
  //  ✅ التشغيل الصامت (بدون أي رسالة للمستخدم)
  //  كل محاولة = User-Agent مختلف، والمحاولات تتم خلف دائرة التحميل
  // ==========================================================
  static const List<String> _userAgents = [
    'VLC/3.0.20 LibVLC/3.0.20',
    'Mozilla/5.0 (Linux; Android 11; Android TV) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'ExoPlayer/2.19.1 (Linux; Android 11) ExoPlayerLib/2.19.1',
  ];

  /// مهلة كل محاولة بالثواني (الأولى أطول قليلاً)
  static const List<int> _attemptSeconds = [12, 10, 10];

  /// أقصى عدد مرات إعادة التشغيل إذا انقطع البث أثناء المشاهدة
  static const int _maxMidPlayDrops = 3;

  final List<StreamSubscription> _subs = [];
  Completer<bool>? _attemptCompleter;
  bool _disposed = false;
  bool _hasStarted = false;
  bool _recovering = false;
  bool _gaveUp = false;
  int _dropCount = 0;

  @override
  void initState() {
    super.initState();
    _playlist = ref.read(playlistProvider.notifier);
    // ⏸️ إيقاف الفحص الخلفي أثناء المشاهدة
    Future.microtask(() {
      try {
        _playlist.pauseBackgroundCheck();
      } catch (_) {}
    });
    _initializePlayer();
  }

  @override
  void dispose() {
    _disposed = true;
    final c = _attemptCompleter;
    if (c != null && !c.isCompleted) c.complete(false);
    for (final s in _subs) {
      s.cancel();
    }
    _hideControlsTimer?.cancel();
    _volumeBarTimer?.cancel();
    try {
      _playlist.resumeBackgroundCheck();
    } catch (_) {}
    player.dispose();
    super.dispose();
  }

  // ==========================================================
  //  التهيئة
  // ==========================================================
  Future<void> _initializePlayer() async {
    // ملاحظة: إنشاء player و controller يجب أن يتم قبل أي await
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

    _subs.add(player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
    }));

    _subs.add(player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      setState(() => _isBuffering = buffering);
    }));

    _subs.add(player.stream.position.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
      // ظهور تقدّم في الزمن = القناة اشتغلت (يشمل البث الصوتي فقط)
      if (pos >= const Duration(seconds: 1)) _signalStarted();
    }));

    _subs.add(player.stream.duration.listen((dur) {
      if (!mounted) return;
      setState(() => _duration = dur);
    }));

    // ظهور صورة = القناة اشتغلت
    _subs.add(player.stream.width.listen((w) {
      if (w != null && w > 0) _signalStarted();
    }));

    _subs.add(player.stream.error.listen(_onPlayerError));

    // ✅ مسارات الترجمة
    _subs.add(player.stream.tracks.listen((tracks) {
      if (!mounted) return;
      setState(() => _subtitleTracks = tracks.subtitle);
    }));

    _subs.add(player.stream.track.listen((track) {
      if (!mounted) return;
      setState(() => _currentSubtitleTrack = track.subtitle);
    }));

    _startHideControlsTimer();

    try {
      final ok = await _playWithFallback();
      if (!ok) await _giveUp(markDead: true);
    } catch (_) {
      await _giveUp(markDead: false);
    }
  }

  // ==========================================================
  //  المحاولات الصامتة
  // ==========================================================
  void _signalStarted() {
    final c = _attemptCompleter;
    if (c != null && !c.isCompleted) c.complete(true);
  }

  void _onPlayerError(String error) {
    if (_disposed) return;
    final c = _attemptCompleter;
    if (c != null && !c.isCompleted) {
      // فشلت المحاولة الحالية → ننتقل فوراً للتالية
      c.complete(false);
      return;
    }
    // انقطاع بعد أن كانت القناة تعمل
    if (_hasStarted) _recoverFromDrop();
  }

  /// يجرّب كل الـ User-Agents بالتتابع. true = اشتغلت القناة.
  Future<bool> _playWithFallback() async {
    for (var i = 0; i < _userAgents.length; i++) {
      if (_disposed) return false;
      final ok = await _tryOpen(i);
      if (ok) {
        _hasStarted = true;
        if (mounted) setState(() => _isLoading = false);
        return true;
      }
    }
    return false;
  }

  Future<bool> _tryOpen(int index) async {
    try {
      await player.stop();
    } catch (_) {}
    // مهلة قصيرة حتى تصل أي أخطاء متأخرة من المحاولة السابقة ونتجاهلها
    await Future.delayed(const Duration(milliseconds: 250));
    if (_disposed) return false;

    final completer = Completer<bool>();
    _attemptCompleter = completer;

    final timer = Timer(Duration(seconds: _attemptSeconds[index]), () {
      if (!completer.isCompleted) completer.complete(false);
    });

    try {
      await player.open(
        Media(
          widget.streamUrl,
          httpHeaders: _buildHeaders(widget.streamUrl, _userAgents[index]),
        ),
        play: true,
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
    }

    final ok = await completer.future;
    timer.cancel();
    if (identical(_attemptCompleter, completer)) _attemptCompleter = null;
    return ok;
  }

  Map<String, String> _buildHeaders(String url, String userAgent) {
    final headers = <String, String>{
      'User-Agent': userAgent,
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

  /// انقطاع أثناء المشاهدة → دائرة التحميل + إعادة تشغيل صامتة
  Future<void> _recoverFromDrop() async {
    if (_recovering || _disposed || _gaveUp) return;
    if (_dropCount >= _maxMidPlayDrops) {
      await _giveUp(markDead: false);
      return;
    }
    _recovering = true;
    _dropCount++;
    _hasStarted = false;
    if (mounted) setState(() => _isLoading = true);

    final ok = await _playWithFallback();
    _recovering = false;
    if (!ok && !_disposed) await _giveUp(markDead: false);
  }

  /// فشل نهائي: نخفي القناة من القوائم (إن كان الإنترنت يعمل) ونعود للخلف
  Future<void> _giveUp({required bool markDead}) async {
    if (_gaveUp || _disposed) return;
    _gaveUp = true;

    if (markDead && await _hasInternet()) {
      if (!_disposed) {
        await _playlist.markDeadByUrl(widget.streamUrl);
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// نتأكد أن الفشل من القناة وليس من انقطاع إنترنت المستخدم
  Future<bool> _hasInternet() async {
    for (final host in const ['google.com', 'cloudflare.com']) {
      try {
        final r = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 4));
        if (r.isNotEmpty) return true;
      } catch (_) {}
    }
    return false;
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
  //  ✅ قائمة اختيار الترجمة
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
      builder: (ctx) {
        return Directionality(
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
                    // العنوان
                    Row(
                      children: [
                        const Icon(
                          Icons.subtitles_rounded,
                          color: Color(0xFF00C8FF),
                          size: 24,
                        ),
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
                            horizontal: 10,
                            vertical: 4,
                          ),
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
                            // خيار "بلا ترجمة"
                            _sheetOption(
                              label: 'بلا ترجمة',
                              isSelected:
                                  _currentSubtitleTrack == null ||
                                      _currentSubtitleTrack!.id == 'no',
                              onTap: () async {
                                await player.setSubtitleTrack(
                                  SubtitleTrack.no(),
                                );
                                setSheetState(() {});
                                _startHideControlsTimer();
                              },
                            ),

                            // قائمة الترجمات المتاحة
                            if (_subtitleTracks.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Divider(color: Color(0xFF2A3350)),
                              const SizedBox(height: 10),
                              ..._subtitleTracks.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final track = entry.value;
                                final isSelected =
                                    _currentSubtitleTrack?.id == track.id;
                                return _sheetOption(
                                  label: _subtitleTrackLabel(track, idx),
                                  isSelected: isSelected,
                                  onTap: () async {
                                    await player.setSubtitleTrack(track);
                                    setSheetState(() {});
                                    _startHideControlsTimer();
                                  },
                                );
                              }),
                            ] else ...[
                              const SizedBox(height: 20),
                              const Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.subtitles_off_rounded,
                                      color: Colors.white24,
                                      size: 60,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'لا توجد ترجمات متاحة لهذه القناة',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
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
        );
      },
    ).then((_) {
      if (mounted) _startHideControlsTimer();
    });
  }

  // ==========================================================
  //  خيار في القائمة
  // ==========================================================
  Widget _sheetOption({
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
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
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

  // ==========================================================
  //  تسميات الترجمات
  // ==========================================================
  String _subtitleTrackLabel(SubtitleTrack track, int index) {
    final lang = track.language ?? '';

    // ترجمة اللغات الشائعة
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
                Center(
                  child: SizedBox.expand(
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
                if (_isLoading) _buildLoading(),
                if (_isBuffering && !_isLoading) _buildBuffering(),
                if (_showVolumeBar) _buildVolumeOverlay(),
                if (_showControls) ...[
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
        const SizedBox(width: 14),
        _CircleButton(
          icon: Icons.replay_10,
          size: 40,
          onPressed: _seekBackward,
        ),
        const SizedBox(width: 14),
        _CircleButton(
          icon: _isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          size: 56,
          filled: true,
          onPressed: _togglePlayPause,
        ),
        const SizedBox(width: 14),
        _CircleButton(
          icon: Icons.forward_10,
          size: 40,
          onPressed: _seekForward,
        ),
        const SizedBox(width: 14),
        _CircleButton(
          icon: Icons.speed_rounded,
          size: 40,
          onPressed: _changeSpeed,
        ),
        const SizedBox(width: 14),
        _CircleButton(
          icon: Icons.aspect_ratio_rounded,
          size: 40,
          onPressed: _changeAspect,
        ),
        const SizedBox(width: 14),
        // 💬 زر الترجمة
        _CircleButton(
          icon: Icons.subtitles_rounded,
          size: 40,
          onPressed: _showSubtitleSheet,
          hasBadge: _subtitleTracks.isNotEmpty,
        ),
      ],
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
            // ✅ Badge يظهر عند وجود ترجمات
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
