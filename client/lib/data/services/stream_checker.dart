import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';

/// خدمة فحص القنوات - تعمل في الخلفية مع إدارة كاش ذكية
class StreamChecker {
  static const String _boxName = 'stream_checks';
  static const String _kResults = 'results';
  static const String _kTimestamp = 'checked_at';

  static const Duration timeout = Duration(seconds: 4);
  static const int concurrency = 15;
  static const int backgroundBatchSize = 10;
  static const Duration backgroundDelay = Duration(seconds: 8);

  /// ✅ الحد الأقصى لنتائج الفحص المحفوظة
  static const int maxSavedResults = 30000;

  /// ✅ بعد هذه المدة تُعاد محاولة فحص القناة التي سُجّلت ميتة
  static const Duration deadRecheckAfter = Duration(days: 3);

  /// ✅ VLC UA — مقبول من 99% من السيرفرات
  static const String vlcUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

  static const List<int> okStatusCodes = [
    200, // OK
    206, // Partial Content
    301, 302, 303, 307, 308, // إعادة التوجيه
    401, // Unauthorized (محتمل)
    403, // Forbidden (بعض السيرفرات ترفض HEAD فقط)
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

  // ==========================================================
  //  فحص قناة واحدة
  // ==========================================================
  Future<bool> checkOne(Channel channel) async {
    try {
      // Referer تلقائي
      final headers = <String, String>{
        'User-Agent': vlcUserAgent,
        'Accept': '*/*',
      };
      try {
        final uri = Uri.parse(channel.streamUrl);
        headers['Referer'] = '${uri.scheme}://${uri.host}/';
      } catch (_) {}

      // استخدام Referer المخصص إن وُجد
      final customReferer = channel.extras['referer'];
      if (customReferer != null && customReferer.isNotEmpty) {
        headers['Referer'] = customReferer;
      }

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
              'Range': 'bytes=0-512',
            },
          ),
        );
      }

      final code = response.statusCode ?? 0;
      return okStatusCodes.contains(code);
    } catch (_) {
      return false;
    }
  }

  // ==========================================================
  //  الفحص الخلفي التلقائي
  // ==========================================================
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

  // ==========================================================
  //  الحفظ والقراءة
  // ==========================================================
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

      // ✅ إذا كبر الكاش → احتفظ بأحدث maxSavedResults فقط
      if (map.length > maxSavedResults) {
        final entries = map.entries.toList()
          ..sort((a, b) {
            final ta = (a.value['at'] as int?) ?? 0;
            final tb = (b.value['at'] as int?) ?? 0;
            return tb.compareTo(ta);
          });

        map = Map.fromEntries(
          entries.take(maxSavedResults),
        );

        // ignore: avoid_print
        print('🧹 تم تنظيف نتائج الفحص القديمة');
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
      final now = DateTime.now().millisecondsSinceEpoch;
      map.forEach((k, v) {
        if (v is Map && v['ok'] is bool) {
          final ok = v['ok'] as bool;
          final at = (v['at'] as int?) ?? 0;
          // علامة "ميتة" قديمة → نتجاهلها ليُعاد فحصها في الخلفية
          if (!ok && now - at > deadRecheckAfter.inMilliseconds) return;
          result[k] = ok;
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  /// ✅ تسجيل نتيجة قناة واحدة (يستعملها المشغّل عند الفشل النهائي)
  Future<void> markResult(String channelId, bool ok) async {
    if (_box == null) await init();
    if (_box == null) return;
    try {
      final raw = _box!.get(_kResults);
      final map = raw != null
          ? Map<String, dynamic>.from(raw as Map)
          : <String, dynamic>{};
      map[channelId] = {
        'ok': ok,
        'at': DateTime.now().millisecondsSinceEpoch,
      };
      await _box!.put(_kResults, map);
    } catch (_) {}
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

  // ==========================================================
  //  إدارة الكاش — صيانة تلقائية
  // ==========================================================
  /// ✅ صيانة الكاش — تُستدعى عند بدء التطبيق
  Future<void> maintainCache() async {
    if (_box == null) await init();
    if (_box == null) return;

    try {
      final raw = _box!.get(_kResults);
      if (raw is! Map) return;

      final map = Map<String, dynamic>.from(raw);
      if (map.length <= maxSavedResults) return;

      // ترتيب حسب الوقت (الأحدث أولاً)
      final entries = map.entries.toList()
        ..sort((a, b) {
          final ta = (a.value['at'] as int?) ?? 0;
          final tb = (b.value['at'] as int?) ?? 0;
          return tb.compareTo(ta);
        });

      final trimmed = Map.fromEntries(
        entries.take(maxSavedResults),
      );

      await _box!.put(_kResults, trimmed);
      // ignore: avoid_print
      print('🧹 تم تقليم نتائج الفحص: ${map.length} → ${trimmed.length}');
    } catch (_) {}
  }

  /// ✅ معلومات الكاش
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
