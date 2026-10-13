import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';

/// مزود المفضلة - يحفظ معرّفات القنوات المفضلة في Hive
class FavoritesNotifier extends StateNotifier<Set<String>> {
  static const String _boxName = 'favorites';
  static const String _keyIds = 'ids';

  late Box _box;
  bool _initialized = false;

  FavoritesNotifier() : super(<String>{}) {
    _init();
  }

  Future<void> _init() async {
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);

      final raw = _box.get(_keyIds);
      if (raw != null) {
        final List<dynamic> list = raw as List<dynamic>;
        state = list.map((e) => e.toString()).toSet();
      }
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  /// هل العنصر في المفضلة؟
  bool isFavorite(String id) => state.contains(id);

  /// إضافة/إزالة
  Future<void> toggle(String id) async {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
    await _save();
  }

  /// إضافة
  Future<void> add(String id) async {
    if (state.contains(id)) return;
    state = {...state, id};
    await _save();
  }

  /// إزالة
  Future<void> remove(String id) async {
    if (!state.contains(id)) return;
    state = {...state}..remove(id);
    await _save();
  }

  /// مسح الكل
  Future<void> clear() async {
    state = <String>{};
    await _save();
  }

  /// حفظ في Hive
  Future<void> _save() async {
    if (!_initialized) {
      try {
        await Hive.initFlutter();
        _box = await Hive.openBox(_boxName);
        _initialized = true;
      } catch (_) {
        return;
      }
    }
    try {
      await _box.put(_keyIds, state.toList());
    } catch (_) {
      // ignore
    }
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

/// قائمة القنوات المفضلة (كاملة)
final favoriteChannelsProvider = Provider<List<Channel>>((ref) {
  final ids = ref.watch(favoritesProvider);
  final all = ref.watch(_allChannelsProvider);
  if (ids.isEmpty) return const [];
  return all.where((c) => ids.contains(c.id)).toList();
});

/// قنوات البث المفضلة
final favoriteLiveProvider = Provider<List<Channel>>((ref) {
  final favorites = ref.watch(favoriteChannelsProvider);
  return favorites.where((c) => c.contentType == 'live').toList();
});

/// أفلام مفضلة
final favoriteMoviesProvider = Provider<List<Channel>>((ref) {
  final favorites = ref.watch(favoriteChannelsProvider);
  return favorites.where((c) => c.contentType == 'movie').toList();
});

/// مسلسلات مفضلة
final favoriteSeriesProvider = Provider<List<Channel>>((ref) {
  final favorites = ref.watch(favoriteChannelsProvider);
  return favorites.where((c) => c.contentType == 'series').toList();
});

/// عدد المفضلة الكلي
final favoriteCountProvider = Provider<int>((ref) {
  return ref.watch(favoritesProvider).length;
});

// Internal: يحصل على كل القنوات من playlist provider
final _allChannelsProvider = Provider<List<Channel>>((ref) {
  // استيراد ديناميكي لتجنب circular dependency
  // سنستخدم ref.read مع اسم الـ provider الرئيسي
  // (playlistProvider مُعرّف في ملف آخر)
  // ignore: invalid_use_of_protected_member
  try {
    final dynamic playlist = ref.watch(_playlistProviderRef);
    return playlist.allChannels as List<Channel>;
  } catch (_) {
    return const [];
  }
});

// مرجع مؤجل لـ playlistProvider
final _playlistProviderRef = Provider<dynamic>((ref) {
  // يتم تجاوزه من خارج الملف
  throw UnimplementedError('يجب override هذه القيمة');
});

// ==========================================================
//  دالة مساعدة: الوصول لقائمة القنوات من أي مكان
// ==========================================================
/// استخدمها في الشاشات للحصول على المفضلة كاملة
List<Channel> getFavoriteChannels({
  required Set<String> ids,
  required List<Channel> allChannels,
}) {
  if (ids.isEmpty) return const [];
  return allChannels.where((c) => ids.contains(c.id)).toList();
}

/// فلترة حسب النوع
List<Channel> filterByType(List<Channel> channels, String type) {
  return channels.where((c) => c.contentType == type).toList();
}
