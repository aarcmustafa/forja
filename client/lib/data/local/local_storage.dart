import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';

/// تخزين محلي محسّن:
/// - يخزّن القنوات كنص JSON واحد
/// - يفك الترميز في Isolate
/// - لا يفرض انتهاء صلاحية
/// - يحفظ علم "الفحص الأولي تم"
class LocalStorage {
  static const String _boxName = 'channels_cache';
  static const String _kChannelsJson = 'channels_json';
  static const String _kChannelsLegacy = 'channels_list';
  static const String _kTimestamp = 'saved_at';
  static const String _kVersion = 'schema_version';
  static const String _kInitialCheckDone = 'initial_check_done';
  static const int _currentVersion = 2;

  static const int maxSavedChannels = 100000;

  late Box _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);

    final savedVersion = _box.get(_kVersion, defaultValue: 0);
    if (savedVersion != _currentVersion) {
      await _box.delete(_kChannelsLegacy);
      await _box.put(_kVersion, _currentVersion);
      // تصفير علم الفحص الأولي عند تغيير الإصدار
      await _box.put(_kInitialCheckDone, false);
    }

    _initialized = true;
  }

  bool get isReady => _initialized;

  // ==========================================================
  //  علم الفحص الأولي
  // ==========================================================
  bool hasInitialCheckDone() {
    if (!_initialized) return false;
    return (_box.get(_kInitialCheckDone, defaultValue: false) as bool?) ??
        false;
  }

  Future<void> markInitialCheckDone() async {
    if (!_initialized) await init();
    await _box.put(_kInitialCheckDone, true);
  }

  Future<void> resetInitialCheck() async {
    if (!_initialized) await init();
    await _box.put(_kInitialCheckDone, false);
  }

  // ==========================================================
  //  ترميز / فك ترميز (في Isolate)
  // ==========================================================
  static String _encodeChannels(List<Channel> channels) {
    final list = channels.map((c) => c.toJson()).toList();
    return jsonEncode(list);
  }

  static List<Channel> _decodeChannels(String jsonStr) {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! List) return const [];
    final channels = <Channel>[];
    for (final item in decoded) {
      try {
        final map = Map<String, dynamic>.from(item as Map);
        channels.add(Channel.fromJson(map));
      } catch (_) {}
    }
    return channels;
  }

  // ==========================================================
  //  حفظ
  // ==========================================================
  Future<void> saveChannels(List<Channel> channels) async {
    if (!_initialized) await init();

    try {
      final jsonStr = await compute(_encodeChannels, channels);
      await _box.put(_kChannelsJson, jsonStr);
      await _box.put(_kTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  // ==========================================================
  //  قراءة (async مع Isolate)
  // ==========================================================
  Future<List<Channel>?> loadChannels({bool checkValidity = false}) async {
    if (!_initialized) await init();

    try {
      final jsonStr = _box.get(_kChannelsJson);

      if (jsonStr == null || jsonStr is! String || jsonStr.isEmpty) {
        return _tryLoadLegacy();
      }

      final channels = await compute(_decodeChannels, jsonStr);
      return channels.isEmpty ? null : channels;
    } catch (_) {
      return null;
    }
  }

  List<Channel>? _tryLoadLegacy() {
    try {
      final raw = _box.get(_kChannelsLegacy);
      if (raw == null || raw is! List) return null;

      final channels = <Channel>[];
      for (final item in raw) {
        try {
          final map = Map<String, dynamic>.from(item as Map);
          channels.add(Channel.fromJson(map));
        } catch (_) {}
      }

      if (channels.isEmpty) return null;
      _box.delete(_kChannelsLegacy);
      return channels;
    } catch (_) {
      return null;
    }
  }

  bool hasSavedData() {
    if (!_initialized) return false;
    return _box.containsKey(_kChannelsJson) ||
        _box.containsKey(_kChannelsLegacy);
  }

  DateTime? getLastSaveTime() {
    if (!_initialized) return null;
    final ts = _box.get(_kTimestamp);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts as int);
  }

  int getSavedCount() {
    if (!_initialized) return 0;
    try {
      final raw = _box.get(_kChannelsJson);
      if (raw is! String || raw.isEmpty) return 0;
      return '"id"'.allMatches(raw).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    await _box.clear();
    await _box.put(_kVersion, _currentVersion);
    await _box.put(_kInitialCheckDone, false);
  }

  Map<String, dynamic> getInfo() {
    return {
      'ready': _initialized,
      'hasData': hasSavedData(),
      'count': getSavedCount(),
      'lastSave': getLastSaveTime()?.toIso8601String(),
      'initialCheckDone': hasInitialCheckDone(),
    };
  }

  Future<void> maintain() async {
    if (!_initialized) await init();
    try {
      final count = getSavedCount();
      if (count > maxSavedChannels) {
        await clear();
      }
    } catch (_) {}
  }

  Future<void> reset() async {
    await clear();
  }
}
