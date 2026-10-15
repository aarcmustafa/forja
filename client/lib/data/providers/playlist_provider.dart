import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/channel.dart';
import '../models/category.dart';
import '../repositories/m3u_repository.dart';
import '../local/local_storage.dart';
import '../services/stream_checker.dart';
import '../../features/settings/settings_screen.dart';

// ==========================================================
//  Providers أساسية
// ==========================================================
final m3uRepositoryProvider = Provider<M3uRepository>((ref) {
  final repo = M3uRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage();
});

final streamCheckerProvider = Provider<StreamChecker>((ref) {
  final checker = StreamChecker();
  ref.onDispose(() => checker.dispose());
  return checker;
});

// ==========================================================
//  حالة القنوات
// ==========================================================
class PlaylistState {
  final List<Channel> allChannels;
  final List<Channel> filteredChannels;
  final List<Category> categories;
  final Map<String, bool> workingStatus;
  final String? selectedCategorySlug;
  final String? selectedSubCategorySlug;
  final String searchQuery;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isInitialChecking;
  final int initialCheckDone;
  final int initialCheckTotal;
  final String? error;
  final DateTime? lastUpdate;

  const PlaylistState({
    this.allChannels = const [],
    this.filteredChannels = const [],
    this.categories = const [],
    this.workingStatus = const {},
    this.selectedCategorySlug,
    this.selectedSubCategorySlug,
    this.searchQuery = '',
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isInitialChecking = false,
    this.initialCheckDone = 0,
    this.initialCheckTotal = 0,
    this.error,
    this.lastUpdate,
  });

  PlaylistState copyWith({
    List<Channel>? allChannels,
    List<Channel>? filteredChannels,
    List<Category>? categories,
    Map<String, bool>? workingStatus,
    String? selectedCategorySlug,
    String? selectedSubCategorySlug,
    bool clearSelectedCategory = false,
    bool clearSelectedSubCategory = false,
    String? searchQuery,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isInitialChecking,
    int? initialCheckDone,
    int? initialCheckTotal,
    String? error,
    bool clearError = false,
    DateTime? lastUpdate,
  }) {
    return PlaylistState(
      allChannels: allChannels ?? this.allChannels,
      filteredChannels: filteredChannels ?? this.filteredChannels,
      categories: categories ?? this.categories,
      workingStatus: workingStatus ?? this.workingStatus,
      selectedCategorySlug: clearSelectedCategory
          ? null
          : (selectedCategorySlug ?? this.selectedCategorySlug),
      selectedSubCategorySlug: clearSelectedSubCategory
          ? null
          : (selectedSubCategorySlug ?? this.selectedSubCategorySlug),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isInitialChecking: isInitialChecking ?? this.isInitialChecking,
      initialCheckDone: initialCheckDone ?? this.initialCheckDone,
      initialCheckTotal: initialCheckTotal ?? this.initialCheckTotal,
      error: clearError ? null : (error ?? this.error),
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

// ==========================================================
//  Notifier — البداية
// ==========================================================
class PlaylistNotifier extends StateNotifier<PlaylistState> {
  final M3uRepository _repository;
  final LocalStorage _storage;
  final StreamChecker _checker;

  bool _filterAdult = true;
  bool _backgroundCheckStarted = false;
  bool _initialCheckInProgress = false;

  static const int firstBatchTarget = 300;

  PlaylistNotifier(this._repository, this._storage, this._checker)
      : super(const PlaylistState());

  void setAdultFilter(bool value) {
    if (_filterAdult == value) return;
    _filterAdult = value;
    _applyFilters();
  }

  void pauseBackgroundCheck() => _checker.pause();
  void resumeBackgroundCheck() => _checker.resume();
  // ==========================================================
//  التحميل الرئيسي (تحميل متدرج + فحص أولي)
// ==========================================================
Future<void> loadPlaylists(
  List<String> urls, {
  bool forceRefresh = false,
}) async {
  if (urls.isEmpty) {
    state = state.copyWith(
      isLoading: false,
      error: 'لا توجد روابط M3U للتحميل',
    );
    return;
  }

  await _storage.init();
  await _checker.init();

  final saved = await _checker.loadResults();

  // 1) محاولة التحميل من الكاش أولاً
  if (!forceRefresh) {
    final cached = await _storage.loadChannels();
    if (cached != null && cached.isNotEmpty) {
      _setChannels(cached, workingStatus: saved);
      state = state.copyWith(
        isLoading: false,
        lastUpdate: _storage.getLastSaveTime(),
      );

      _runInitialCheckIfNeeded(saved);
      _refreshInBackground(urls);
      return;
    }
  }

  // 2) تحميل من الشبكة مع عرض متدرج
  state = state.copyWith(isLoading: true, clearError: true);

  final channels = await _fetchAllStreaming(
    urls,
    refreshCache: forceRefresh,
  );

  if (channels == null || channels.isEmpty) {
    state = state.copyWith(
      isLoading: false,
      isLoadingMore: false,
      error: 'فشل تحميل القنوات',
    );
    return;
  }

  await _storage.saveChannels(channels);
  _setChannels(channels, workingStatus: saved);

  state = state.copyWith(
    isLoading: false,
    isLoadingMore: false,
    lastUpdate: DateTime.now(),
  );

  _runInitialCheckIfNeeded(saved);
  _startBackgroundCheckIfNeeded();
}

// ==========================================================
//  التحميل المتدرج (Stream من Futures)
// ==========================================================
Future<List<Channel>?> _fetchAllStreaming(
  List<String> urls, {
  bool refreshCache = false,
}) async {
  final List<Channel> all = [];
  bool firstDelivered = false;

  final futures = urls.map((url) async {
    try {
      return await _repository.loadFromUrl(
        url,
        forceRefresh: refreshCache,
      );
    } catch (e) {
      // ignore: avoid_print
      print('فشل تحميل $url: $e');
      return <Channel>[];
    }
  }).toList();

  if (futures.isEmpty) return null;

  await for (final channels in Stream.fromFutures(futures)) {
    all.addAll(channels);

    final sportOnly = _removeDuplicates(
      all.where(_isSportChannel).toList(),
    );

    if (sportOnly.isEmpty) continue;

    // أول دفعة: اعرض فوراً (بحد أقصى 300)
    if (!firstDelivered) {
      firstDelivered = true;
      final initial = sportOnly.length > firstBatchTarget
          ? sportOnly.take(firstBatchTarget).toList()
          : sportOnly;

      _setChannels(initial, workingStatus: state.workingStatus);

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: sportOnly.length > firstBatchTarget,
      );
    } else {
      _setChannels(sportOnly, workingStatus: state.workingStatus);
    }
  }

  if (all.isEmpty) return null;

  final finalList = _removeDuplicates(
    all.where(_isSportChannel).toList(),
  );

  if (!firstDelivered && finalList.isNotEmpty) {
    _setChannels(finalList, workingStatus: state.workingStatus);
    state = state.copyWith(isLoading: false);
  }

  return finalList;
}

// ==========================================================
//  تحديث في الخلفية
// ==========================================================
Future<void> _refreshInBackground(List<String> urls) async {
  state = state.copyWith(isRefreshing: true);

  try {
    final futures = urls.map((url) async {
      try {
        return await _repository.loadFromUrl(url, forceRefresh: true);
      } catch (_) {
        return <Channel>[];
      }
    }).toList();

    final List<Channel> all = [];
    await for (final channels in Stream.fromFutures(futures)) {
      all.addAll(channels);
    }

    final deduped = _removeDuplicates(
      all.where(_isSportChannel).toList(),
    );

    if (deduped.isNotEmpty) {
      await _storage.saveChannels(deduped);
      _setChannels(deduped, workingStatus: state.workingStatus);
      state = state.copyWith(
        isRefreshing: false,
        lastUpdate: DateTime.now(),
      );
    } else {
      state = state.copyWith(isRefreshing: false);
    }
  } catch (_) {
    state = state.copyWith(isRefreshing: false);
  }
}
  // ==========================================================
//  الفحص الأولي (أول تشغيل فقط)
// ==========================================================
Future<void> _runInitialCheckIfNeeded(Map<String, bool> saved) async {
  if (_storage.hasInitialCheckDone()) return;
  if (_initialCheckInProgress) return;
  if (state.allChannels.isEmpty) return;

  _initialCheckInProgress = true;

  final total = state.allChannels.length;

  state = state.copyWith(
    isInitialChecking: true,
    initialCheckDone: 0,
    initialCheckTotal: total,
  );

  try {
    await _checker.checkInitial(
      state.allChannels,
      batchSize: 20,
      onProgress: (done, ttl) {
        state = state.copyWith(
          initialCheckDone: done,
          initialCheckTotal: ttl,
        );
      },
      onBatch: (batchResults) {
        final merged = <String, bool>{
          ...saved,
          ...state.workingStatus,
          ...batchResults,
        };
        state = state.copyWith(workingStatus: merged);
        _applyFilters();
      },
    );

    await _storage.markInitialCheckDone();
    state = state.copyWith(isInitialChecking: false);
  } catch (e) {
    // ignore: avoid_print
    print('خطأ في الفحص الأولي: $e');
    state = state.copyWith(isInitialChecking: false);
  } finally {
    _initialCheckInProgress = false;
  }
}

// ==========================================================
//  الفحص الخلفي للقنوات الجديدة
// ==========================================================
void _startBackgroundCheckIfNeeded() {
  if (_backgroundCheckStarted) return;
  if (state.allChannels.isEmpty) return;
  if (_initialCheckInProgress) return;

  _backgroundCheckStarted = true;

  Future.delayed(const Duration(seconds: 5), () {
    if (_initialCheckInProgress) {
      _backgroundCheckStarted = false;
      _startBackgroundCheckIfNeeded();
      return;
    }
    _runBackgroundCheck();
  });
}

Future<void> _runBackgroundCheck() async {
  final channels = state.allChannels;
  if (channels.isEmpty) return;

  await _checker.startBackgroundCheck(
    channels,
    alreadyChecked: state.workingStatus,
    onResult: (channelId, isWorking) {
      final merged = <String, bool>{
        ...state.workingStatus,
        channelId: isWorking,
      };
      state = state.copyWith(workingStatus: merged);

      if (merged.length % 50 == 0) {
        _applyFilters();
      }
    },
  );

  _applyFilters();
}

// ==========================================================
//  وضع علامة "ميتة" على قناة
// ==========================================================
Future<void> markDeadByUrl(String streamUrl) async {
  try {
    final channel = state.allChannels.firstWhere(
      (c) => c.streamUrl == streamUrl,
      orElse: () => const Channel(
        id: '',
        name: '',
        streamUrl: '',
      ),
    );

    if (channel.id.isEmpty) return;

    final newStatus = <String, bool>{...state.workingStatus};
    newStatus[channel.id] = false;

    state = state.copyWith(workingStatus: newStatus);
    await _checker.markDead(channel.id);
    _applyFilters();
  } catch (_) {}
}
  // ==========================================================
//  البناء والفلترة
// ==========================================================
void _setChannels(
  List<Channel> channels, {
  Map<String, bool>? workingStatus,
}) {
  final categories = _buildCategoriesFromChannels(channels);
  state = state.copyWith(
    allChannels: channels,
    categories: categories,
    workingStatus: workingStatus ?? state.workingStatus,
  );
  _applyFilters();
}

// ==========================================================
//  الترتيب (beIN أولاً، VOD آخراً)
// ==========================================================
List<Channel> _sortChannels(List<Channel> channels) {
  final sorted = List<Channel>.from(channels);
  sorted.sort((a, b) => _sortPriority(a).compareTo(_sortPriority(b)));
  return sorted;
}

int _sortPriority(Channel c) {
  final name = c.name.toLowerCase();
  final group = c.group.toLowerCase();
  final text = '$group $name';

  // 1) VOD — آخر شيء
  if (text.contains('vod') ||
      text.contains('في إتش دي') ||
      text.contains('فيديو حسب الطلب')) {
    if (text.contains('bein') || text.contains('بين')) {
      return 9999;
    }
    return 9500;
  }

  // 2) beIN Sports (غير VOD) — أول شيء
  final isBein = text.contains('bein') ||
      text.contains('بين سبورت') ||
      text.contains('بين سبور') ||
      text.contains('بين');

  if (isBein) {
    final match = RegExp(r'(\d{1,3})').firstMatch(name);
    final num = int.tryParse(match?.group(1) ?? '0') ?? 0;

    if (name.contains('max') || name.contains('ماكس')) {
      return 1100 + num;
    }
    if (name.contains('premium') || name.contains('بريميوم')) {
      return 1150 + num;
    }
    return 1000 + num;
  }

  // 3) الباقات الرياضية الأخرى
  if (text.contains('ssc')) return 2000;
  if (text.contains('ad sport') ||
      text.contains('abu dhabi sport') ||
      text.contains('أبوظبي الرياضية')) {
    return 2100;
  }
  if (text.contains('alkass') || text.contains('الكأس')) return 2200;
  if (text.contains('dubai sport') ||
      text.contains('دبي الرياضية')) {
    return 2300;
  }
  if (text.contains('ksa sport') ||
      text.contains('السعودية الرياضية') ||
      text.contains('saudi sport')) {
    return 2400;
  }
  if (text.contains('alwan') || text.contains('ألوان')) return 2500;
  if (text.contains('shahid')) return 2600;
  if (text.contains('1001')) return 2700;
  if (text.contains('sky sport')) return 2800;
  if (text.contains('espn')) return 2850;
  if (text.contains('dazn')) return 2900;

  // 4) الباقي
  return 5000 + (name.hashCode.abs() % 4000);
}

// ==========================================================
//  الفلاتر
// ==========================================================
void selectCategory(String? slug) {
  if (slug == null) {
    state = state.copyWith(
      clearSelectedCategory: true,
      clearSelectedSubCategory: true,
    );
    _applyFilters();
    return;
  }
  state = state.copyWith(
    selectedCategorySlug: slug,
    clearSelectedSubCategory: true,
  );
  _applyFilters();
}

void selectSubCategory(String? slug) {
  if (slug == null) {
    state = state.copyWith(clearSelectedSubCategory: true);
  } else {
    state = state.copyWith(selectedSubCategorySlug: slug);
  }
  _applyFilters();
}

void search(String query) {
  state = state.copyWith(searchQuery: query);
  _applyFilters();
}

void _applyFilters() {
  List<Channel> filtered = List.from(state.allChannels);

  // 1) الرياضة فقط
  filtered = filtered.where(_isSportChannel).toList();

  // 2) فلتر البالغين
  if (_filterAdult) {
    filtered = filtered
        .where((c) => !isAdultContent(c.name, c.group))
        .toList();
  }

  // 3) إخفاء الميتة
  if (state.workingStatus.isNotEmpty) {
    filtered = filtered.where((c) {
      final status = state.workingStatus[c.id];
      return status == null || status == true;
    }).toList();
  }

  // 4) الباقة الفرعية
  if (state.selectedSubCategorySlug != null) {
    final slug = state.selectedSubCategorySlug!.toLowerCase();
    final selectedCat = state.categories.firstWhere(
      (cat) => cat.slug == state.selectedCategorySlug,
      orElse: () => const Category(id: '', name: '', slug: ''),
    );
    String? subName;
    for (final s in selectedCat.subCategories) {
      if (s.slug == slug) {
        subName = s.name.toLowerCase();
        break;
      }
    }
    filtered = filtered.where((c) {
      final g = c.group.toLowerCase();
      final n = c.name.toLowerCase();
      return g.contains(slug) ||
          n.contains(slug) ||
          (subName != null &&
              (g.contains(subName) || n.contains(subName)));
    }).toList();
  }

  // 5) البحث
  if (state.searchQuery.trim().isNotEmpty) {
    final q = state.searchQuery.trim().toLowerCase();
    filtered = filtered
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.group.toLowerCase().contains(q))
        .toList();
  }

  // 6) الترتيب
  filtered = _sortChannels(filtered);

  state = state.copyWith(filteredChannels: filtered);
}
    // ==========================================================
  //  مساعدات
  // ==========================================================
  bool _isSportChannel(Channel c) {
    if (c.category == 'sport') return true;

    final name = c.name.toLowerCase();
    final group = c.group.toLowerCase();
    final text = '$name $group';

    const sportKeywords = [
      'bein', 'sport', 'ssc', 'رياض', 'كورة', 'alkass',
      'dubai sport', 'ad sport', 'ksa sport', 'alwan',
      'sky sport', 'espn', 'dazn', 'nba', 'nfl',
      'shahid sport', 'shasha', '1001', 'sportv',
      'فورمولا', 'moto', 'ufc', 'wwe', 'fight',
      'fifa', 'uefa', 'caf', 'afc',
    ];

    for (final keyword in sportKeywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }

  List<Channel> _removeDuplicates(List<Channel> channels) {
    final Map<String, Channel> unique = {};
    for (final ch in channels) {
      final key = _normalizeName(ch.name);
      if (!unique.containsKey(key)) {
        unique[key] = ch;
      } else {
        final existing = unique[key]!;
        if (ch.priority > existing.priority) unique[key] = ch;
      }
    }
    return unique.values.toList();
  }

  String _normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '')
        .trim();
  }

  List<Category> _buildCategoriesFromChannels(List<Channel> channels) {
    const defaultSubs = [
      SubCategory(id: '1', name: 'beIN Sports', slug: 'bein', order: 1),
      SubCategory(id: '2', name: 'SSC', slug: 'ssc', order: 2),
      SubCategory(id: '3', name: 'AD Sports', slug: 'adsports', order: 3),
      SubCategory(id: '4', name: 'Al Kass', slug: 'alkass', order: 4),
      SubCategory(id: '5', name: 'Dubai Sports', slug: 'dubai', order: 5),
      SubCategory(id: '6', name: 'KSA Sports', slug: 'ksa', order: 6),
      SubCategory(id: '7', name: 'Alwan', slug: 'alwan', order: 7),
      SubCategory(id: '8', name: 'Shahid', slug: 'shahid', order: 8),
      SubCategory(id: '9', name: '1001', slug: '1001', order: 9),
    ];

    final subs = <SubCategory>[];
    for (final sub in defaultSubs) {
      final count = channels.where((c) {
        final g = c.group.toLowerCase();
        final n = c.name.toLowerCase();
        final s = sub.slug.toLowerCase();
        final subName = sub.name.toLowerCase();
        return g.contains(s) ||
            n.contains(s) ||
            g.contains(subName) ||
            n.contains(subName);
      }).length;

      if (count > 0) {
        subs.add(sub.copyWith(channelsCount: count));
      }
    }

    return [
      Category(
        id: 'sport',
        name: 'رياضة',
        slug: 'sport',
        iconName: 'sports',
        order: 1,
        subCategories: subs,
        channelsCount: channels.length,
      ),
    ];
  }

  Future<void> refresh(List<String> urls) async {
    _repository.clearCache();
    await _storage.resetInitialCheck();
    _backgroundCheckStarted = false;
    await loadPlaylists(urls, forceRefresh: true);
  }
}

// ==========================================================
//  Provider الرئيسي
// ==========================================================
final playlistProvider =
    StateNotifierProvider<PlaylistNotifier, PlaylistState>((ref) {
  final repo = ref.watch(m3uRepositoryProvider);
  final storage = ref.watch(localStorageProvider);
  final checker = ref.watch(streamCheckerProvider);
  final notifier = PlaylistNotifier(repo, storage, checker);

  final settings = ref.read(settingsProvider);
  notifier.setAdultFilter(settings.filterAdult);

  ref.listen<SettingsState>(settingsProvider, (prev, next) {
    if (prev == null) return;
    if (prev.filterAdult != next.filterAdult) {
      notifier.setAdultFilter(next.filterAdult);
    }
  });

  return notifier;
});

// ==========================================================
//  Providers مساعدة
// ==========================================================
final filteredChannelsProvider = Provider<List<Channel>>((ref) {
  return ref.watch(playlistProvider).filteredChannels;
});

final categoriesProvider = Provider<List<Category>>((ref) {
  return ref.watch(playlistProvider).categories;
});

final isLoadingProvider = Provider<bool>((ref) {
  return ref.watch(playlistProvider).isLoading;
});

final isRefreshingProvider = Provider<bool>((ref) {
  return ref.watch(playlistProvider).isRefreshing;
});

final errorProvider = Provider<String?>((ref) {
  return ref.watch(playlistProvider).error;
});

final selectedCategoryProvider = Provider<String?>((ref) {
  return ref.watch(playlistProvider).selectedCategorySlug;
});

final selectedSubCategoryProvider = Provider<String?>((ref) {
  return ref.watch(playlistProvider).selectedSubCategorySlug;
});

final searchQueryProvider = Provider<String>((ref) {
  return ref.watch(playlistProvider).searchQuery;
});

final lastUpdateProvider = Provider<DateTime?>((ref) {
  return ref.watch(playlistProvider).lastUpdate;
});

final isLoadingMoreProvider = Provider<bool>((ref) {
  return ref.watch(playlistProvider).isLoadingMore;
});

final isInitialCheckingProvider = Provider<bool>((ref) {
  return ref.watch(playlistProvider).isInitialChecking;
});
