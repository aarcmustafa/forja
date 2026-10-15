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
  final double loadProgress;
  final String loadLabel;
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
    this.loadProgress = 0.0,
    this.loadLabel = 'جارٍ التحميل...',
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
    double? loadProgress,
    String? loadLabel,
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
      loadProgress: loadProgress ?? this.loadProgress,
      loadLabel: loadLabel ?? this.loadLabel,
      error: clearError ? null : (error ?? this.error),
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

// ==========================================================
//  Notifier
// ==========================================================
class PlaylistNotifier extends StateNotifier<PlaylistState> {
  final M3uRepository _repository;
  final LocalStorage _storage;
  final StreamChecker _checker;
  bool _filterAdult = true;
  bool _backgroundCheckStarted = false;

  Set<String> _sportIds = {};
  Set<String> _adultIds = {};

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
  //  ✅ علّم قناة كـ ميتة (عند فشل التشغيل)
  // ==========================================================
  Future<void> markDeadByUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final deadIds = state.allChannels
          .where((c) => c.streamUrl == url)
          .map((c) => c.id)
          .toList();

      if (deadIds.isEmpty) return;

      final newWorking = <String, bool>{...state.workingStatus};
      for (final id in deadIds) {
        newWorking[id] = false;
      }
      state = state.copyWith(workingStatus: newWorking);
      _applyFilters();

      await _checker.markDeadMultiple(deadIds);
    } catch (_) {}
  }

  /// علّم قناة كـ ميتة بـ ID
  Future<void> markDead(String channelId) async {
    if (channelId.isEmpty) return;
    try {
      final newWorking = <String, bool>{...state.workingStatus};
      newWorking[channelId] = false;
      state = state.copyWith(workingStatus: newWorking);
      _applyFilters();
      await _checker.markDead(channelId);
    } catch (_) {}
  }

  // ==========================================================
  //  التحميل الرئيسي
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
    final initialCheckDone = _storage.hasInitialCheckDone();

    // 1) عرض Cache فوراً إذا تم الفحص الأولي
    if (!forceRefresh && initialCheckDone) {
      final cached = await _storage.loadChannels();

      if (cached != null && cached.isNotEmpty) {
        _setChannels(cached, workingStatus: saved);
        state = state.copyWith(
          isLoading: false,
          lastUpdate: _storage.getLastSaveTime(),
        );
        _startBackgroundCheckIfNeeded();
        _refreshInBackground(urls);
        return;
      }
    }

    // 2) الفحص الأولي
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      loadProgress: 0.0,
      loadLabel: 'جارٍ تحميل القنوات...',
    );

    final channels = await _fetchAll(
      urls,
      onUrlProgress: (done, total) {
        state = state.copyWith(
          loadProgress: (done / total) * 0.3,
          loadLabel: 'تحميل القنوات ($done/$total)...',
        );
      },
    );

    if (channels == null || channels.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'فشل تحميل القنوات',
        loadProgress: 0.0,
      );
      return;
    }

    // 2-2) الفحص الأولي
    if (!initialCheckDone) {
      state = state.copyWith(
        loadProgress: 0.3,
        loadLabel: 'فحص ${channels.length} قناة...',
      );

      final checkResults = await _checker.checkInitial(
        channels,
        onProgress: (done, total) {
          final p = 0.3 + (done / total) * 0.65;
          state = state.copyWith(
            loadProgress: p,
            loadLabel: 'فحص القنوات ($done/$total)...',
          );
        },
      );

      final working = channels
          .where((c) => checkResults[c.id] == true)
          .toList();

      final sorted = _sortChannels(working);

      await _storage.saveChannels(sorted);
      await _storage.markInitialCheckDone();

      state = state.copyWith(
        loadProgress: 1.0,
        loadLabel: 'جارٍ العرض...',
      );

      _setChannels(sorted, workingStatus: checkResults);

      state = state.copyWith(
        isLoading: false,
        lastUpdate: DateTime.now(),
      );

      _startBackgroundCheckIfNeeded();
      return;
    }

    // 3) فحص تم لكن لا cache
    final sorted = _sortChannels(channels);
    await _storage.saveChannels(sorted);
    _setChannels(sorted, workingStatus: saved);

    state = state.copyWith(
      isLoading: false,
      lastUpdate: DateTime.now(),
    );

    _startBackgroundCheckIfNeeded();
  }

  Future<List<Channel>?> _fetchAll(
    List<String> urls, {
    bool refreshCache = false,
    void Function(int done, int total)? onUrlProgress,
  }) async {
    try {
      final List<Channel> all = [];
      final total = urls.length;

      for (int i = 0; i < urls.length; i++) {
        try {
          final channels = await _repository.loadFromUrl(
            urls[i],
            forceRefresh: refreshCache,
          );
          all.addAll(channels);
        } catch (_) {}
        onUrlProgress?.call(i + 1, total);
      }

      if (all.isEmpty) return null;

      final sportOnly = all.where((c) => _isSportChannel(c)).toList();
      return _removeDuplicates(sportOnly);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshInBackground(List<String> urls) async {
    state = state.copyWith(isRefreshing: true);

    try {
      final channels = await _fetchAll(urls, refreshCache: true);
      if (channels != null && channels.isNotEmpty) {
        final sorted = _sortChannels(channels);
        await _storage.saveChannels(sorted);
        _setChannels(sorted, workingStatus: state.workingStatus);
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

  bool _isSportChannel(Channel c) {
    if (c.category == 'sport') return true;

    final text = '${c.name.toLowerCase()} ${c.group.toLowerCase()}';

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

  // ==========================================================
  //  الترتيب: beIN أولاً + Live قبل VOD + جودة تصاعدية
  // ==========================================================
  List<Channel> _sortChannels(List<Channel> channels) {
    final list = List<Channel>.from(channels);
    list.sort(_compareChannels);
    return list;
  }

  int _compareChannels(Channel a, Channel b) {
    // 1) beIN أولاً
    final aBein = _isBeinChannel(a);
    final bBein = _isBeinChannel(b);
    if (aBein != bBein) return aBein ? -1 : 1;

    // 2) Live قبل VOD
    final aVod = _isVod(a);
    final bVod = _isVod(b);
    if (aVod != bVod) return aVod ? 1 : -1;

    // 3) الجودة تصاعدياً
    final qa = _qualityScore(a);
    final qb = _qualityScore(b);
    if (qa != qb) return qa.compareTo(qb);

    // 4) أبجدياً
    return a.name.compareTo(b.name);
  }

  bool _isBeinChannel(Channel c) {
    final t = '${c.name.toLowerCase()} ${c.group.toLowerCase()}';
    return t.contains('bein') || t.contains('بين');
  }

  bool _isVod(Channel c) {
    return c.contentType == 'movie' || c.contentType == 'series';
  }

  int _qualityScore(Channel c) {
    final t = '${c.name} ${c.streamUrl}'.toLowerCase();
    if (t.contains('4k') || t.contains('uhd')) return 4;
    if (t.contains('fhd') || t.contains('1080')) return 3;
    if (t.contains('720') || RegExp(r'\bhd\b').hasMatch(t)) {
      return 2;
    }
    return 1;
  }
  
  // ==========================================================
  //  الفحص الخلفي
  // ==========================================================
  void _startBackgroundCheckIfNeeded() {
    if (_backgroundCheckStarted) return;
    if (state.allChannels.isEmpty) return;

    _backgroundCheckStarted = true;

    Future.delayed(const Duration(seconds: 10), () {
      _runBackgroundCheck();
    });
  }

  Future<void> _runBackgroundCheck() async {
    final channels = state.allChannels;
    if (channels.isEmpty) return;

    final newWorkingStatus = <String, bool>{...state.workingStatus};

    await _checker.startBackgroundCheck(
      channels,
      alreadyChecked: state.workingStatus,
      onResult: (channelId, isWorking) {
        newWorkingStatus[channelId] = isWorking;
        state = state.copyWith(workingStatus: newWorkingStatus);

        if (newWorkingStatus.length % 100 == 0) {
          _applyFilters();
        }
      },
    );

    _applyFilters();
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

    if (_sportIds.isNotEmpty) {
      filtered = filtered.where((c) => _sportIds.contains(c.id)).toList();
    }

    if (_filterAdult && _adultIds.isNotEmpty) {
      filtered = filtered.where((c) => !_adultIds.contains(c.id)).toList();
    }

    if (state.workingStatus.isNotEmpty) {
      filtered = filtered.where((c) {
        final status = state.workingStatus[c.id];
        return status == null || status == true;
      }).toList();
    }

    if (state.selectedSubCategorySlug != null) {
      final slug = state.selectedSubCategorySlug!.toLowerCase();
      filtered = filtered.where((c) {
        final g = c.group.toLowerCase();
        final n = c.name.toLowerCase();
        return g.contains(slug) || n.contains(slug);
      }).toList();
    }

    if (state.searchQuery.trim().isNotEmpty) {
      final q = state.searchQuery.trim().toLowerCase();
      filtered = filtered.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.group.toLowerCase().contains(q);
      }).toList();
    }

    state = state.copyWith(filteredChannels: filtered);
  }

  void _setChannels(
    List<Channel> channels, {
    Map<String, bool>? workingStatus,
  }) {
    _precomputeSets(channels);
    state = state.copyWith(
      allChannels: channels,
      categories: _buildCategoriesFromChannels(channels),
      workingStatus: workingStatus ?? state.workingStatus,
    );
    _applyFilters();
  }

  void _precomputeSets(List<Channel> channels) {
    _sportIds = {};
    _adultIds = {};

    for (final c in channels) {
      if (_isSportChannel(c)) _sportIds.add(c.id);
      if (isAdultContent(c.name, c.group)) _adultIds.add(c.id);
    }
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
      int count = 0;
      final s = sub.slug.toLowerCase();
      final n = sub.name.toLowerCase();

      for (final c in channels) {
        final t = '${c.name.toLowerCase()} ${c.group.toLowerCase()}';
        if (t.contains(s) || t.contains(n)) count++;
      }

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
    await loadPlaylists(urls, forceRefresh: true);
  }

  Future<void> resetInitialCheck() async {
    await _storage.resetInitialCheck();
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

final loadProgressProvider = Provider<double>((ref) {
  return ref.watch(playlistProvider).loadProgress;
});

final loadLabelProvider = Provider<String>((ref) {
  return ref.watch(playlistProvider).loadLabel;
});
