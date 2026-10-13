import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/playlist_provider.dart';
import '../../data/providers/history_provider.dart';
import '../live_tv/widgets/channel_card.dart';
import '../player/player_screen.dart';

/// البحث الموحد — رياضة فقط
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 16),
              Expanded(
                child: _query.trim().isEmpty
                    ? _buildHint()
                    : results.isEmpty
                        ? _buildNoResults()
                        : _buildGrid(results),
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
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    final results = <_ScoredChannel>[];

    for (final c in all) {
      final name = c.name.toLowerCase();
      final group = c.group.toLowerCase();
      final country = c.countryLabel.toLowerCase();

      int score = 0;
      int matches = 0;

      for (final w in words) {
        int wordScore = 0;

        if (name == w) {
          wordScore += 100;
        } else if (name.startsWith(w)) {
          wordScore += 50;
        } else if (name.contains(w)) {
          wordScore += 30;
        }

        if (group.contains(w)) wordScore += 15;
        if (country.contains(w)) wordScore += 10;

        if (wordScore > 0) {
          matches++;
          score += wordScore;
        }
      }

      if (matches == words.length && score > 0) {
        results.add(_ScoredChannel(channel: c, score: score));
      }
    }

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
                        hintText: 'ابحث عن قناة رياضية...',
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
  //  الشاشات المساعدة
  // ==========================================================
  Widget _buildHint() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_soccer_rounded,
            color: Colors.white24,
            size: 100,
          ),
          SizedBox(height: 20),
          Text(
            'ابحث في القنوات الرياضية',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'beIN, SSC, AD Sports, Alwan...',
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C8FF),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${items.length} نتيجة',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.95,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return ChannelCard(
                channel: item,
                width: 200,
                height: 200,
                onTap: () => _openChannel(item),
              );
            },
          ),
        ),
      ],
    );
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
}

// ==========================================================
//  نموذج داخلي
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
