import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/channel.dart';
import '../models/category.dart';
import '../repositories/m3u_repository.dart';
import '../../features/settings/settings_screen.dart';

// ==========================================================
//  1) المستودع (Singleton)
// ==========================================================
final m3uRepositoryProvider = Provider<M3uRepository>((ref) {
  final repo = M3uRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

// ==========================================================
//  2) حالة القنوات
// ==========================================================
class PlaylistState {
  final List<Channel> allChannels;
  final List<Channel> filteredChannels;
  final List<Category> categories;
  final String? selectedCategorySlug;
  final String? selectedSubCategorySlug;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  const PlaylistState({
    this.allChannels = const [],
    this.filteredChannels = const [],
    this.categories = const [],
    this.selectedCategorySlug,
    this.selectedSubCategorySlug,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
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
    String? error,
    bool clearError = false,
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
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ==========================================================
//  3) Notifier
// ==========================================================
class PlaylistNotifier extends StateNotifier<PlaylistState> {
  final M3uRepository _repository;
  bool _filterAdult = true; // ← فلتر البالغين (افتراضياً مفعّل)

  PlaylistNotifier(this._repository) : super(const PlaylistState());

  /// تحديث فلتر البالغين
  void setAdultFilter(bool value) {
    if (_filterAdult == value) return;
    _filterAdult = value;
    _applyFilters();
  }

  /// تحميل كل روابط M3U
  Future<void> loadPlaylists(List<String> urls) async {
    if (urls.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'لا توجد روابط M3U للتحميل',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final List<Channel> all = [];

      for (final url in urls) {
        try {
          final channels = await _repository.loadFromUrl(url);
          all.addAll(channels);
        } catch (e) {
          // ignore: avoid_print
          print('فشل تحميل الرابط $url: $e');
        }
      }

      final unique = _removeDuplicates(all);
      final categories = _buildCategoriesFromChannels(unique);

      state = state.copyWith(
        allChannels: unique,
        categories: categories,
        isLoading: false,
      );

      // تطبيق الفلاتر (بما فيها فلتر البالغين)
      _applyFilters();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'فشل تحميل القنوات: $e',
      );
    }
  }

  /// إزالة التكرار
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

  /// بناء التصنيفات
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
          return g.contains(s) || g.contains(n) || c.name.toLowerCase().contains(n);
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

  /// تطبيق كل الفلاتر
  void _applyFilters() {
    List<Channel> filtered = List.from(state.allChannels);

    // ==========================================================
    //  1) فلتر البالغين (الأولوية القصوى)
    // ==========================================================
    if (_filterAdult) {
      filtered = filtered
          .where((c) => !isAdultContent(c.name, c.group))
          .toList();
    }

    // ==========================================================
    //  2) فلتر التصنيف الرئيسي
    // ==========================================================
    if (state.selectedCategorySlug != null) {
      filtered = filtered
          .where((c) => c.category == state.selectedCategorySlug)
          .toList();
    }

    // ==========================================================
    //  3) فلتر الباقة الفرعية
    // ==========================================================
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

    // ==========================================================
    //  4) فلتر البحث
    // ==========================================================
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

  /// إعادة تحميل
  Future<void> refresh(List<String> urls) async {
    _repository.clearCache();
    await loadPlaylists(urls);
  }
}

// ==========================================================
//  Provider الرئيسي — يستمع لتغييرات الإعدادات
// ==========================================================
final playlistProvider =
    StateNotifierProvider<PlaylistNotifier, PlaylistState>((ref) {
  final repo = ref.watch(m3uRepositoryProvider);
  final notifier = PlaylistNotifier(repo);

  // تطبيق القيمة الابتدائية
  final initialFilter = ref.read(settingsProvider).filterAdult;
  notifier.setAdultFilter(initialFilter);

  // الاستماع لأي تغيير في الإعدادات
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
