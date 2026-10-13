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
