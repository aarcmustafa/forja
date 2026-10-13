import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/playlist_provider.dart';
import '../../data/providers/favorites_provider.dart';
import '../live_tv/widgets/channel_card.dart';
import '../player/player_screen.dart';

/// شاشة المفضلة الرياضية
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String? _selectedCountry;

  // الدول العربية الشائعة
  static const List<Map<String, String>> _countries = [
    {'code': 'SA', 'label': 'السعودية'},
    {'code': 'AE', 'label': 'الإمارات'},
    {'code': 'EG', 'label': 'مصر'},
    {'code': 'MA', 'label': 'المغرب'},
    {'code': 'DZ', 'label': 'الجزائر'},
    {'code': 'TN', 'label': 'تونس'},
    {'code': 'IQ', 'label': 'العراق'},
    {'code': 'KW', 'label': 'الكويت'},
    {'code': 'QA', 'label': 'قطر'},
    {'code': 'JO', 'label': 'الأردن'},
  ];

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(favoritesProvider);
    final all = ref.watch(playlistProvider).allChannels;

    // تجميع المفضلة
    var favorites = all.where((c) => ids.contains(c.id)).toList();

    // فلتر الدولة
    if (_selectedCountry != null) {
      favorites = favorites
          .where((c) => c.countryCode == _selectedCountry)
          .toList();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(ids.length),
              const SizedBox(height: 16),
              _buildCountryFilters(),
              const SizedBox(height: 20),
              Expanded(
                child: favorites.isEmpty
                    ? _buildEmpty()
                    : _buildGrid(favorites),
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
                'قنواتك الرياضية المفضلة',
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
                  '$total قناة',
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
  //  فلاتر الدول
  // ==========================================================
  Widget _buildCountryFilters() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        itemCount: _countries.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _CountryChip(
              label: 'الكل',
              isSelected: _selectedCountry == null,
              onTap: () => setState(() => _selectedCountry = null),
            );
          }
          final c = _countries[i - 1];
          return _CountryChip(
            label: c['label']!,
            isSelected: _selectedCountry == c['code'],
            onTap: () => setState(() => _selectedCountry = c['code']),
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
            'لا توجد قنوات في المفضلة',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'اضغط ⭐ على أي قناة رياضية لإضافتها',
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
        childAspectRatio: 0.95,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return Stack(
          children: [
            ChannelCard(
              channel: item,
              width: 200,
              height: 200,
              onTap: () => _openChannel(item),
            ),
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

  void _openChannel(Channel channel) {
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
//  شريحة الدولة
// ==========================================================
class _CountryChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CountryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CountryChip> createState() => _CountryChipState();
}

class _CountryChipState extends State<_CountryChip> {
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
                ? const Color(0xFF00C8FF)
                : const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : active
                      ? const Color(0xFF00C8FF)
                      : const Color(0xFF2A3350),
              width: _isFocused ? 2.5 : 1.5,
            ),
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
