import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/playlist_provider.dart';
import '../live_tv/widgets/channel_card.dart';
import '../movies/movie_detail_screen.dart';
import '../player/player_screen.dart';

/// الشاشة الرئيسية - تجمع القنوات والأفلام والمسلسلات
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playlistProvider);
    final all = state.allChannels;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: _buildBody(state, all),
        ),
      ),
    );
  }

  Widget _buildBody(PlaylistState state, List<Channel> all) {
    if (state.isLoading && all.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF00C8FF), strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'جارٍ تحميل المحتوى...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (all.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_rounded, color: Colors.white24, size: 80),
            SizedBox(height: 16),
            Text(
              'لا يوجد محتوى',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final liveChannels = all.where((c) => c.contentType == 'live').toList();
    final movies = all.where((c) => c.contentType == 'movie').toList();
    final series = all.where((c) => c.contentType == 'series').toList();

    final sportsChannels =
        liveChannels.where((c) => c.category == 'sport').toList();
    final newsChannels =
        liveChannels.where((c) => c.category == 'news').toList();
    final kidsChannels =
        liveChannels.where((c) => c.category == 'kids').toList();

    final arabicMovies =
        movies.where((m) => m.language == 'ara').take(20).toList();
    final turkishMovies =
        movies.where((m) => m.language == 'tur').take(20).toList();
    final hindiMovies =
        movies.where((m) => m.language == 'hin').take(20).toList();

    final arabicSeries =
        series.where((s) => s.language == 'ara').take(20).toList();
    final turkishSeries =
        series.where((s) => s.language == 'tur').take(20).toList();

    final featured = [...liveChannels, ...movies]
        .where((c) => c.logo.isNotEmpty)
        .take(20)
        .toList();

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (featured.isNotEmpty)
          SliverToBoxAdapter(child: _buildHero(featured)),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: _buildStats(
            liveChannels.length,
            movies.length,
            series.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
        if (sportsChannels.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'قنوات رياضية',
              icon: Icons.sports_soccer_rounded,
              items: sportsChannels.take(20).toList(),
              color: const Color(0xFF00C8FF),
            ),
          ),
        if (newsChannels.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'قنوات إخبارية',
              icon: Icons.newspaper_rounded,
              items: newsChannels.take(20).toList(),
              color: const Color(0xFFFFB800),
            ),
          ),
        if (kidsChannels.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'قنوات أطفال',
              icon: Icons.child_care_rounded,
              items: kidsChannels.take(20).toList(),
              color: const Color(0xFF9C27B0),
            ),
          ),
        if (arabicMovies.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'أفلام عربية',
              icon: Icons.movie_rounded,
              items: arabicMovies,
              color: const Color(0xFF4CAF50),
            ),
          ),
        if (turkishMovies.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'أفلام تركية',
              icon: Icons.movie_rounded,
              items: turkishMovies,
              color: const Color(0xFF4CAF50),
            ),
          ),
        if (hindiMovies.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'أفلام هندية',
              icon: Icons.movie_rounded,
              items: hindiMovies,
              color: const Color(0xFF4CAF50),
            ),
          ),
        if (arabicSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'مسلسلات عربية',
              icon: Icons.tv_rounded,
              items: arabicSeries,
              color: const Color(0xFFE91E63),
            ),
          ),
        if (turkishSeries.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'مسلسلات تركية',
              icon: Icons.tv_rounded,
              items: turkishSeries,
              color: const Color(0xFFE91E63),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildHero(List<Channel> featured) {
    return Container(
      height: 320,
      margin: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1A2238),
            Color(0xFF0F1A2E),
          ],
        ),
        border: Border.all(color: const Color(0xFF2A3350), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      const Color(0xFF00C8FF).withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB800).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFFB800).withOpacity(0.5),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFB800),
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'مميز',
                              style: TextStyle(
                                color: Color(0xFFFFB800),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'مرحباً بك في',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'استيتن فرجة',
                        style: TextStyle(
                          color: Color(0xFF00C8FF),
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'آلاف القنوات والأفلام والمسلسلات\nفي تطبيق واحد',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 240,
                    child: Stack(
                      children: [
                        for (int i = 0; i < featured.take(3).length; i++)
                          Positioned(
                            right: i * 40.0,
                            top: i * 15.0,
                            child: Transform.rotate(
                              angle: (i - 1) * 0.08,
                              child: Container(
                                width: 140,
                                height: 220,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A2238),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF2A3350),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: featured[i].logo.isEmpty
                                      ? const Center(
                                          child: Icon(
                                            Icons.movie_rounded,
                                            color: Colors.white24,
                                            size: 40,
                                          ),
                                        )
                                      : Image.network(
                                          featured[i].logo,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(
                                            child: Icon(
                                              Icons.movie_rounded,
                                              color: Colors.white24,
                                              size: 40,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(int channels, int movies, int series) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.live_tv_rounded,
            label: 'قنوات مباشرة',
            value: '$channels',
            color: const Color(0xFF00C8FF),
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            icon: Icons.movie_rounded,
            label: 'أفلام',
            value: '$movies',
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            icon: Icons.tv_rounded,
            label: 'مسلسلات',
            value: '$series',
            color: const Color(0xFFE91E63),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF141A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A3350)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRow({
    required String title,
    required IconData icon,
    required List<Channel> items,
    required Color color,
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final item = items[i];
                return ChannelCard(
                  channel: item,
                  width: 180,
                  height: 250,
                  onTap: () {
                    if (item.contentType == 'movie') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MovieDetailScreen(movie: item),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerScreen(
                            streamUrl: item.streamUrl,
                            channelName: item.name,
                            channelLogo: item.logo,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
