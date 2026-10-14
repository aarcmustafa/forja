import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';

/// خدمة فحص القنوات — بطيئة ولطيفة (لا تزعج Cloudflare)
class StreamChecker {
  static const String _boxName = 'stream_checks';
  static const String _kResults = 'results';
  static const String _kTimestamp = 'checked_at';

  /// ✅ مهلة قصيرة جداً
  static const Duration timeout = Duration(seconds: 3);

  /// ✅ توازي منخفض جداً (تم تقليله من 10)
  static const int concurrency = 2;

  /// ✅ دفعة صغيرة (تم تقليلها من 8)
  static const int backgroundBatchSize = 3;

  /// ✅ راحة طويلة بين الدفعات (تمت زيادتها من 15)
  static const Duration backgroundDelay = Duration(seconds: 30);

  /// ✅ تأخير أولي قبل البدء (تمت زيادته من 30)
  static const Duration initialDelay = Duration(seconds: 60);

  static const int maxSavedResults = 30000;

  static const String vlcUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

  static const List<int> okStatusCodes = [
    200, 206,
    301, 302, 303, 307, 308,
  ];

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

  Future<bool> checkOne(Channel channel) async {
    try {
      // ✅ بدون Referer/Origin (قد يسبب 511)
      final headers = <String, String>{
        'User-Agent': vlcUserAgent,
        'Accept': '*/*',
      };

      Response response;
      try {
        response = await _dio.head(
          channel.streamUrl,
          options: Options(headers: headers),
        );
      } catch (_) {
        response = await _dio.get(
          channel.streamUrl,
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              ...headers,
              'Range': 'bytes=0-256',
            },
          ),
        );
      }

      final code = response.statusCode ?? 0;

      // ✅ لا نعتبر 403 فشلاً إذا كان بسبب referer
      if (code == 403 || code == 511) {
        // جرّب مرة أخرى بدون أي headers
        try {
          final retry = await _dio.head(channel.streamUrl);
          final retryCode = retry.statusCode ?? 0;
          return retryCode == 200 || retryCode == 206;
        } catch (_) {
          return false;
        }
      }

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

    // ✅ تأخير 60 ثانية قبل البدء
    await Future.delayed(initialDelay);
    if (!_isRunning) return;

    final checkedIds = alreadyChecked?.keys.toSet() ?? <String>{};
    final toCheck =
        channels.where((c) => !checkedIds.contains(c.id)).toList();

    if (toCheck.isEmpty) {
      _isRunning = false;
      return;
    }

    // ✅ فحص 3 قنوات فقط في كل دفعة
    for (int i = 0; i < toCheck.length; i += backgroundBatchSize) {
      while (_isPaused) {
        await Future.delayed(const Duration(seconds: 2));
      }
      if (!_isRunning) break;

      final batch = toCheck.skip(i).take(backgroundBatchSize).toList();

      // ✅ معالجة متتالية داخل الدفعة (لا توازي)
      final results = <bool>[];
      for (final c in batch) {
        final r = await checkOne(c);
        results.add(r);
      }

      for (int j = 0; j < batch.length; j++) {
        onResult(batch[j].id, results[j]);
      }
      await _savePartialResults(batch, results);

      // ✅ راحة 30 ثانية بين الدفعات
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

  Future<void> _savePartialResults(
    List<Channel> channels,
    List<bool> results,
  ) async {
    if (_box == null) await init();
    if (_box == null) return;

    try {
      final raw = _box!.get(_kResults);
      Map<String, dynamic> map =
          raw != null ? Map<String, dynamic>.from(raw as Map) : {};

      for (int i = 0; i < channels.length; i++) {
        map[channels[i].id] = {
          'ok': results[i],
          'at': DateTime.now().millisecondsSinceEpoch,
        };
      }

      if (map.length > maxSavedResults) {
        final entries = map.entries.toList()
          ..sort((a, b) {
            final ta = (a.value['at'] as int?) ?? 0;
            final tb = (b.value['at'] as int?) ?? 0;
            return tb.compareTo(ta);
          });
        map = Map.fromEntries(entries.take(maxSavedResults));
      }

      await _box!.put(_kResults, map);
      await _box!.put(_kTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<Map<String, bool>> loadResults() async {
    if (_box == null) await init();
    if (_box == null) return {};

    try {
      final raw = _box!.get(_kResults);
      if (raw == null) return {};

      final map = Map<String, dynamic>.from(raw as Map);
      final result = <String, bool>{};
      map.forEach((k, v) {
        if (v is Map && v['ok'] is bool) {
          result[k] = v['ok'] as bool;
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<bool> hasBeenChecked(String channelId) async {
    final results = await loadResults();
    return results.containsKey(channelId);
  }

  DateTime? getLastCheckTime() {
    if (_box == null) return null;
    final ts = _box!.get(_kTimestamp);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts as int);
  }

  Future<int> getCheckedCount() async {
    final results = await loadResults();
    return results.length;
  }

  Future<void> maintainCache() async {
    if (_box == null) await init();
    if (_box == null) return;

    try {
      final raw = _box!.get(_kResults);
      if (raw is! Map) return;

      final map = Map<String, dynamic>.from(raw);
      if (map.length <= maxSavedResults) return;

      final entries = map.entries.toList()
        ..sort((a, b) {
          final ta = (a.value['at'] as int?) ?? 0;
          final tb = (b.value['at'] as int?) ?? 0;
          return tb.compareTo(ta);
        });

      final trimmed = Map.fromEntries(entries.take(maxSavedResults));
      await _box!.put(_kResults, trimmed);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getCacheInfo() async {
    if (_box == null) await init();
    if (_box == null) {
      return {'ready': false, 'count': 0, 'limit': maxSavedResults};
    }

    try {
      final raw = _box!.get(_kResults);
      final count = raw is Map ? raw.length : 0;
      return {
        'ready': true,
        'count': count,
        'limit': maxSavedResults,
        'lastCheck': getLastCheckTime()?.toIso8601String(),
      };
    } catch (_) {
      return {'ready': false, 'count': 0, 'limit': maxSavedResults};
    }
  }

  Future<void> clear() async {
    if (_box == null) await init();
    if (_box == null) return;
    await _box!.delete(_kResults);
    await _box!.delete(_kTimestamp);
  }

  void dispose() {
    stop();
    _dio.close();
  }
}
