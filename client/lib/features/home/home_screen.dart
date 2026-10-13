import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/playlist_provider.dart';
import '../../data/providers/history_provider.dart';
import '../live_tv/widgets/channel_card.dart';
import '../live_tv/widgets/sports_matches_widget.dart';
import '../player/player_screen.dart';

/// الشاشة الرئيسية الرياضية
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
            CircularProgressIndicator(
                color: Color(0xFF00C8FF), strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'جارٍ تحميل القنوات الرياضية...',
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
            Icon(Icons.sports_soccer_rounded,
                color: Colors.white24, size: 80),
            SizedBox(height: 16),
            Text(
              'لا توجد قنوات رياضية',
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

    // تجميع القنوات حسب الباقة
    final beinChannels = _filterByKeyword(all, 'bein');
    final sscChannels = _filterByKeyword(all, 'ssc');
    final adChannels = _filterByKeyword(all, 'ad sport');
    final alwanChannels = _filterByKeyword(all, 'alwan');
    final alkassChannels = _filterByKeyword(all, 'alkass');
    final others = all
        .where((c) =>
            !_matchesKeyword(c, 'bein') &&
            !_matchesKeyword(c, 'ssc') &&
            !_matchesKeyword(c, 'ad sport') &&
            !_matchesKeyword(c, 'alwan') &&
            !_matchesKeyword(c, 'alkass'))
        .toList();

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Hero
        const SliverToBoxAdapter(child: _HeroSection()),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // صندوق المباريات
        SliverToBoxAdapter(
          child: SportsMatchesWidget(
            onChannelTap: _openChannel,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // الإحصائيات
        SliverToBoxAdapter(
          child: _buildStats(all.length),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),

        // صفوف الباقات
        if (beinChannels.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'beIN Sports',
              icon: Icons.sports_soccer_rounded,
              items: beinChannels.take(20).toList(),
              color: const Color(0xFF00C8FF),
            ),
          ),
        if (sscChannels.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'SSC Sports',
              icon: Icons.sports_soccer_rounded,
              items: sscChannels.take(20).toList(),
              color: const Color(0xFF4CAF50),
            ),
          ),
        if (adChannels.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'AD Sports',
              icon: Icons.sports_soccer_rounded,
              items: adChannels.take(20).toList(),
              color: const Color(0xFFFFB800),
            ),
          ),
        if (alwanChannels.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'قنوات ألوان',
              icon: Icons.sports_soccer_rounded,
              items: alwanChannels.take(20).toList(),
              color: const Color(0xFFE91E63),
            ),
          ),
        if (alkassChannels.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'Al Kass',
              icon: Icons.sports_soccer_rounded,
              items: alkassChannels.take(20).toList(),
              color: const Color(0xFF9C27B0),
            ),
          ),
        if (others.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildRow(
              title: 'قنوات رياضية أخرى',
              icon: Icons.sports_rounded,
              items: others.take(20).toList(),
              color: const Color(0xFF00BCD4),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ==========================================================
  //  فلترة القنوات بالكلمة المفتاحية
  // ==========================================================
  List<Channel> _filterByKeyword(List<Channel> all, String keyword) {
    return all.where((c) => _matchesKeyword(c, keyword)).toList();
  }

  bool _matchesKeyword(Channel c, String keyword) {
    final text = '${c.name.toLowerCase()} ${c.group.toLowerCase()}';
    return text.contains(keyword.toLowerCase());
  }

  void _openChannel(Channel channel) {
    ref.read(historyProvider.notifier).record(channel);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: channel.streamUrl,
          channelName: channel.name,
          channelLogo: channel.logo,
        ),
      ),
    );
  }
  
  // ==========================================================
  //  الإحصائيات
  // ==========================================================
  Widget _buildStats(int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF1A2E1A),
              Color(0xFF141A2E),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.sports_soccer_rounded,
                color: Color(0xFF4CAF50),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'القنوات الرياضية المتاحة',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$total قناة',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFFB800),
              size: 40,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  //  صف القنوات
  // ==========================================================
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
                  onTap: () => _openChannel(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
//  Hero Section
// ==========================================================
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      margin: const EdgeInsets.fromLTRB(32, 20, 32, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1A2E1A),
            Color(0xFF0F1A0F),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.sports_soccer_rounded,
                color: Colors.white,
                size: 56,
              ),
            ),
            const SizedBox(width: 24),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'استيتن فرجة',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'كل الرياضة في مكان واحد',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'قنوات • مباريات • بث مباشر',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFFB800),
              size: 80,
            ),
          ],
        ),
      ),
    );
  }
}
