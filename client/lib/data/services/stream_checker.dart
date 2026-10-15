import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';

/// خدمة فحص القنوات
/// - فحص سريع (محاولة واحدة)
/// - فحص شامل (3 محاولات) للاستخدام الأولي
/// - بدون طباعة مزعجة
class StreamChecker {
  static const String _boxName = 'stream_checks';
  static const String _kResults = 'results';
  static const String _kTimestamp = 'checked_at';

  /// مهلة الفحص السريع
  static const Duration quickTimeout = Duration(seconds: 3);

  /// مهلة الفحص الشامل (لكل محاولة)
  static const Duration thoroughTimeout = Duration(seconds: 4);

  /// عدد محاولات الفحص الشامل
  static const int thoroughAttempts = 3;

  /// عدد الفحوصات المتوازية في الفحص الأولي
  static const int initialConcurrency = 40;

  /// عدد الفحوصات المتوازية في الفحص الخلفي
  static const int concurrency = 15;

  /// حجم دفعة الفحص الخلفي
  static const int backgroundBatchSize = 10;

  /// التأخير بين دفعات الفحص الخلفي
  static const Duration backgroundDelay = Duration(seconds: 8);

  /// الحد الأقصى لنتائج الفحص المحفوظة
  static const int maxSavedResults = 30000;

  /// User-Agent
  static const String vlcUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

  static const List<int> okStatusCodes = [
    200, 206,
    301, 302, 303, 307, 308,
    401, 403,
  ];

  final Dio _dio;
  Box? _box;
  Timer? _backgroundTimer;
  bool _isRunning = false;
  bool _isPaused = false;

  StreamChecker()
      : _dio = Dio(BaseOptions(
          connectTimeout: quickTimeout,
          receiveTimeout: quickTimeout,
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
  //  فحص قناة واحدة (محاولة واحدة سريعة)
  // ==========================================================
  Future<bool> checkOne(Channel channel) async {
    return _attemptCheck(channel, quickTimeout);
  }

  /// فحص شامل (3 محاولات)
  /// يتوقف بمجرد نجاح محاولة
  Future<bool> checkThorough(Channel channel) async {
    for (int i = 0; i < thoroughAttempts; i++) {
      final ok = await _attemptCheck(channel, thoroughTimeout);
      if (ok) return true;
      // انتظار قصير قبل المحاولة التالية
      if (i < thoroughAttempts - 1) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
    return false;
  }

  /// محاولة واحدة
  Future<bool> _attemptCheck(Channel channel, Duration timeout) async {
    try {
      final headers = <String, String>{
        'User-Agent': vlcUserAgent,
        'Accept': '*/*',
      };
      try {
        final uri = Uri.parse(channel.streamUrl);
        headers['Referer'] = '${uri.scheme}://${uri.host}/';
      } catch (_) {}

      final customReferer = channel.extras['referer'];
      if (customReferer != null && customReferer.isNotEmpty) {
        headers['Referer'] = customReferer;
      }

      Response response;
      try {
        response = await _dio.head(
          channel.streamUrl,
          options: Options(
            headers: headers,
            sendTimeout: timeout,
            receiveTimeout: timeout,
          ),
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
            sendTimeout: timeout,
            receiveTimeout: timeout,
          ),
        );
      }

      final code = response.statusCode ?? 0;
      if (!okStatusCodes.contains(code)) return false;

      // للتحقق الإضافي: إذا كان HEAD، جرّب GET للتأكد
      if (response.requestOptions.method == 'HEAD' &&
          (code == 405 || code == 501)) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // ==========================================================
  //  ✅ الفحص الأولي (قبل ظهور القنوات لأول مرة)
  // ==========================================================
  /// يفحص كل القنوات بـ 3 محاولات لكل واحدة
  /// يعيد: Map<channelId, isWorking>
  /// [onProgress]: (done, total) للتحكم بشريط التقدم
  Future<Map<String, bool>> checkInitial(
    List<Channel> channels, {
    void Function(int done, int total)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final results = <String, bool>{};
    if (channels.isEmpty) return results;

    final total = channels.length;
    int done = 0;
    final queue = List<Channel>.from(channels);

    // معالجة بالتوازي المحدود
    while (queue.isNotEmpty) {
      if (shouldCancel?.call() ?? false) break;

      final batchSize =
          queue.length > initialConcurrency ? initialConcurrency : queue.length;
      final batch = queue.take(batchSize).toList();
      queue.removeRange(0, batchSize);

      final batchResults = await Future.wait(
        batch.map((c) => checkThorough(c)),
      );

      for (int i = 0; i < batch.length; i++) {
        results[batch[i].id] = batchResults[i];
      }

      done += batch.length;
      onProgress?.call(done, total);
    }

    // حفظ النتائج
    await _mergeAndSaveResults(results);

    return results;
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

  /// دمج نتائج جديدة مع المحفوظة
  Future<void> _mergeAndSaveResults(Map<String, bool> newResults) async {
    if (_box == null) await init();
    if (_box == null) return;

    try {
      final raw = _box!.get(_kResults);
      final Map<String, dynamic> map =
          raw != null ? Map<String, dynamic>.from(raw as Map) : {};

      final now = DateTime.now().millisecondsSinceEpoch;
      newResults.forEach((id, ok) {
        map[id] = {'ok': ok, 'at': now};
      });

      await _box!.put(_kResults, map);
      await _box!.put(_kTimestamp, now);
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
