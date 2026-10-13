import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/channel.dart';
import '../models/category.dart';
import '../repositories/m3u_repository.dart';
import '../local/local_storage.dart';
import '../../features/settings/settings_screen.dart';

// ==========================================================
//  المستودع
// ==========================================================
final m3uRepositoryProvider = Provider<M3uRepository>((ref) {
  final repo = M3uRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

// ==========================================================
//  التخزين المحلي
// ==========================================================
final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage();
});

// ==========================================================
//  حالة القنوات
// ==========================================================
class PlaylistState {
  final List<Channel> allChannels;
  final List<Channel> filteredChannels;
  final List<Category> categories;
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
  bool _filterAdult = true;

  PlaylistNotifier(this._repository, this._storage)
      : super(const PlaylistState());

  /// تحديث فلتر البالغين
  void setAdultFilter(bool value) {
    if (_filterAdult == value) return;
    _filterAdult = value;
    _applyFilters();
  }

  // ==========================================================
  //  التحميل الذكي (من الذاكرة أولاً + تحديث في الخلفية)
  // ==========================================================
  Future<void> loadPlaylists(List<String> urls, {bool forceRefresh = false}) async {
    if (urls.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'لا توجد روابط M3U للتحميل',
      );
      return;
    }

    // 1) تهيئة التخزين
    await _storage.init();

    // 2) محاولة القراءة من الذاكرة (فقط إذا لم يكن refresh)
    if (!forceRefresh) {
      final cached = _storage.loadChannels();
      if (cached != null && cached.isNotEmpty) {
        // عرض فوري من الذاكرة
        _setChannels(cached);
        state = state.copyWith(
          isLoading: false,
          lastUpdate: _storage.getLastSaveTime(),
        );

        // تحديث في الخلفية (صامت)
        _refreshInBackground(urls);
        return;
      }
    }

    // 3) لا يوجد cache → تحميل كامل
    state = state.copyWith(isLoading: true, clearError: true);

    final channels = await _fetchAll(urls);

    if (channels == null || channels.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'فشل تحميل القنوات',
      );
      return;
    }

    // حفظ + عرض
    await _storage.saveChannels(channels);
    _setChannels(channels);

    state = state.copyWith(
      isLoading: false,
      lastUpdate: DateTime.now(),
    );
  }

  /// تحديث في الخلفية بدون إظهار شاشة التحميل
  Future<void> _refreshInBackground(List<String> urls) async {
    state = state.copyWith(isRefreshing: true);

    try {
      final channels = await _fetchAll(urls, refreshCache: true);
      if (channels != null && channels.isNotEmpty) {
        await _storage.saveChannels(channels);
        _setChannels(channels);
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

  /// جلب كل الروابط
  Future<List<Channel>?> _fetchAll(List<String> urls, {bool refreshCache = false}) async {
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

  /// تعيين القنوات + بناء التصنيفات + تطبيق الفلاتر
  void _setChannels(List<Channel> channels) {
    final categories = _buildCategoriesFromChannels(channels);
    state = state.copyWith(
      allChannels: channels,
      categories: categories,
    );
    _applyFilters();
  }
  
  // ==========================================================
  //  إزالة التكرار
  // ==========================================================
  List<Channel> _removeDuplicates(List<Channel> channels) {
    final Map<String, Channel> unique = {};

    for (final ch in channels) {
      final key = _normalizeName(ch.name);

      if (!unique.containsKey(key)) {
        unique[key] = ch;
      } else {
        final existing = unique[key]!;
        if (ch.priority > existing.priority) {
          unique[key] = ch;
        }
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

  // ==========================================================
  //  بناء التصنيفات
  // ==========================================================
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

        if (count > 0) {
          subs.add(sub.copyWith(channelsCount: count));
        }
      }

      result.add(
        cat.copyWith(
          subCategories: subs,
          channelsCount: catChannels.length,
        ),
      );
    }

    return result;
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

    // 2) التصنيف الرئيسي
    if (state.selectedCategorySlug != null) {
      filtered = filtered
          .where((c) => c.category == state.selectedCategorySlug)
          .toList();
    }

    // 3) الباقة الفرعية
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
            (subName != null && (g.contains(subName) || n.contains(subName)));
      }).toList();
    }

    // 4) البحث
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
  //  تحديث يدوي
  // ==========================================================
  Future<void> refresh(List<String> urls) async {
    _repository.clearCache();
    await loadPlaylists(urls, forceRefresh: true);
  }

  /// مسح كل البيانات
  Future<void> clearAll(List<String> urls) async {
    await _storage.clear();
    _repository.clearCache();
    state = const PlaylistState();
    await loadPlaylists(urls, forceRefresh: true);
  }

  /// عدد القنوات المخزنة محلياً
  int getCachedCount() => _storage.getSavedCount();

  /// وقت آخر تحديث
  DateTime? getLastUpdate() => state.lastUpdate;
}

// ==========================================================
//  Provider الرئيسي
// ==========================================================
final playlistProvider =
    StateNotifierProvider<PlaylistNotifier, PlaylistState>((ref) {
  final repo = ref.watch(m3uRepositoryProvider);
  final storage = ref.watch(localStorageProvider);
  final notifier = PlaylistNotifier(repo, storage);

  // تطبيق فلتر البالغين المبدئي
  final initialFilter = ref.read(settingsProvider).filterAdult;
  notifier.setAdultFilter(initialFilter);

  // الاستماع لتغييرات الإعدادات
  ref.listen<SettingsState>(settingsProvider, (prev, next) {
    if (prev == null || prev.filterAdult != next.filterAdult) {
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
