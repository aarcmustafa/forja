import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/playlist_provider.dart';
import '../../data/providers/favorites_provider.dart';
import '../live_tv/widgets/channel_card.dart';
import '../movies/movie_detail_screen.dart';
import '../player/player_screen.dart';

/// شاشة المفضلة
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  int _tabIndex = 0; // 0=الكل, 1=قنوات, 2=أفلام, 3=مسلسلات

  final List<String> _tabLabels = const [
    'الكل',
    'قنوات',
    'أفلام',
    'مسلسلات',
  ];

  final List<IconData> _tabIcons = const [
    Icons.favorite_rounded,
    Icons.live_tv_rounded,
    Icons.movie_rounded,
    Icons.tv_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(favoritesProvider);
    final all = ref.watch(playlistProvider).allChannels;

    // تجميع المفضلة
    final favorites = all.where((c) => ids.contains(c.id)).toList();
    final liveFavs =
        favorites.where((c) => c.contentType == 'live').toList();
    final movieFavs =
        favorites.where((c) => c.contentType == 'movie').toList();
    final seriesFavs =
        favorites.where((c) => c.contentType == 'series').toList();

    // حسب التبويب
    final currentList = switch (_tabIndex) {
      0 => favorites,
      1 => liveFavs,
      2 => movieFavs,
      3 => seriesFavs,
      _ => favorites,
    };

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(favorites.length),
              const SizedBox(height: 16),
              _buildTabs(),
              const SizedBox(height: 20),
              Expanded(
                child: currentList.isEmpty
                    ? _buildEmpty()
                    : _buildGrid(currentList),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  //  العنوان
  // ==========================================================
  Widget _buildHeader(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF1744).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFFF1744),
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المفضلة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'قنواتك وأفلامك المفضلة',
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
                  Icons.star_rounded,
                  color: Color(0xFFFFB800),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '$total عنصر',
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
  //  التبويبات
  // ==========================================================
  Widget _buildTabs() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        itemCount: _tabLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          return _TabButton(
            label: _tabLabels[i],
            icon: _tabIcons[i],
            isSelected: _tabIndex == i,
            onTap: () => setState(() => _tabIndex = i),
          );
        },
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
          Icon(
            Icons.favorite_border_rounded,
            color: Colors.white24,
            size: 80,
          ),
          SizedBox(height: 16),
          Text(
            'لا توجد عناصر في المفضلة',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'اضغط ⭐ على أي قناة أو فيلم لإضافته',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  //  شبكة
  // ==========================================================
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
        return Stack(
          children: [
            ChannelCard(
              channel: item,
              width: 200,
              height: 270,
              onTap: () => _openItem(item),
            ),
            // زر الإزالة
            Positioned(
              top: 8,
              left: 8,
              child: _RemoveButton(
                onTap: () async {
                  await ref
                      .read(favoritesProvider.notifier)
                      .remove(item.id);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openItem(Channel item) {
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
//  زر التبويب
// ==========================================================
class _TabButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
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
            color: active
                ? const Color(0xFFFF1744)
                : const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : active
                      ? const Color(0xFFFF1744)
                      : const Color(0xFF2A3350),
              width: _isFocused ? 2.5 : 1.5,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF1744).withOpacity(0.5),
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
                color: active ? Colors.white : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
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
//  زر الإزالة
// ==========================================================
class _RemoveButton extends StatefulWidget {
  final VoidCallback onTap;

  const _RemoveButton({required this.onTap});

  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _isFocused
                ? const Color(0xFFFF1744)
                : Colors.black.withOpacity(0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.white24,
              width: _isFocused ? 2.5 : 1,
            ),
          ),
          child: Icon(
            Icons.close_rounded,
            color: _isFocused ? Colors.white : Colors.white70,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ==========================================================
//  دالة مساعدة: زر المفضلة القابل للاستخدام في أي مكان
// ==========================================================
class FavoriteButton extends ConsumerWidget {
  final String channelId;
  final double size;
  final bool showLabel;

  const FavoriteButton({
    super.key,
    required this.channelId,
    this.size = 44,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider).contains(channelId);

    return _FavoriteButtonInner(
      isFavorite: isFav,
      size: size,
      showLabel: showLabel,
      onTap: () {
        ref.read(favoritesProvider.notifier).toggle(channelId);
      },
    );
  }
}

class _FavoriteButtonInner extends StatefulWidget {
  final bool isFavorite;
  final double size;
  final bool showLabel;
  final VoidCallback onTap;

  const _FavoriteButtonInner({
    required this.isFavorite,
    required this.size,
    required this.showLabel,
    required this.onTap,
  });

  @override
  State<_FavoriteButtonInner> createState() => _FavoriteButtonInnerState();
}

class _FavoriteButtonInnerState extends State<_FavoriteButtonInner> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isFavorite || _isFocused;

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
          width: widget.showLabel ? null : widget.size,
          height: widget.size,
          padding: widget.showLabel
              ? const EdgeInsets.symmetric(horizontal: 20)
              : null,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFFF1744)
                : const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? Colors.white : const Color(0xFF2A3350),
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF1744).withOpacity(0.5),
                      blurRadius: 14,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: active ? Colors.white : Colors.white70,
                size: widget.size * 0.5,
              ),
              if (widget.showLabel) ...[
                const SizedBox(width: 8),
                Text(
                  widget.isFavorite ? 'في المفضلة' : 'أضف للمفضلة',
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
