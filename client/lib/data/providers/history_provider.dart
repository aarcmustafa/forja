import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';

/// مزود سجل المشاهدة
/// يحفظ:
/// - آخر 20 قناة مباشرة
/// - آخر فيلم واحد
/// - آخر مسلسل واحد
class HistoryState {
  final List<String> liveIds;   // آخر 20 قناة
  final String? lastMovieId;    // آخر فيلم
  final String? lastSeriesId;   // آخر مسلسل
  final bool isLoaded;

  const HistoryState({
    this.liveIds = const [],
    this.lastMovieId,
    this.lastSeriesId,
    this.isLoaded = false,
  });

  HistoryState copyWith({
    List<String>? liveIds,
    String? lastMovieId,
    String? lastSeriesId,
    bool? isLoaded,
    bool clearMovie = false,
    bool clearSeries = false,
  }) {
    return HistoryState(
      liveIds: liveIds ?? this.liveIds,
      lastMovieId: clearMovie ? null : (lastMovieId ?? this.lastMovieId),
      lastSeriesId: clearSeries ? null : (lastSeriesId ?? this.lastSeriesId),
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  static const String _boxName = 'watch_history';
  static const String _kLiveIds = 'live_ids';
  static const String _kMovieId = 'movie_id';
  static const String _kSeriesId = 'series_id';
  static const int _maxLive = 20;

  late Box _box;
  bool _initialized = false;

  HistoryNotifier() : super(const HistoryState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);

      final rawLive = _box.get(_kLiveIds);
      final List<String> liveIds = rawLive != null
          ? (rawLive as List).map((e) => e.toString()).toList()
          : <String>[];

      state = HistoryState(
        liveIds: liveIds,
        lastMovieId: _box.get(_kMovieId)?.toString(),
        lastSeriesId: _box.get(_kSeriesId)?.toString(),
        isLoaded: true,
      );
      _initialized = true;
    } catch (_) {
      state = state.copyWith(isLoaded: true);
      _initialized = false;
    }
  }

  /// تسجيل عنصر في السجل
  Future<void> record(Channel channel) async {
    switch (channel.contentType) {
      case 'live':
        await _recordLive(channel.id);
        break;
      case 'movie':
        await _recordMovie(channel.id);
        break;
      case 'series':
        await _recordSeries(channel.id);
        break;
    }
  }

  /// إضافة قناة مباشرة
  Future<void> _recordLive(String id) async {
    final list = [...state.liveIds];

    // نُزيل التكرار
    list.remove(id);

    // نُضيف في البداية
    list.insert(0, id);

    // نحفظ آخر 20 فقط
    if (list.length > _maxLive) {
      list.removeRange(_maxLive, list.length);
    }

    state = state.copyWith(liveIds: list);
    await _save(_kLiveIds, list);
  }

  /// حفظ آخر فيلم
  Future<void> _recordMovie(String id) async {
    state = state.copyWith(lastMovieId: id);
    await _save(_kMovieId, id);
  }

  /// حفظ آخر مسلسل
  Future<void> _recordSeries(String id) async {
    state = state.copyWith(lastSeriesId: id);
    await _save(_kSeriesId, id);
  }
  
  /// حفظ في Hive
  Future<void> _save(String key, dynamic value) async {
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
      await _box.put(key, value);
    } catch (_) {
      // ignore
    }
  }

  /// مسح سجل القنوات المباشرة
  Future<void> clearLive() async {
    state = state.copyWith(liveIds: []);
    if (_initialized) await _box.delete(_kLiveIds);
  }

  /// مسح كل السجل
  Future<void> clearAll() async {
    state = const HistoryState(isLoaded: true);
    if (_initialized) await _box.clear();
  }
}

// ==========================================================
//  Provider الرئيسي
// ==========================================================
final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier();
});

// ==========================================================
//  قوائم السجل (كاملة)
// ==========================================================
final recentLiveProvider = Provider<List<Channel>>((ref) {
  final ids = ref.watch(historyProvider).liveIds;
  if (ids.isEmpty) return const [];

  final all = ref.watch(playlistProvider).allChannels;
  final map = {for (final c in all) c.id: c};

  return ids
      .map((id) => map[id])
      .whereType<Channel>()
      .toList();
});

final lastMovieProvider = Provider<Channel?>((ref) {
  final id = ref.watch(historyProvider).lastMovieId;
  if (id == null) return null;

  final all = ref.watch(playlistProvider).allChannels;
  for (final c in all) {
    if (c.id == id && c.contentType == 'movie') return c;
  }
  return null;
});

final lastSeriesProvider = Provider<Channel?>((ref) {
  final id = ref.watch(historyProvider).lastSeriesId;
  if (id == null) return null;

  final all = ref.watch(playlistProvider).allChannels;
  for (final c in all) {
    if (c.id == id && c.contentType == 'series') return c;
  }
  return null;
});
