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
  final bool isBackgroundChecking;

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
    this.isBackgroundChecking = false,
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
    bool? isBackgroundChecking,
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
      isBackgroundChecking:
          isBackgroundChecking ?? this.isBackgroundChecking,
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

  /// فلتر البالغين
  void setAdultFilter(bool value) {
    if (_filterAdult == value) return;
    _filterAdult = value;
    _applyFilters();
  }

  /// معرّفات القنوات التي فشل تشغيلها نهائياً (تُخفى فوراً)
  final Set<String> _deadIds = {};

  /// ✅ إخفاء قناة فشل تشغيلها نهائياً — تُستدعى من المشغّل
  Future<void> markDeadByUrl(String url) async {
    final ids = state.allChannels
        .where((c) => c.streamUrl == url)
        .map((c) => c.id)
        .toList();
    if (ids.isEmpty) return;

    _deadIds.addAll(ids);
    for (final id in ids) {
      await _checker.markResult(id, false);
    }
    state = state.copyWith(
      workingStatus: {
        ...state.workingStatus,
        for (final id in ids) id: false,
      },
    );
    _applyFilters();
  }

  /// إيقاف الفحص مؤقتاً (عند فتح مشغل الفيديو)
  void pauseBackgroundCheck() => _checker.pause();

  /// استئناف الفحص
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

    // قراءة نتائج الفحص المحفوظة
    final saved = await _checker.loadResults();

    if (!forceRefresh) {
      final cached = _storage.loadChannels();
      if (cached != null && cached.isNotEmpty) {
        _setChannels(cached, workingStatus: saved);
        state = state.copyWith(
          isLoading: false,
          lastUpdate: _storage.getLastSaveTime(),
        );

        // بدء الفحص الخلفي فوراً
        _startBackgroundCheckIfNeeded();

        // تحديث القنوات في الخلفية
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

    // بدء الفحص الخلفي
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
      return _removeDuplicates(all);
    } catch (e) {
      // ignore: avoid_print
      print('خطأ في الجلب: $e');
      return null;
    }
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
  //  الفحص الخلفي التلقائي
  // ==========================================================
  void _startBackgroundCheckIfNeeded() {
    if (_backgroundCheckStarted) return;
    if (state.allChannels.isEmpty) return;

    _backgroundCheckStarted = true;
    state = state.copyWith(isBackgroundChecking: true);

    // ابدأ بعد 5 ثوان (حتى يرى المستخدم القنوات أولاً)
    Future.delayed(const Duration(seconds: 5), () {
      _runBackgroundCheck();
    });
  }

  Future<void> _runBackgroundCheck() async {
    final channels = state.allChannels;
    if (channels.isEmpty) {
      state = state.copyWith(isBackgroundChecking: false);
      return;
    }

    // التحديث الفوري عند وصول نتائج الدفعات
    final newWorkingStatus = <String, bool>{...state.workingStatus};

    await _checker.startBackgroundCheck(
      channels,
      alreadyChecked: state.workingStatus,
      onResult: (channelId, isWorking) {
        newWorkingStatus[channelId] = isWorking;

        // تحديث الحالة (بدون إعادة بناء كل شيء)
        state = state.copyWith(workingStatus: newWorkingStatus);

        // تطبيق الفلاتر عند كل 50 نتيجة
        if (newWorkingStatus.length % 50 == 0) {
          _applyFilters();
        }
      },
    );

    // تحديث نهائي
    _applyFilters();
    state = state.copyWith(isBackgroundChecking: false);
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

    // 1) فلتر البالغين
    if (_filterAdult) {
      filtered = filtered
          .where((c) => !isAdultContent(c.name, c.group))
          .toList();
    }

    // 2-أ) القنوات التي فشل المشغّل في تشغيلها → تُخفى فوراً
    if (_deadIds.isNotEmpty) {
      filtered = filtered.where((c) => !_deadIds.contains(c.id)).toList();
    }

    // 2) إخفاء القنوات الميتة تلقائياً (إذا فُحصت)
    if (state.workingStatus.isNotEmpty) {
      filtered = filtered.where((c) {
        final status = state.workingStatus[c.id];
        // إذا لم تُفحص → نعرضها (أفضل من إخفائها خطأً)
        // إذا فُحصت → نعرضها فقط إذا كانت تعمل
        return status == null || status == true;
      }).toList();
    }

    // 3) التصنيف
    if (state.selectedCategorySlug != null) {
      filtered = filtered
          .where((c) => c.category == state.selectedCategorySlug)
          .toList();
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
    final defaultCats = DefaultCategories.list;
    final result = <Category>[];
    for (final cat in defaultCats) {
      final catChannels =
          channels.where((c) => c.category == cat.slug).toList();
      final subs = <SubCategory>[];
      for (final sub in cat.subCategories) {
        final count = catChannels.where((c) {
          final g = c.group.toLowerCase();
          final s = sub.slug.toLowerCase();
          final n = sub.name.toLowerCase();
          return g.contains(s) ||
              g.contains(n) ||
              c.name.toLowerCase().contains(n);
        }).length;
        if (count > 0) subs.add(sub.copyWith(channelsCount: count));
      }
      result.add(cat.copyWith(
        subCategories: subs,
        channelsCount: catChannels.length,
      ));
    }
    return result;
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
