import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/playlist_provider.dart';
import '../live_tv/widgets/channel_card.dart';
import '../player/player_screen.dart';

/// شاشة المسلسلات — تعرض كل ما هو contentType == 'series'
class SeriesScreen extends ConsumerStatefulWidget {
  final ValueChanged<Channel>? onSeriesTap;

  const SeriesScreen({super.key, this.onSeriesTap});

  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> {
  String? _selectedLanguage;
  String? _selectedGenre;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<Map<String, String>> _languages = [
    {'code': 'ara', 'label': 'عربي'},
    {'code': 'tur', 'label': 'تركي'},
    {'code': 'hin', 'label': 'هندي'},
    {'code': 'eng', 'label': 'أجنبي'},
    {'code': 'anime', 'label': 'أنمي'},
    {'code': 'asian', 'label': 'أسيوي'},
    {'code': 'kor', 'label': 'كوري'},
    {'code': 'jpn', 'label': 'ياباني'},
  ];

  static const List<Map<String, String>> _genres = [
    {'code': 'action', 'label': 'أكشن'},
    {'code': 'drama', 'label': 'دراما'},
    {'code': 'comedy', 'label': 'كوميدي'},
    {'code': 'romance', 'label': 'رومانسي'},
    {'code': 'thriller', 'label': 'إثارة'},
    {'code': 'crime', 'label': 'جريمة'},
    {'code': 'mystery', 'label': 'غموض'},
    {'code': 'history', 'label': 'تاريخي'},
    {'code': 'war', 'label': 'حربي'},
    {'code': 'family', 'label': 'عائلي'},
    {'code': 'fantasy', 'label': 'فانتازيا'},
    {'code': 'kids', 'label': 'أطفال'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Channel> _applyFilters(List<Channel> all) {
    List<Channel> series =
        all.where((c) => c.contentType == 'series').toList();

    if (_selectedLanguage != null) {
      series = series.where((c) => c.language == _selectedLanguage).toList();
    }
    if (_selectedGenre != null) {
      series = series.where((c) => c.genre == _selectedGenre).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      series = series.where((c) => c.matchesQuery(_searchQuery)).toList();
    }

    return series;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playlistProvider);
    final allSeries =
        state.allChannels.where((c) => c.contentType == 'series').toList();
    final filtered = _applyFilters(state.allChannels);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(state, allSeries.length, filtered.length),
              const SizedBox(height: 16),
              _buildLanguageFilters(),
              const SizedBox(height: 12),
              _buildGenreFilters(),
              const SizedBox(height: 20),
              Expanded(child: _buildBody(state, filtered)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(PlaylistState state, int total, int shown) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00C8FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.tv_rounded,
              color: Color(0xFF00C8FF),
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المسلسلات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'مكتبة المسلسلات',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF141A2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2A3350)),
            ),
            child: Text(
              '$shown من $total',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const Spacer(),
          if (_showSearch)
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ابحث عن مسلسل...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF00C8FF)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () {
                      setState(() {
                        _showSearch = false;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFF141A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            )
          else
            _IconBtn(
              icon: Icons.search,
              tooltip: 'بحث',
              onPressed: () => setState(() => _showSearch = true),
            ),
          const SizedBox(width: 12),
          _IconBtn(
            icon: Icons.filter_alt_off_rounded,
            tooltip: 'مسح الفلاتر',
            onPressed: () {
              setState(() {
                _selectedLanguage = null;
                _selectedGenre = null;
                _searchQuery = '';
                _searchController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageFilters() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _languages.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _FilterChip(
              label: 'الكل',
              isSelected: _selectedLanguage == null,
              onTap: () => setState(() => _selectedLanguage = null),
            );
          }
          final lang = _languages[i - 1];
          return _FilterChip(
            label: lang['label']!,
            isSelected: _selectedLanguage == lang['code'],
            onTap: () => setState(() => _selectedLanguage = lang['code']),
          );
        },
      ),
    );
  }

  Widget _buildGenreFilters() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _genres.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _FilterChip(
              label: 'كل الأنواع',
              isSelected: _selectedGenre == null,
              isSecondary: true,
              onTap: () => setState(() => _selectedGenre = null),
            );
          }
          final genre = _genres[i - 1];
          return _FilterChip(
            label: genre['label']!,
            isSelected: _selectedGenre == genre['code'],
            isSecondary: true,
            onTap: () => setState(() => _selectedGenre = genre['code']),
          );
        },
      ),
    );
  }

  Widget _buildBody(PlaylistState state, List<Channel> series) {
    if (state.isLoading && state.allChannels.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                color: Color(0xFF00C8FF), strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'جارٍ تحميل المسلسلات...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }
    if (series.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_off_rounded, color: Colors.white24, size: 80),
            SizedBox(height: 16),
            Text(
              'لا توجد مسلسلات',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              'جرّب فلتراً آخر أو ابحث بكلمة مختلفة',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: series.length,
      itemBuilder: (context, index) {
        final item = series[index];
        return ChannelCard(
          channel: item,
          width: 200,
          height: 270,
          onTap: () {
            if (widget.onSeriesTap != null) {
              widget.onSeriesTap!(item);
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
    );
  }
}

// ==========================================================
//  فلتر (Chip) قابل للتركيز
// ==========================================================
class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final bool isSecondary;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _isFocused;
    final Color activeColor =
        widget.isSecondary ? const Color(0xFFFFB800) : const Color(0xFF00C8FF);

    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
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
            color: active ? activeColor : const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : active
                      ? activeColor
                      : const Color(0xFF2A3350),
              width: _isFocused ? 2.5 : 1.5,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.5),
                      blurRadius: 14,
                    ),
                  ]
                : [],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: active ? Colors.black : Colors.white70,
              fontSize: 13,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================
//  زر أيقونة
// ==========================================================
class _IconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
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
                color: _isFocused
                    ? Colors.white
                    : const Color(0xFF2A3350),
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
              widget.icon,
              color: _isFocused ? Colors.black : Colors.white70,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
