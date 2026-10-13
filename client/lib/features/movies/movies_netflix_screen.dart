import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/playlist_provider.dart';
import '../../data/providers/history_provider.dart';
import '../live_tv/widgets/channel_card.dart';
import 'movie_detail_screen.dart';

/// شاشة الأفلام بنمط Netflix + سجل المشاهدة
class MoviesNetflixScreen extends ConsumerStatefulWidget {
  const MoviesNetflixScreen({super.key});

  @override
  ConsumerState<MoviesNetflixScreen> createState() =>
      _MoviesNetflixScreenState();
}

class _MoviesNetflixScreenState extends ConsumerState<MoviesNetflixScreen> {
  final ScrollController _verticalController = ScrollController();

  static const List<Map<String, String>> _languagesOrder = [
    {'code': 'ara', 'title': 'أفلام عربية'},
    {'code': 'tur', 'title': 'أفلام تركية'},
    {'code': 'hin', 'title': 'أفلام هندية'},
    {'code': 'anime', 'title': 'أنمي'},
    {'code': 'asian', 'title': 'أفلام أسيوية'},
    {'code': 'kor', 'title': 'أفلام كورية'},
    {'code': 'jpn', 'title': 'أفلام يابانية'},
    {'code': 'eng', 'title': 'أفلام أجنبية'},
    {'code': 'fra', 'title': 'أفلام فرنسية'},
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
    final lastMovieId = ref.watch(historyProvider).lastMovieId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: _buildBody(state, allMovies, lastMovieId),
        ),
      ),
    );
  }

  Widget _buildBody(
    PlaylistState state,
    List<Channel> movies,
    String? lastMovieId,
  ) {
    if (state.isLoading && state.allChannels.isEmpty) {
      return _buildLoading();
    }

    if (movies.isEmpty) {
      return _buildEmpty();
    }

    final grouped = _groupByLanguage(movies);

    // ابحث عن آخر فيلم
    Channel? lastMovie;
    if (lastMovieId != null) {
      try {
        lastMovie = movies.firstWhere((m) => m.id == lastMovieId);
      } catch (_) {
        lastMovie = null;
      }
    }

    return CustomScrollView(
      controller: _verticalController,
      slivers: [
        // قسم شوهد حديثاً (إن وُجد)
        if (lastMovie != null)
          SliverToBoxAdapter(child: _buildRecentMovie(lastMovie)),

        SliverToBoxAdapter(child: _buildHeader(state, movies.length)),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),

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
  //  قسم شوهد حديثاً (آخر فيلم)
  // ==========================================================
  Widget _buildRecentMovie(Channel movie) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.history_rounded,
                  color: Color(0xFFFFB800),
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'شوهد حديثاً',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ChannelCard(
              channel: movie,
              width: 180,
              height: 270,
              onTap: () => _openMovie(movie),
            ),
          ),
        ],
      ),
    );
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
  //  الفتح
  // ==========================================================
  void _openMovie(Channel movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen(movie: movie),
      ),
    );
  }

  void _openLanguageList(String title, List<Channel> movies) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MovieListPage(title: title, movies: movies),
      ),
    );
  }

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

// ==========================================================
//  زر "الكل"
// ==========================================================
class _SeeAllButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _SeeAllButton({required this.onPressed});

  @override
  State<_SeeAllButton> createState() => _SeeAllButtonState();
}

class _SeeAllButtonState extends State<_SeeAllButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey.keyLabel;
          if (key == 'Select' || key == 'Enter' || key == 'Space') {
            widget.onPressed();
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isFocused
                ? const Color(0xFF00C8FF)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isFocused ? Colors.white : const Color(0xFF2A3350),
              width: _isFocused ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الكل',
                style: TextStyle(
                  color: _isFocused ? Colors.black : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_back_rounded,
                color: _isFocused ? Colors.black : Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
//  صفحة كل أفلام لغة
// ==========================================================
class _MovieListPage extends StatelessWidget {
  final String title;
  final List<Channel> movies;

  const _MovieListPage({required this.title, required this.movies});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    _BackButton(onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${movies.length} فيلم',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: movies.length,
                  itemBuilder: (context, i) {
                    final movie = movies[i];
                    return ChannelCard(
                      channel: movie,
                      width: 200,
                      height: 270,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MovieDetailScreen(movie: movie),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
//  زر الرجوع
// ==========================================================
class _BackButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey.keyLabel;
          if (key == 'Select' || key == 'Enter' || key == 'Space') {
            widget.onPressed();
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _isFocused
                ? const Color(0xFF00C8FF)
                : const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? Colors.white : const Color(0xFF2A3350),
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF00C8FF).withOpacity(0.5),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: _isFocused ? Colors.black : Colors.white70,
            size: 22,
          ),
        ),
      ),
    );
  }
}
