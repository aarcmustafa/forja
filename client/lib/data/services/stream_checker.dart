import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';

/// نتيجة فحص واحد
enum _Probe { ok, dead, retry }

/// خدمة فحص القنوات - تعمل في الخلفية مع إدارة كاش ذكية
class StreamChecker {
  static const String _boxName = 'stream_checks';
  static const String _kResults = 'results';
  static const String _kTimestamp = 'checked_at';

  static const Duration timeout = Duration(seconds: 6);
  static const int concurrency = 25;
  static const int backgroundBatchSize = 25;
  static const Duration backgroundDelay = Duration(seconds: 2);

  /// ✅ الحد الأقصى لنتائج الفحص المحفوظة
  static const int maxSavedResults = 30000;

  /// ✅ بعد هذه المدة تُعاد محاولة فحص القناة التي سُجّلت ميتة
  static const Duration deadRecheckAfter = Duration(days: 3);

  /// ✅ بعد هذه المدة تُعاد مراجعة القناة التي كانت تعمل
  static const Duration okRecheckAfter = Duration(days: 7);

  static const String browserUserAgent =
      'Mozilla/5.0 (Linux; Android 11; Android TV) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

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
  //  فحص قناة واحدة (فحص حقيقي: نقرأ أول بيانات من البث)
  // ==========================================================
  Future<bool> checkOne(Channel channel) async {
    for (final ua in const [vlcUserAgent, browserUserAgent]) {
      final r = await _probe(channel, ua);
      if (r == _Probe.ok) return true;
      if (r == _Probe.dead) return false;
      // _Probe.retry → نجرّب User-Agent آخر
    }
    return false;
  }

  Future<_Probe> _probe(Channel channel, String userAgent) async {
    final cancel = CancelToken();
    void stopRequest() {
      if (!cancel.isCancelled) cancel.cancel();
    }

    try {
      final headers = <String, String>{
        'User-Agent': userAgent,
        'Accept': '*/*',
        'Range': 'bytes=0-2047',
      };
      try {
        final uri = Uri.parse(channel.streamUrl);
        headers['Referer'] = '${uri.scheme}://${uri.host}/';
      } catch (_) {}
      final customReferer = channel.extras['referer'];
      if (customReferer != null && customReferer.isNotEmpty) {
        headers['Referer'] = customReferer;
      }

      final response = await _dio.get<ResponseBody>(
        channel.streamUrl,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
        ),
      );

      final code = response.statusCode ?? 0;

      // رفض بسبب الهوية → نجرّب User-Agent آخر
      if (code == 401 || code == 403 || code == 405) {
        stopRequest();
        return _Probe.retry;
      }
      if (code != 200 && code != 206) {
        stopRequest();
        return _Probe.dead;
      }

      final ctype =
          (response.headers.value('content-type') ?? '').toLowerCase();
      // صفحة خطأ HTML بدل البث
      if (ctype.contains('text/html')) {
        stopRequest();
        return _Probe.dead;
      }

      final body = response.data;
      if (body == null) {
        stopRequest();
        return _Probe.dead;
      }

      // نقرأ أول جزء من البيانات فقط
      final chunk = await body.stream.first.timeout(timeout);
      stopRequest();
      if (chunk.isEmpty) return _Probe.dead;

      final isHls = channel.streamUrl.toLowerCase().contains('.m3u8') ||
          ctype.contains('mpegurl');
      if (isHls) {
        final text = String.fromCharCodes(chunk);
        return text.contains('#EXTM3U') ? _Probe.ok : _Probe.dead;
      }
      return _Probe.ok;
    } catch (_) {
      stopRequest();
      return _Probe.dead;
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
          // نتيجة قديمة → نتجاهلها ليُعاد فحصها في الخلفية
          final maxAge = ok
              ? okRecheckAfter.inMilliseconds
              : deadRecheckAfter.inMilliseconds;
          if (now - at > maxAge) return;
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
