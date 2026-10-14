import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';

/// ✅ فحص بطيء وآمن — لا يستفز Cloudflare
class StreamChecker {
  static const String _boxName = 'stream_checks';
  static const String _kResults = 'results';
  static const String _kTimestamp = 'checked_at';

  static const Duration timeout = Duration(seconds: 5);

  /// ✅ تقليل التوازي (10 → 3)
  static const int concurrency = 3;
  static const int backgroundBatchSize = 3;

  /// ✅ زيادة التأخير (8s → 15s)
  static const Duration backgroundDelay = Duration(seconds: 15);

  /// ✅ نتيجة صالحة 7 أيام (بدل كل مرة)
  static const Duration resultValidity = Duration(days: 7);

  static const int maxSavedResults = 30000;

  static const String vlcUserAgent = 'okhttp/4.9.0';

  static const List<int> okStatusCodes = [200, 206, 301, 302, 303, 307, 308];

  final Dio _dio;
  Box? _box;
  Timer? _backgroundTimer;
  bool _isRunning = false;
  bool _isPaused = false;

  StreamChecker()
      : _dio = Dio(BaseOptions(
          connectTimeout: timeout,
          receiveTimeout: timeout,
          followRedirects: true,
          validateStatus: (_) => true,
          headers: {
            'User-Agent': vlcUserAgent,
            'Accept': '*/*',
            'Connection': 'keep-alive',
          },
        ));

  Future<void> init() async {
    if (_box != null) return;
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);
    } catch (_) {}
  }

  /// ✅ GET مع Range بدل HEAD (HEAD محظور من بعض السيرفرات)
  /// ✅ فحص 7 أيام أولاً قبل إعادة الفحص
  Future<bool> checkOne(Channel channel) async {
    try {
      if (_box == null) await init();

      // فحص النتيجة السابقة
      if (_box != null) {
        final raw = _box!.get(_kResults);
        if (raw is Map) {
          final data = raw[channel.id];
          if (data is Map && data['at'] is int) {
            final savedAt =
                DateTime.fromMillisecondsSinceEpoch(data['at'] as int);
            if (DateTime.now().difference(savedAt) < resultValidity) {
              return data['ok'] as bool? ?? false;
            }
          }
        }
      }

      final headers = <String, String>{
        'User-Agent': vlcUserAgent,
        'Accept': '*/*',
        'Range': 'bytes=0-512',
      };

      // ✅ GET بدل HEAD
      final response = await _dio.get(
        channel.streamUrl,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
        ),
      );

      final code = response.statusCode ?? 0;
      return okStatusCodes.contains(code);
    } catch (_) {
      return false;
    }
  }

  Future<void> startBackgroundCheck(
    List<Channel> channels, {
    required void Function(String channelId, bool isWorking) onResult,
    Map<String, bool>? alreadyChecked,
  }) async {
    if (_isRunning) return;
    _isRunning = true;

    final checkedIds = alreadyChecked?.keys.toSet() ?? <String>{};
    final toCheck =
        channels.where((c) => !checkedIds.contains(c.id)).toList();

    if (toCheck.isEmpty) {
      _isRunning = false;
      return;
    }

    for (int i = 0; i < toCheck.length; i += backgroundBatchSize) {
      while (_isPaused) {
        await Future.delayed(const Duration(seconds: 2));
      }
      if (!_isRunning) break;

      final batch = toCheck.skip(i).take(backgroundBatchSize).toList();
      final results = await Future.wait(batch.map((c) => checkOne(c)));

      for (int j = 0; j < batch.length; j++) {
        onResult(batch[j].id, results[j]);
      }
      await _savePartialResults(batch, results);

      if (i + backgroundBatchSize < toCheck.length) {
        await Future.delayed(backgroundDelay);
      }
    }

    _isRunning = false;
  }

  void pause() => _isPaused = true;
  void resume() => _isPaused = false;

  void stop() {
    _isRunning = false;
    _backgroundTimer?.cancel();
  }

  bool get isRunning => _isRunning;
