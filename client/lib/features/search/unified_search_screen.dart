import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/playlist_provider.dart';
import '../../data/providers/history_provider.dart';
import '../live_tv/widgets/channel_card.dart';
import '../movies/movie_detail_screen.dart';
import '../player/player_screen.dart';

/// البحث الموحد — يبحث في القنوات والأفلام والمسلسلات
class UnifiedSearchScreen extends ConsumerStatefulWidget {
  const UnifiedSearchScreen({super.key});

  @override
  ConsumerState<UnifiedSearchScreen> createState() =>
      _UnifiedSearchScreenState();
}

class _UnifiedSearchScreenState extends ConsumerState<UnifiedSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  String _query = '';
  int _tabIndex = 0; // 0=الكل, 1=قنوات, 2=أفلام, 3=مسلسلات

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(playlistProvider).allChannels;
    final results = _search(all, _query);

    final liveResults =
        results.where((c) => c.contentType == 'live').toList();
    final movieResults =
        results.where((c) => c.contentType == 'movie').toList();
    final seriesResults =
        results.where((c) => c.contentType == 'series').toList();

    final currentList = switch (_tabIndex) {
      0 => results,
      1 => liveResults,
      2 => movieResults,
      3 => seriesResults,
      _ => results,
    };

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              if (_query.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildTabs(
                  total: results.length,
                  live: liveResults.length,
                  movies: movieResults.length,
                  series: seriesResults.length,
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: _query.trim().isEmpty
                    ? _buildHint()
                    : currentList.isEmpty
                        ? _buildNoResults()
                        : _buildGrid(currentList),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  //  منطق البحث
  // ==========================================================
  List<Channel> _search(List<Channel> all, String query) {
    if (query.trim().isEmpty) return const [];

    final q = query.trim().toLowerCase();

    // كلمات البحث منفصلة (يدعم "فيلم عربي 2024")
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    final results = <_ScoredChannel>[];

    for (final c in all) {
      final name = c.name.toLowerCase();
      final original = c.originalName.toLowerCase();
      final group = c.group.toLowerCase();
      final genre = c.genreLabel.toLowerCase();
      final lang = c.languageLabel.toLowerCase();

      int score = 0;
      int matches = 0;

      for (final w in words) {
        int wordScore = 0;

        // مطابقة الاسم (الأعلى أولوية)
        if (name == w) {
          wordScore += 100;
        } else if (name.startsWith(w)) {
          wordScore += 50;
        } else if (name.contains(w)) {
          wordScore += 30;
        }

        // مطابقة الاسم الأصلي
        if (original.isNotEmpty) {
          if (original == w) {
            wordScore += 80;
          } else if (original.contains(w)) {
            wordScore += 25;
          }
        }

        // مطابقة الباقة
        if (group.contains(w)) wordScore += 15;

        // مطابقة النوع أو اللغة
        if (genre.contains(w)) wordScore += 10;
        if (lang.contains(w)) wordScore += 10;

        if (wordScore > 0) {
          matches++;
          score += wordScore;
        }
      }

      // نطلب أن تتحقق كل الكلمات
      if (matches == words.length && score > 0) {
        // مكافأة للأفلام/المسلسلات (لأنها عادة أكثر أهمية)
        if (c.contentType == 'movie') score += 5;
        if (c.contentType == 'series') score += 3;

        results.add(_ScoredChannel(channel: c, score: score));
      }
    }

    // ترتيب حسب الأولوية
    results.sort((a, b) => b.score.compareTo(a.score));

    return results.map((r) => r.channel).toList();
  }

  // ==========================================================
  //  شريط البحث
  // ==========================================================
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          _BackButton(onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF141A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _inputFocus.hasFocus
                      ? const Color(0xFF00C8FF)
                      : const Color(0xFF2A3350),
                  width: _inputFocus.hasFocus ? 2.5 : 1.5,
                ),
                boxShadow: _inputFocus.hasFocus
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00C8FF).withOpacity(0.3),
                          blurRadius: 16,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 18),
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF00C8FF),
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _inputFocus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'ابحث عن قناة، فيلم، أو مسلسل...',
                        hintStyle: TextStyle(
                          color: Colors.white38,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                        _inputFocus.requestFocus();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  //  التبويبات
  // ==========================================================
  Widget _buildTabs({
    required int total,
    required int live,
    required int movies,
    required int series,
  }) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          _ResultTab(
            label: 'الكل',
            count: total,
            icon: Icons.apps_rounded,
            color: const Color(0xFF00C8FF),
            isSelected: _tabIndex == 0,
            onTap: () => setState(() => _tabIndex = 0),
          ),
          const SizedBox(width: 10),
          _ResultTab(
            label: 'قنوات',
            count: live,
            icon: Icons.live_tv_rounded,
            color: const Color(0xFF4CAF50),
            isSelected: _tabIndex == 1,
            onTap: () => setState(() => _tabIndex = 1),
          ),
          const SizedBox(width: 10),
          _ResultTab(
            label: 'أفلام',
            count: movies,
            icon: Icons.movie_rounded,
            color: const Color(0xFFE91E63),
            isSelected: _tabIndex == 2,
            onTap: () => setState(() => _tabIndex = 2),
          ),
          const SizedBox(width: 10),
          _ResultTab(
            label: 'مسلسلات',
            count: series,
            icon: Icons.tv_rounded,
            color: const Color(0xFF9C27B0),
            isSelected: _tabIndex == 3,
            onTap: () => setState(() => _tabIndex = 3),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  //  الشاشات المساعدة
  // ==========================================================
  Widget _buildHint() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, color: Colors.white24, size: 100),
          SizedBox(height: 20),
          Text(
            'ابحث في كل المحتوى',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'اكتب اسم قناة أو فيلم أو مسلسل',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: Colors.white24,
            size: 90,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد نتائج لـ "$_query"',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'جرّب كلمات أخرى',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Channel> items) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return ChannelCard(
          channel: item,
          width: 200,
          height: 270,
          onTap: () => _openItem(item),
        );
      },
    );
  }

  // ==========================================================
  //  الفتح
  // ==========================================================
  void _openItem(Channel item) {
    ref.read(historyProvider.notifier).record(item);

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
  }
}

// ==========================================================
//  نموذج داخلي (قناة + نقاط)
// ==========================================================
class _ScoredChannel {
  final Channel channel;
  final int score;
  const _ScoredChannel({required this.channel, required this.score});
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
      onFocusChange: (h) => setState(() => _isFocused = h),
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
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _isFocused
                ? const Color(0xFF00C8FF)
                : const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isFocused ? Colors.white : const Color(0xFF2A3350),
              width: _isFocused ? 2.5 : 1.5,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF00C8FF).withOpacity(0.5),
                      blurRadius: 14,
                    ),
                  ]
                : [],
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: _isFocused ? Colors.black : Colors.white70,
            size: 26,
          ),
        ),
      ),
    );
  }
}

// ==========================================================
//  تبويب نتيجة
// ==========================================================
class _ResultTab extends StatefulWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ResultTab({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ResultTab> createState() => _ResultTabState();
}

class _ResultTabState extends State<_ResultTab> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _isFocused;

    return Focus(
      onFocusChange: (h) => setState(() => _isFocused = h),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey.keyLabel;
          if (key == 'Select' || key == 'Enter' || key == 'Space') {
            widget.onTap();
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: _isFocused ? 20 : 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: active ? widget.color : const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : active
                      ? widget.color
                      : const Color(0xFF2A3350),
              width: _isFocused ? 2.5 : 1.5,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.5),
                      blurRadius: 14,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: active ? Colors.black : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: active ? Colors.black : Colors.white70,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.black.withOpacity(0.25)
                      : widget.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.count}',
                  style: TextStyle(
                    color: active ? Colors.white : widget.color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
