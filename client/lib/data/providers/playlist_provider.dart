import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/channel.dart';
import '../models/category.dart';
import '../repositories/m3u_repository.dart';
import '../local/local_storage.dart';
import '../services/stream_checker.dart';
import '../../features/settings/settings_screen.dart';

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

class PlaylistNotifier extends StateNotifier<PlaylistState> {
  final M3uRepository _repository;
  final LocalStorage _storage;
  final StreamChecker _checker;
  bool _filterAdult = false;
  bool _backgroundCheckStarted = false;
  bool _refreshInProgress = false;

  PlaylistNotifier(this._repository, this._storage, this._checker)
      : super(const PlaylistState());

  void setAdultFilter(bool value) {
    if (_filterAdult == value) return;
    _filterAdult = value;
    _applyFilters();
  }

  void pauseBackgroundCheck() => _checker.pause();
  void resumeBackgroundCheck() => _checker.resume();

  Future<void> loadPlaylists(
    List<String> urls, {
    bool forceRefresh = false,
  }) async {
    if (urls.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'لا توجد روابط M3U',
      );
      return;
    }

    await _storage.init();
    await _checker.init();

    // ✅ 1) اقرأ الكاش فوراً
    if (!forceRefresh) {
      final cached = _storage.loadChannels();
      if (cached != null && cached.isNotEmpty) {
        final saved = await _checker.loadResults();
        _setChannels(cached, workingStatus: saved);
        state = state.copyWith(
          isLoading: false,
          lastUpdate: _storage.getLastSaveTime(),
        );

        // تحديث في الخلفية
        Future.delayed(const Duration(seconds: 5), () {
          _refreshInBackground(urls);
        });

        // ✅ 2) ابدأ الفحص بعد 15 ثانية (بدل 45)
        Future.delayed(const Duration(seconds: 15), () {
          _startBackgroundCheckIfNeeded();
        });

        return;
      }
    }

    // لا يوجد كاش → تحميل كامل
    state = state.copyWith(isLoading: true, clearError: true);

    final channels = await _fetchAll(urls);

    if (channels == null || channels.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'فشل تحميل القنوات',
      );
      return;
    }

    // ✅ 3) احفظ فوراً + إجبار الكتابة
    await _storage.saveChannels(channels);

    final saved = await _checker.loadResults();
    _setChannels(channels, workingStatus: saved);

    state = state.copyWith(
      isLoading: false,
      lastUpdate: DateTime.now(),
    );

    _startBackgroundCheckIfNeeded();
  }

  Future<void> _refreshInBackground(List<String> urls) async {
    if (_refreshInProgress) return;
    _refreshInProgress = true;
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
    } finally {
      _refreshInProgress = false;
    }
  }

  Future<List<Channel>?> _fetchAll(
    List<String> urls, {
    bool refreshCache = false,
  }) async {
    try {
      final all = <Channel>[];
      const batchSize = 4;

      for (int i = 0; i < urls.length; i += batchSize) {
        final batch = urls.skip(i).take(batchSize).toList();
        final results = await Future.wait(
          batch.map((url) async {
            try {
              return await _repository.loadFromUrl(
                url,
                forceRefresh: refreshCache,
              );
            } catch (e) {
              return <Channel>[];
            }
          }),
        );

        for (final list in results) {
          all.addAll(list);
        }
      }

      if (all.isEmpty) return null;

      final sportOnly = all.where((c) => _isSportChannel(c)).toList();
      return _removeDuplicates(sportOnly);
    } catch (e) {
      return null;
    }
  }

  // ==========================================================
  //  ✅ فلتر صارم — رياضة فقط
  // ==========================================================
  bool _isSportChannel(Channel c) {
    final name = c.name.toLowerCase();
    final group = c.group.toLowerCase();
    final text = '$name $group';

    // ✅ 1) كلمات ممنوعة (غير رياضية)
    const excludeKeywords = [
      'quran', 'قرآن', 'إسلام', 'دين', 'religious', 'prayer',
      'movie', 'cinema', 'فيلم', 'أفلام', 'film',
      'series', 'مسلسل', 'drama', 'دراما',
      'kids', 'أطفال', 'cartoon', 'كرتون',
      'music', 'أغاني', 'موسيقى',
      'news', 'أخبار', 'إخبارية',
      'cooking', 'طبخ', 'food',
      'fashion', 'أزياء',
      'shopping', 'تسوق',
      'general', 'عامة',
    ];

    for (final k in excludeKeywords) {
      if (text.contains(k)) return false;
    }

    // ✅ 2) كلمات رياضية مطلوبة
    const sportKeywords = [
      // علامات رياضية
      'bein', 'ssc', 'alkass', 'alwan', 'shahid sport',
      'ad sport', 'adsport', 'abu dhabi sport',
      'dubai sport', 'ksa sport', 'saudi sport',
      'al kass', 'shasha sport', '1001 sport',
      'sportv', 'sport tv', 'sky sport', 'espn',
      'dazn', 'nba', 'nfl', 'ufc', 'wwe',
      'fifa', 'uefa', 'caf', 'afc', 'f1',
      'formula', 'moto gp', 'motogp',
      // كلمات عربية
      'رياض', 'رياضية', 'كورة', 'كرة',
      'الدوري', 'دوري',
      'مباريات', 'مباراة',
      // الدوريات
      'premier', 'laliga', 'bundesliga', 'ligue',
      'serie a', 'world cup', 'euro',
    ];

    for (final k in sportKeywords) {
      if (text.contains(k)) return true;
    }

    return false;
  }

  // ==========================================================
  //  ✅ ترتيب القنوات — الشغالة أولاً + الباقات + الجودة
  // ==========================================================
  void _setChannels(
    List<Channel> channels, {
    Map<String, bool>? workingStatus,
  }) {
    final sorted = _sortSportsChannels(channels);
    final categories = _buildCategoriesFromChannels(sorted);
    state = state.copyWith(
      allChannels: sorted,
      categories: categories,
      workingStatus: workingStatus ?? state.workingStatus,
    );
    _applyFilters();
  }

  List<Channel> _sortSportsChannels(List<Channel> channels) {
    const packageOrder = <String>[
      'bein',
      'alwan',
      'ad sport', 'adsport', 'abu dhabi',
      'alkass', 'al kass',
      'premier', 'epl',
      'bundesliga',
      'laliga', 'la liga',
      'ligue1', 'ligue 1',
    ];

    int packageRank(Channel c) {
      final text = '${c.name.toLowerCase()} ${c.group.toLowerCase()}';
      for (int i = 0; i < packageOrder.length; i++) {
        if (text.contains(packageOrder[i])) return i;
      }
      return 999;
    }

    int qualityRank(String name) {
      final lower = name.toLowerCase();
      if (lower.contains('tod')) return 9999;
      if (lower.contains('8k')) return 8000;
      if (lower.contains('4k') || lower.contains('uhd')) return 7000;
      if (lower.contains('fhd')) return 6000;
      if (lower.contains('hd')) return 5000;
      return 4000;
    }

    int extractNumber(String name) {
      final match = RegExp(r'(\d+)').firstMatch(name);
      if (match != null) return int.tryParse(match.group(1)!) ?? 9999;
      return 9999;
    }

    final sorted = List<Channel>.from(channels);
    sorted.sort((a, b) {
      // ✅ 1) الشغالة أولاً (الأهم!)
      final wa = state.workingStatus[a.id];
      final wb = state.workingStatus[b.id];

      // working=true → rank 0
      // unknown → rank 1
      // working=false → rank 2 (سيبقى في النهاية)
      final ra = wa == true ? 0 : (wa == false ? 2 : 1);
      final rb = wb == true ? 0 : (wb == false ? 2 : 1);
      if (ra != rb) return ra.compareTo(rb);

      // ✅ 2) الباقة
      final pa = packageRank(a);
      final pb = packageRank(b);
      if (pa != pb) return pa.compareTo(pb);

      // ✅ 3) الجودة
      final qa = qualityRank(a.name);
      final qb = qualityRank(b.name);
      if (qa != qb) return qa.compareTo(qb);

      // ✅ 4) الرقم
      final na = extractNumber(a.name);
      final nb = extractNumber(b.name);
      if (na != nb) return na.compareTo(nb);

      return a.name.compareTo(b.name);
    });

    return sorted;
  }
  
  void _startBackgroundCheckIfNeeded() {
    if (_backgroundCheckStarted) return;
    if (state.allChannels.isEmpty) return;
    _backgroundCheckStarted = true;
    _runBackgroundCheck();
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

        // ✅ إعادة الترتيب كل 20 نتيجة
        if (newWorkingStatus.length % 20 == 0) {
          final reSorted = _sortSportsChannels(state.allChannels);
          state = state.copyWith(allChannels: reSorted);
          _applyFilters();
        }
      },
    );

    // إعادة الترتيب النهائية
    final finalSorted = _sortSportsChannels(state.allChannels);
    state = state.copyWith(allChannels: finalSorted);
    _applyFilters();
  }

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

    if (_filterAdult) {
      filtered = filtered
          .where((c) => !isAdultContent(c.name, c.group))
          .toList();
    }

    // ✅ لا نخفي الميتة تلقائياً، فقط نرتبها في النهاية
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
      SubCategory(id: '2', name: 'ألوان', slug: 'alwan', order: 2),
      SubCategory(id: '3', name: 'أبوظبي', slug: 'adsports', order: 3),
      SubCategory(id: '4', name: 'الكأس', slug: 'alkass', order: 4),
      SubCategory(id: '5', name: 'الإنجليزي', slug: 'premier', order: 5),
      SubCategory(id: '6', name: 'الألماني', slug: 'bundesliga', order: 6),
      SubCategory(id: '7', name: 'الإسباني', slug: 'laliga', order: 7),
      SubCategory(id: '8', name: 'الفرنسي', slug: 'ligue1', order: 8),
      SubCategory(id: '9', name: 'SSC', slug: 'ssc', order: 9),
      SubCategory(id: '10', name: 'Shahid', slug: 'shahid', order: 10),
      SubCategory(id: '11', name: '1001', slug: '1001', order: 11),
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
