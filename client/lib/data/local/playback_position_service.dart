import 'package:hive_flutter/hive_flutter.dart';

/// خدمة حفظ موضع التشغيل — تستخدم Hive
class PlaybackPositionService {
  static const String _boxName = 'playback_positions';
  static const String _kPrefix = 'pos_';
  static const String _kTimestamp = 'ts_';

  /// لا تُحفظ المواضع أقل من 30 ثانية
  static const Duration minPositionToSave = Duration(seconds: 30);

  /// لا تُحفظ إذا المتبقي أقل من 60 ثانية (يعني شبه انتهى)
  static const Duration minRemainingToSave = Duration(seconds: 60);

  /// مدة انتهاء الصلاحية (30 يوماً)
  static const Duration maxAge = Duration(days: 30);

  Box? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  /// حفظ موضع التشغيل
  Future<void> save({
    required String itemId,
    required Duration position,
    required Duration duration,
  }) async {
    if (!_initialized) await init();
    if (_box == null) return;

    try {
      // تجاهل المواضع القصيرة جداً
      if (position < minPositionToSave) {
        await clear(itemId);
        return;
      }

      // إذا اقترب من النهاية، احذف (لأنه شاهد المقطع)
      if (duration > Duration.zero) {
        final remaining = duration - position;
        if (remaining < minRemainingToSave) {
          await clear(itemId);
          return;
        }
      }

      await _box!.put('$_kPrefix$itemId', position.inMilliseconds);
      await _box!.put(
        '$_kTimestamp$itemId',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// قراءة موضع التشغيل
  Future<Duration?> load(String itemId) async {
    if (!_initialized) await init();
    if (_box == null) return null;

    try {
      final ms = _box!.get('$_kPrefix$itemId');
      if (ms == null) return null;

      // فحص الصلاحية
      final ts = _box!.get('$_kTimestamp$itemId');
      if (ts != null) {
        final savedAt = DateTime.fromMillisecondsSinceEpoch(ts as int);
        if (DateTime.now().difference(savedAt) > maxAge) {
          await clear(itemId);
          return null;
        }
      }

      return Duration(milliseconds: ms as int);
    } catch (_) {
      return null;
    }
  }

  /// حذف موضع
  Future<void> clear(String itemId) async {
    if (!_initialized) await init();
    if (_box == null) return;
    try {
      await _box!.delete('$_kPrefix$itemId');
      await _box!.delete('$_kTimestamp$itemId');
    } catch (_) {}
  }

  /// مسح كل المواضع
  Future<void> clearAll() async {
    if (!_initialized) await init();
    if (_box == null) return;
    try {
      await _box!.clear();
    } catch (_) {}
  }

  /// عدد المواضع المحفوظة
  Future<int> getCount() async {
    if (!_initialized) await init();
    if (_box == null) return 0;
    try {
      return _box!.keys
          .where((k) => k.toString().startsWith(_kPrefix))
          .length;
    } catch (_) {
      return 0;
    }
  }
}
