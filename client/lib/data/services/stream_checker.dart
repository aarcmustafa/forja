import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';

/// خدمة فحص القنوات - تعمل في الخلفية بدون أن يراها المستخدم
class StreamChecker {
  static const String _boxName = 'stream_checks';
  static const String _kResults = 'results';
  static const String _kTimestamp = 'checked_at';

  /// مهلة قصيرة (للفحص الخلفي)
  static const Duration timeout = Duration(seconds: 4);

  /// عدد الفحوصات المتوازية
  static const int concurrency = 15;

  /// عدد الفحوصات في الدفعة الخلفية
  static const int backgroundBatchSize = 10;

  /// التأخير بين الدفعات (لتقليل الحِمل)
  static const Duration backgroundDelay = Duration(seconds: 8);

  static const List<int> okStatusCodes = [
    200, 206, 301, 302, 303, 307, 308,
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
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 11; Android TV) AppleWebKit/537.36',
            'Accept': '*/*',
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
      Response response;
      try {
        response = await _dio.head(channel.streamUrl);
      } catch (_) {
        response = await _dio.get(
          channel.streamUrl,
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Range': 'bytes=0-512'},
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

  /// تشغيل الفحص في الخلفية
  /// - يفحص الدفعات واحدة تلو الأخرى
  /// - يتوقف مؤقتاً إذا كانت القناة تُشغّل فيديو
  /// - يعيد فقط القنوات غير المفصولة مسبقاً
  Future<void> startBackgroundCheck(
    List<Channel> channels, {
    required void Function(String channelId, bool isWorking) onResult,
    Map<String, bool>? alreadyChecked,
  }) async {
    if (_isRunning) return;
    _isRunning = true;

    // فلترة: نتجاوز القنوات المفحوصة سابقاً
    final checkedIds = alreadyChecked?.keys.toSet() ?? <String>{};
    final toCheck = channels
        .where((c) => !checkedIds.contains(c.id))
        .toList();

    if (toCheck.isEmpty) {
      _isRunning = false;
      return;
    }

    // فحص صامت في الخلفية
    for (int i = 0; i < toCheck.length; i += backgroundBatchSize) {
      // إيقاف مؤقت إذا كان الفيديو يعمل
      while (_isPaused) {
        await Future.delayed(const Duration(seconds: 2));
      }

      if (!_isRunning) break;

      final batch = toCheck.skip(i).take(backgroundBatchSize).toList();
      final results = await Future.wait(batch.map((c) => checkOne(c)));

      // إرسال النتائج + حفظ فوري
      for (int j = 0; j < batch.length; j++) {
        onResult(batch[j].id, results[j]);
      }
      await _savePartialResults(batch, results);

      // تأخير بين الدفعات (لتقليل الحِمل)
      if (i + backgroundBatchSize < toCheck.length) {
        await Future.delayed(backgroundDelay);
      }
    }

    _isRunning = false;
  }

  /// إيقاف الفحص مؤقتاً (عند فتح فيديو)
  void pause() {
    _isPaused = true;
  }

  /// استئناف الفحص
  void resume() {
    _isPaused = false;
  }

  /// إيقاف الفحص نهائياً
  void stop() {
    _isRunning = false;
    _backgroundTimer?.cancel();
  }

  /// هل الفحص يعمل؟
  bool get isRunning => _isRunning;

  // ==========================================================
  //  حفظ + قراءة
  // ==========================================================
  Future<void> _savePartialResults(
    List<Channel> channels,
    List<bool> results,
  ) async {
    if (_box == null) await init();
    if (_box == null) return;

    try {
      final raw = _box!.get(_kResults);
      final Map<String, dynamic> map =
          raw != null ? Map<String, dynamic>.from(raw as Map) : {};

      for (int i = 0; i < channels.length; i++) {
        map[channels[i].id] = {
          'ok': results[i],
          'at': DateTime.now().millisecondsSinceEpoch,
        };
      }

      await _box!.put(_kResults, map);
      await _box!.put(_kTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// قراءة النتائج المحفوظة
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

  /// هل فُحصت هذه القناة؟
  Future<bool> hasBeenChecked(String channelId) async {
    final results = await loadResults();
    return results.containsKey(channelId);
  }
  
  /// وقت آخر فحص
  DateTime? getLastCheckTime() {
    if (_box == null) return null;
    final ts = _box!.get(_kTimestamp);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts as int);
  }

  /// عدد القنوات المفحوصة
  Future<int> getCheckedCount() async {
    final results = await loadResults();
    return results.length;
  }

  /// مسح النتائج
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
