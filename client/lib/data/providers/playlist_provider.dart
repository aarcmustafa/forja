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
//  Notifier
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
//  الفحص مُلغى — نستخدم فقط النتائج المحفوظة
// ==========================================================
Future<void> _runInitialCheckIfNeeded(Map<String, bool> saved) async {
  if (saved.isNotEmpty) {
    state = state.copyWith(workingStatus: saved);
    _applyFilters();
  }
  await _storage.markInitialCheckDone();
  state = state.copyWith(isInitialChecking: false);
}

void _startBackgroundCheckIfNeeded() {
  // لا شيء — الفحص مُلغى
}

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
//  الترتيب: beIN العربية أولاً
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

  final quality = _qualityRank(text);

  // ═══════════════════════════════════════════════════════
  //  beIN Sports — العربية 1-16 أولاً
  // ═══════════════════════════════════════════════════════
  final isBein = text.contains('bein') ||
      text.contains('بين سبورت') ||
      text.contains('بين سبور');

  if (isBein) {
    final n = _num(name);

    // MAX آخر شيء
    if (name.contains('max') || name.contains('ماكس')) {
      return 300 + n;
    }
    // Premium قبل MAX
    if (name.contains('premium') || name.contains('بريميوم')) {
      return 200 + n;
    }
    // English قبل Premium
    if (name.contains('english') || name.contains('إنجليزي')) {
      return 100 + n;
    }
    // ✅ العربية beIN Sports 1-16 → القمة المطلقة
    return 10 + n;
  }

  // Al Kass
  if (text.contains('alkass') ||
      text.contains('al kass') ||
      text.contains('الكأس') ||
      text.contains('الكاس')) {
    final n = _num(name);
    return 500 + (n * 10) + quality;
  }

  // Abu Dhabi Sports
  if (text.contains('abu dhabi') ||
      text.contains('ad sport') ||
      text.contains('أبوظبي')) {
    final n = _num(name);
    return 1000 + (n * 10) + quality;
  }

  // Dubai Sports
  if (text.contains('dubai sport') || text.contains('دبي الرياضية')) {
    final n = _num(name);
    return 1500 + (n * 10) + quality;
  }

  // الباقي
  return 9000 + (name.hashCode.abs() % 900);
}

int _qualityRank(String text) {
  if (text.contains('4k') ||
      text.contains('uhd') ||
      text.contains('2160')) {
    return 3;
  }
  if (text.contains('fhd') ||
      text.contains('full hd') ||
      text.contains('1080')) {
    return 2;
  }
  if (text.contains('hd') || text.contains('720')) {
    return 1;
  }
  return 0;
}

int _num(String text) {
  final m = RegExp(r'(\d{1,2})').firstMatch(text);
  if (m == null) return 0;
  return int.tryParse(m.group(1)!) ?? 0;
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

  filtered = filtered.where(_isSportChannel).toList();

  if (_filterAdult) {
    filtered = filtered
        .where((c) => !isAdultContent(c.name, c.group))
        .toList();
  }

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

  filtered = _sortChannels(filtered);

  state = state.copyWith(filteredChannels: filtered);
}
    // ==========================================================
  //  الفلترة الصارمة: رياضية فقط
  // ==========================================================
  bool _isSportChannel(Channel c) {
    final name = c.name.toLowerCase();
    final group = c.group.toLowerCase();
    final text = '$name $group';

    // ═══════════════════════════════════════════════════════
    //  🚫 قائمة سوداء: أي قناة تحتوي هذه → ليست رياضية
    // ═══════════════════════════════════════════════════════
    const blacklist = [
      'kids', 'أطفال', 'اطفال', 'cartoon', 'كرتون', 'سبيستون',
      'movie', 'أفلام', 'افلام', 'cinema', 'سينما',
      'music', 'موسيقى', 'موسيقية', 'طرب',
      'news', 'أخبار', 'اخبار',
      'religion', 'ديني', 'قرآن', 'quran', 'قرآن كريم',
      'cooking', 'طبخ', 'food', 'أكل',
      'shopping', 'تسوق', 'بيع',
      'documentary', 'وثائقي', 'ناشيونال',
      'series', 'مسلسل', 'مسلسلات', 'دراما', 'drama',
      'entertainment', 'ترفيه',
      'fashion', 'أزياء', 'موضة',
      'travel', 'سفر', 'سياحة',
      'education', 'تعليم', 'مدارس',
      'health', 'صحة', 'طب',
    ];

    for (final b in blacklist) {
      if (name.contains(b) || group.contains(b)) return false;
    }

    // ═══════════════════════════════════════════════════════
    //  ✅ قائمة بيضاء: كلمات رياضية محددة جدًا
    // ═══════════════════════════════════════════════════════
    const sportKeywords = [
      // باقات عربية معروفة
      'bein', 'بين سبورت', 'بين سبور',
      'ssc', 'ssc sport',
      'alkass', 'al kass', 'الكأس', 'الكاس',
      'abu dhabi sport', 'ad sport', 'أبوظبي الرياضية',
      'dubai sport', 'دبي الرياضية',
      'ksa sport', 'السعودية الرياضية',
      'alwan sport', 'ألوان الرياضية',
      'shahid sport',
      '1001',
      // عالمية
      'sky sport', 'espn', 'dazn',
      'eurosport', 'euro sport',
      'sportv', 'sport tv',
      // رياضات محددة
      'nba', 'nfl', 'ufc', 'wwe',
      'formula 1', 'f1 ', 'moto gp',
      // كلمات عربية محددة
      'رياضية', 'الرياضية',
      'كورة', 'الكورة',
      'ملاعب',
    ];

    for (final k in sportKeywords) {
      if (text.contains(k)) return true;
    }

    // القرار النهائي: غير مدرج = غير رياضي
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

  // ==========================================================
  //  الباقات: beIN + الكأس + أبوظبي + دبي
  // ==========================================================
  List<Category> _buildCategoriesFromChannels(List<Channel> channels) {
    const wantedSubs = [
      SubCategory(id: '1', name: 'beIN Sports', slug: 'bein', order: 1),
      SubCategory(id: '2', name: 'الكأس', slug: 'alkass', order: 2),
      SubCategory(id: '3', name: 'أبوظبي الرياضية', slug: 'ad', order: 3),
      SubCategory(id: '4', name: 'دبي الرياضية', slug: 'dubai', order: 4),
    ];

    const matchMap = <String, List<String>>{
      'bein': ['bein', 'بين سبورت', 'بين سبور'],
      'alkass': ['alkass', 'al kass', 'الكأس', 'الكاس'],
      'ad': ['abu dhabi', 'ad sport', 'أبوظبي'],
      'dubai': ['dubai sport', 'دبي الرياضية'],
    };

    final subs = <SubCategory>[];
    for (final sub in wantedSubs) {
      final keywords = matchMap[sub.slug] ?? [sub.slug];
      final count = channels.where((c) {
        final text = '${c.name} ${c.group}'.toLowerCase();
        return keywords.any((k) => text.contains(k));
      }).length;

      subs.add(sub.copyWith(channelsCount: count));
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
