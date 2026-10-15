import 'dart:async';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';

/// خدمة فحص القنوات — تعمل في الخلفية مع إدارة كاش ذكية
class StreamChecker {
  static const String _boxName = 'stream_checks';
  static const String _kResults = 'results';
  static const String _kTimestamp = 'checked_at';

  static const Duration timeout = Duration(seconds: 4);
  static const int backgroundBatchSize = 10;
  static const Duration backgroundDelay = Duration(seconds: 8);
  static const int maxSavedResults = 30000;

  static const String vlcUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

  static const List<int> okStatusCodes = [
    200, 206, 301, 302, 303, 307, 308,
    401, 403,
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
//  الفحص الأولي (مصحح — بدون bug الـ 20 قناة)
// ==========================================================
Future<Map<String, bool>> checkInitial(
  List<Channel> channels, {
  int? limit,
  int batchSize = 20,
  void Function(int done, int total)? onProgress,
  void Function(Map<String, bool> batchResults)? onBatch,
}) async {
  final result = <String, bool>{};

  if (channels.isEmpty) return result;

  final toCheck = limit != null && limit > 0 && limit < channels.length
      ? channels.take(limit).toList()
      : channels;
  final total = toCheck.length;

  for (int i = 0; i < total; i += batchSize) {
    // نحترم فقط الإيقاف المؤقت
    while (_isPaused) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final batch = toCheck.skip(i).take(batchSize).toList();

    try {
      final batchResults = await Future.wait(batch.map(checkOne));
      final batchMap = <String, bool>{};
      for (int j = 0; j < batch.length; j++) {
        batchMap[batch[j].id] = batchResults[j];
        result[batch[j].id] = batchResults[j];
      }
      onBatch?.call(batchMap);
    } catch (_) {
      final batchMap = <String, bool>{};
      for (final c in batch) {
        batchMap[c.id] = false;
        result[c.id] = false;
      }
      onBatch?.call(batchMap);
    }

    onProgress?.call(
      (i + batch.length).clamp(0, total),
      total,
    );

    // حفظ تدريجي كل 5 دفعات
    if (i > 0 && (i ~/ batchSize) % 5 == 0) {
      await _saveBatchResults(result);
    }
  }

  await _saveBatchResults(result);
  return result;
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
    final results = await Future.wait(batch.map(checkOne));

    final batchMap = <String, bool>{};
    for (int j = 0; j < batch.length; j++) {
      onResult(batch[j].id, results[j]);
      batchMap[batch[j].id] = results[j];
    }
    await _saveBatchResults(batchMap);

    if (i + backgroundBatchSize < toCheck.length) {
      await Future.delayed(backgroundDelay);
    }
  }

  _isRunning = false;
}
  // ==========================================================
//  تحديد قناة/عدة قنوات كـ ميتة أو شغّالة
// ==========================================================
Future<void> markDead(String channelId) async {
  await _saveBatchResults({channelId: false});
}

Future<void> markDeadMultiple(List<String> channelIds) async {
  if (channelIds.isEmpty) return;
  final map = {for (final id in channelIds) id: false};
  await _saveBatchResults(map);
}

Future<void> markWorking(String channelId) async {
  await _saveBatchResults({channelId: true});
}

Future<void> markWorkingMultiple(List<String> channelIds) async {
  if (channelIds.isEmpty) return;
  final map = {for (final id in channelIds) id: true};
  await _saveBatchResults(map);
}

// ==========================================================
//  حفظ دفعة نتائج
// ==========================================================
Future<void> _saveBatchResults(Map<String, bool> results) async {
  if (results.isEmpty) return;
  await init();
  if (_box == null) return;

  try {
    final raw = _box!.get(_kResults);
    Map<String, dynamic> map =
        raw != null ? Map<String, dynamic>.from(raw as Map) : {};

    final now = DateTime.now().millisecondsSinceEpoch;
    results.forEach((id, isWorking) {
      map[id] = {'ok': isWorking, 'at': now};
    });

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
    await _box!.put(_kTimestamp, now);
  } catch (_) {}
}

// ==========================================================
//  تحميل النتائج
// ==========================================================
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

DateTime? getLastCheckTime() {
  if (_box == null) return null;
  final ts = _box!.get(_kTimestamp);
  if (ts == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(ts as int);
}

// ==========================================================
//  إحصائيات
// ==========================================================
Future<int> getWorkingCount() async {
  final results = await loadResults();
  return results.values.where((v) => v == true).length;
}

Future<int> getDeadCount() async {
  final results = await loadResults();
  return results.values.where((v) => v == false).length;
}
    // ==========================================================
  //  التحكم
  // ==========================================================
  void pause() => _isPaused = true;
  void resume() => _isPaused = false;
  void stop() {
    _isRunning = false;
    _backgroundTimer?.cancel();
  }

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;

  // ==========================================================
  //  صيانة الكاش
  // ==========================================================
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

  // ==========================================================
  //  مسح النتائج
  // ==========================================================
  Future<void> clear() async {
    if (_box == null) await init();
    if (_box == null) return;
    await _box!.delete(_kResults);
    await _box!.delete(_kTimestamp);
  }

  Future<void> reset() async {
    await clear();
  }

  // ==========================================================
  //  تنظيف الموارد
  // ==========================================================
  void dispose() {
    stop();
    _dio.close();
  }
}
