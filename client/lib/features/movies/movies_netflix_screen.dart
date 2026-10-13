import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/playlist_provider.dart';
import '../live_tv/widgets/channel_card.dart';
import 'movie_detail_screen.dart';

/// شاشة الأفلام بنمط Netflix
/// صفوف أفقية حسب اللغة: عربي / تركي / هندي / أجنبي / أنمي / أسيوي...
class MoviesNetflixScreen extends ConsumerStatefulWidget {
  const MoviesNetflixScreen({super.key});

  @override
  ConsumerState<MoviesNetflixScreen> createState() =>
      _MoviesNetflixScreenState();
}

class _MoviesNetflixScreenState extends ConsumerState<MoviesNetflixScreen> {
  final ScrollController _verticalController = ScrollController();

  // ترتيب اللغات حسب الأولوية
  static const List<Map<String, String>> _languagesOrder = [
    {'code': 'ara', 'title': 'أفلام عربية', 'icon': 'movie'},
    {'code': 'tur', 'title': 'أفلام تركية', 'icon': 'movie'},
    {'code': 'hin', 'title': 'أفلام هندية', 'icon': 'movie'},
    {'code': 'anime', 'title': 'أنمي', 'icon': 'anime'},
    {'code': 'asian', 'title': 'أفلام أسيوية', 'icon': 'movie'},
    {'code': 'kor', 'title': 'أفلام كورية', 'icon': 'movie'},
    {'code': 'jpn', 'title': 'أفلام يابانية', 'icon': 'movie'},
    {'code': 'eng', 'title': 'أفلام أجنبية', 'icon': 'movie'},
    {'code': 'fra', 'title': 'أفلام فرنسية', 'icon': 'movie'},
  ];

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playlistProvider);
    final allMovies =
        state.allChannels.where((c) => c.contentType == 'movie').toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: _buildBody(state, allMovies),
        ),
      ),
    );
  }

  Widget _buildBody(PlaylistState state, List<Channel> movies) {
    // تحميل
    if (state.isLoading && state.allChannels.isEmpty) {
      return _buildLoading();
    }

    // فارغ
    if (movies.isEmpty) {
      return _buildEmpty();
    }

    // تجميع الأفلام حسب اللغة
    final grouped = _groupByLanguage(movies);

    return CustomScrollView(
      controller: _verticalController,
      slivers: [
        // شريط علوي
        SliverToBoxAdapter(child: _buildHeader(state, movies.length)),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // الصفوف
        for (final lang in _languagesOrder)
          if ((grouped[lang['code']] ?? []).isNotEmpty)
            SliverToBoxAdapter(
              child: _buildRow(
                title: lang['title']!,
                languageCode: lang['code']!,
                movies: grouped[lang['code']]!,
              ),
            ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Map<String, List<Channel>> _groupByLanguage(List<Channel> movies) {
    final map = <String, List<Channel>>{};
    for (final m in movies) {
      map.putIfAbsent(m.language, () => []).add(m);
    }
    // ترتيب كل مجموعة حسب السنة (الأحدث أولاً)
    for (final key in map.keys) {
      map[key]!.sort((a, b) {
        final ya = a.year ?? 0;
        final yb = b.year ?? 0;
        return yb.compareTo(ya);
      });
    }
    return map;
  }

  // ==========================================================
  //  الشريط العلوي
  // ==========================================================
  Widget _buildHeader(PlaylistState state, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00C8FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.movie_rounded,
              color: Color(0xFF00C8FF),
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الأفلام',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'تصفح حسب اللغة والنوع',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141A2E),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF2A3350)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_movies_rounded,
                  color: Color(0xFFFFB800),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '$total فيلم',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  //  صف أفقى
  // ==========================================================
  Widget _buildRow({
    required String title,
    required String languageCode,
    required List<Channel> movies,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان الصف + زر "الكل"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8FF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${movies.length}',
                    style: const TextStyle(
                      color: Color(0xFF00C8FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                _SeeAllButton(
                  onPressed: () => _openLanguageList(title, movies),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // الصف الأفقي للبطاقات
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              itemCount: movies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final movie = movies[i];
                return ChannelCard(
                  channel: movie,
                  width: 180,
                  height: 270,
                  onTap: () => _openMovie(movie),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  //  فتح فيلم
  // ==========================================================
  void _openMovie(Channel movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen(movie: movie),
      ),
    );
  }

  // ==========================================================
  //  فتح قائمة كاملة باللغة
  // ==========================================================
  void _openLanguageList(String title, List<Channel> movies) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MovieListPage(title: title, movies: movies),
      ),
    );
  }

  // ==========================================================
  //  تحميل
  // ==========================================================
  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF00C8FF), strokeWidth: 3),
          SizedBox(height: 20),
          Text(
            'جارٍ تحميل الأفلام...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  //  فارغ
  // ==========================================================
  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_filter_rounded, color: Colors.white24, size: 80),
          SizedBox(height: 16),
          Text(
            'لا توجد أفلام',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'تحقق من اتصالك بالإنترنت',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
