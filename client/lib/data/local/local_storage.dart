import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';

/// خدمة التخزين المحلي باستخدام Hive
class LocalStorage {
  static const String _boxName = 'channels_cache';
  static const String _kChannels = 'channels_list';
  static const String _kTimestamp = 'saved_at';
  static const String _kVersion = 'schema_version';

  // ✅ رفعنا الإصدار → يمسح الكاش القديم مرة واحدة
  static const int _currentVersion = 2;

  // ✅ مدة صلاحية 30 يوماً
  static const Duration cacheValidity = Duration(days: 30);

  // ✅ حد أقصى كبير جداً (لن يُمسح)
  static const int maxSavedChannels = 500000;

  late Box _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);

    final savedVersion = _box.get(_kVersion, defaultValue: 0);
    if (savedVersion != _currentVersion) {
      await _box.clear();
      await _box.put(_kVersion, _currentVersion);
      await _box.flush();
    }

    _initialized = true;
  }

  bool get isReady => _initialized;

  // ==========================================================
  //  ✅ حفظ + إجبار الكتابة على القرص
  // ==========================================================
  Future<void> saveChannels(List<Channel> channels) async {
    if (!_initialized) await init();

    try {
      final List<Map<String, dynamic>> jsonList =
          channels.map((c) => c.toJson()).toList();

      await _box.put(_kChannels, jsonList);
      await _box.put(_kTimestamp, DateTime.now().millisecondsSinceEpoch);

      // ✅ الأهم: إجبار الكتابة على القرص فوراً
      await _box.flush();
    } catch (e) {
      // ignore: avoid_print
      print('فشل حفظ القنوات محلياً: $e');
    }
  }

  // ==========================================================
  //  قراءة القنوات من الذاكرة
  // ==========================================================
  List<Channel>? loadChannels({bool checkValidity = true}) {
    if (!_initialized) return null;

    try {
      if (checkValidity && !_isCacheValid()) {
        return null;
      }

      final raw = _box.get(_kChannels);
      if (raw == null) return null;

      final List<dynamic> list = raw as List<dynamic>;
      final channels = <Channel>[];

      for (final item in list) {
        try {
          final map = Map<String, dynamic>.from(item as Map);
          channels.add(Channel.fromJson(map));
        } catch (_) {}
      }

      return channels.isEmpty ? null : channels;
    } catch (e) {
      // ignore: avoid_print
      print('فشل قراءة القنوات محلياً: $e');
      return null;
    }
  }

  bool _isCacheValid() {
    try {
      final timestamp = _box.get(_kTimestamp);
      if (timestamp == null) return false;

      final savedAt = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
      final age = DateTime.now().difference(savedAt);

      return age < cacheValidity;
    } catch (_) {
      return false;
    }
  }

  bool hasSavedData() {
    if (!_initialized) return false;
    return _box.containsKey(_kChannels);
  }

  DateTime? getLastSaveTime() {
    if (!_initialized) return null;
    final ts = _box.get(_kTimestamp);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts as int);
  }

  int getSavedCount() {
    if (!_initialized) return 0;
    final raw = _box.get(_kChannels);
    if (raw == null) return 0;
    try {
      return (raw as List).length;
    } catch (_) {
      return 0;
    }
  }

  // ==========================================================
  //  حذف كل البيانات (يدوي فقط)
  // ==========================================================
  Future<void> clear() async {
    if (!_initialized) await init();
    await _box.clear();
    await _box.put(_kVersion, _currentVersion);
    await _box.flush();
  }

  // ==========================================================
  //  معلومات التخزين
  // ==========================================================
  Map<String, dynamic> getInfo() {
    return {
      'ready': _initialized,
      'hasData': hasSavedData(),
      'count': getSavedCount(),
      'lastSave': getLastSaveTime()?.toIso8601String(),
      'valid': _isCacheValid(),
      'limit': maxSavedChannels,
    };
  }

  // ==========================================================
  //  ✅ صيانة — لا تمسح الكاش
  // ==========================================================
  Future<void> maintain() async {
    // لا تفعل شيئاً — اترك الكاش كما هو
    // سيُحدَّث تلقائياً في الخلفية
  }

  // ==========================================================
  //  إعادة تعيين كاملة (يدوي فقط)
  // ==========================================================
  Future<void> reset() async {
    await clear();
  }
}
