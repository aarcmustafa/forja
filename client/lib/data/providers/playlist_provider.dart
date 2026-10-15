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
  //  التحميل
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

    if (!forceRefresh) {
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

    state = state.copyWith(isLoading: true, clearError: true);

    final channels = await _fetchAll(urls);

    if (channels == null || channels.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'فشل تحميل القنوات',
      );
      return;
    }

    await _storage.saveChannels(channels);
    _setChannels(channels, workingStatus: saved);

    state = state.copyWith(
      isLoading: false,
      lastUpdate: DateTime.now(),
    );

    _startBackgroundCheckIfNeeded();
  }

  Future<void> _refreshInBackground(List<String> urls) async {
    state = state.copyWith(isRefreshing: true);

    try {
      final channels = await _fetchAll(urls, refreshCache: true);
      if (channels != null && channels.isNotEmpty) {
        await _storage.saveChannels(channels);
        _setChannels(channels, workingStatus: state.workingStatus);
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

  Future<List<Channel>?> _fetchAll(
    List<String> urls, {
    bool refreshCache = false,
  }) async {
    try {
      final List<Channel> all = [];
      for (final url in urls) {
        try {
          final channels = await _repository.loadFromUrl(
            url,
            forceRefresh: refreshCache,
          );
          all.addAll(channels);
        } catch (e) {
          // ignore: avoid_print
          print('فشل تحميل $url: $e');
        }
      }
      if (all.isEmpty) return null;

      final sportOnly = all.where((c) => _isSportChannel(c)).toList();

      return _removeDuplicates(sportOnly);
    } catch (e) {
      // ignore: avoid_print
      print('خطأ في الجلب: $e');
      return null;
    }
  }

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
  //  ✅ وضع علامة "ميتة" على قناة (من المشغل)
  // ==========================================================
  /// تُستدعى من player_screen عند فشل البث
  Future<void> markDeadByUrl(String streamUrl) async {
    try {
      final channel = state.allChannels.firstWhere(
        (c) => c.streamUrl == streamUrl,
        orElse: () => Channel(
          id: '',
          name: '',
          streamUrl: '',
        ),
      );

      if (channel.id.isEmpty) return;

      final newStatus = <String, bool>{...state.workingStatus};
      newStatus[channel.id] = false;

      state = state.copyWith(workingStatus: newStatus);

      _applyFilters();

      // ignore: avoid_print
      print('Marked dead: ${channel.name}');
    } catch (_) {
      // تجاهل الأخطاء
    }
  }

  // ==========================================================
  //  الفحص الخلفي
  // ==========================================================
  void _startBackgroundCheckIfNeeded() {
    if (_backgroundCheckStarted) return;
    if (state.allChannels.isEmpty) return;

    _backgroundCheckStarted = true;

    Future.delayed(const Duration(seconds: 5), () {
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

        if (newWorkingStatus.length % 50 == 0) {
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

    // 1) الرياضة فقط
    filtered = filtered.where((c) => _isSportChannel(c)).toList();

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

    state = state.copyWith(filteredChannels: filtered);
  }

  // ==========================================================
  //  مساعدات
  // ==========================================================
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
        final name = sub.name.toLowerCase();
        return g.contains(s) ||
            n.contains(s) ||
            g.contains(name) ||
            n.contains(name);
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
