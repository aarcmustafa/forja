import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/playlist_provider.dart';
import '../live_tv/widgets/channel_card.dart';
import '../player/player_screen.dart';

/// شاشة الباقات - تعرض كل الباقات منظمة في بطاقات كبيرة
class PackagesScreen extends ConsumerStatefulWidget {
  const PackagesScreen({super.key});

  @override
  ConsumerState<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends ConsumerState<PackagesScreen> {
  String? _selectedCategory;

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
              'جارٍ تحميل الباقات...',
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
            Icon(Icons.list_rounded, color: Colors.white24, size: 80),
            SizedBox(height: 16),
            Text(
              'لا توجد باقات',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // تجميع حسب الباقة (group)
    final grouped = _groupByCategory(all);
    final categories = grouped.keys.toList();
    categories.sort();

    return Column(
      children: [
        _buildHeader(state, all.length, grouped.length),
        const SizedBox(height: 16),
        _buildCategoryChips(categories),
        const SizedBox(height: 20),
        Expanded(child: _buildGrid(grouped)),
      ],
    );
  }

  // تجميع القنوات حسب التصنيف الرئيسي ثم الباقة
  Map<String, List<Channel>> _groupByCategory(List<Channel> all) {
    final map = <String, List<Channel>>{};
    for (final c in all) {
      final key = c.category;
      map.putIfAbsent(key, () => []).add(c);
    }
    return map;
  }

  // تجميع القنوات حسب المجموعة (الباقة)
  Map<String, List<Channel>> _groupByPackage(List<Channel> channels) {
    final map = <String, List<Channel>>{};
    for (final c in channels) {
      final key = c.group.isEmpty ? 'غير مصنف' : c.group;
      map.putIfAbsent(key, () => []).add(c);
    }
    return map;
  }

  String _categoryLabel(String slug) {
    switch (slug) {
      case 'sport':
        return 'رياضة';
      case 'movie':
        return 'أفلام';
      case 'series':
        return 'مسلسلات';
      case 'news':
        return 'أخبار';
      case 'kids':
        return 'أطفال';
      case 'documentary':
        return 'وثائقي';
      case 'music':
        return 'موسيقى';
      case 'religious':
        return 'ديني';
      default:
        return 'عام';
    }
  }

  IconData _categoryIcon(String slug) {
    switch (slug) {
      case 'sport':
        return Icons.sports_soccer_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'series':
        return Icons.tv_rounded;
      case 'news':
        return Icons.newspaper_rounded;
      case 'kids':
        return Icons.child_care_rounded;
      case 'documentary':
        return Icons.camera_roll_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'religious':
        return Icons.mosque_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  // ==========================================================
  //  الشريط العلوي
  // ==========================================================
  Widget _buildHeader(PlaylistState state, int totalChannels, int totalPacks) {
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
              Icons.list_rounded,
              color: Color(0xFF00C8FF),
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الباقات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'تصفح كل القنوات حسب الباقة',
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
                  Icons.live_tv_rounded,
                  color: Color(0xFFFFB800),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '$totalChannels قناة',
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
  //  شرائح التصنيفات
  // ==========================================================
  Widget _buildCategoryChips(List<String> categories) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _CategoryChip(
              label: 'الكل',
              icon: Icons.apps_rounded,
              isSelected: _selectedCategory == null,
              onTap: () => setState(() => _selectedCategory = null),
            );
          }
          final cat = categories[i - 1];
          return _CategoryChip(
            label: _categoryLabel(cat),
            icon: _categoryIcon(cat),
            isSelected: _selectedCategory == cat,
            onTap: () => setState(() => _selectedCategory = cat),
          );
        },
      ),
    );
  }

  // ==========================================================
  //  شبكة الباقات
  // ==========================================================
  Widget _buildGrid(Map<String, List<Channel>> grouped) {
    // تحديد القنوات المعروضة
    final selectedChannels = _selectedCategory == null
        ? grouped.values.expand((e) => e).toList()
        : grouped[_selectedCategory] ?? [];

    // تجميع حسب الباقة
    final packs = _groupByPackage(selectedChannels);

    if (packs.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد باقات في هذا التصنيف',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // ترتيب الباقات حسب عدد القنوات (الأكثر أولاً)
    final sortedPacks = packs.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.2,
      ),
      itemCount: sortedPacks.length,
      itemBuilder: (context, index) {
        final pack = sortedPacks[index];
        return _PackageCard(
          name: pack.key,
          count: pack.value.length,
          channels: pack.value,
          onTap: () => _openPackage(pack.key, pack.value),
        );
      },
    );
  }

  // ==========================================================
  //  فتح الباقة
  // ==========================================================
  void _openPackage(String name, List<Channel> channels) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PackageDetailPage(
          title: name,
          channels: channels,
        ),
      ),
    );
  }
}

// ==========================================================
//  شريحة تصنيف
// ==========================================================
class _CategoryChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _isFocused;

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
            color: active ? const Color(0xFF00C8FF) : const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : active
                      ? const Color(0xFF00C8FF)
                      : const Color(0xFF2A3350),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: active ? Colors.black : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: active ? Colors.black : Colors.white70,
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
//  بطاقة باقة
// ==========================================================
class _PackageCard extends StatefulWidget {
  final String name;
  final int count;
  final List<Channel> channels;
  final VoidCallback onTap;

  const _PackageCard({
    required this.name,
    required this.count,
    required this.channels,
    required this.onTap,
  });

  @override
  State<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<_PackageCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
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
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: _isFocused
                  ? [
                      const Color(0xFF00C8FF).withOpacity(0.3),
                      const Color(0xFF141A2E),
                    ]
                  : [
                      const Color(0xFF1A2238),
                      const Color(0xFF141A2E),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isFocused
                  ? const Color(0xFF00C8FF)
                  : const Color(0xFF2A3350),
              width: _isFocused ? 3 : 1.5,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF00C8FF).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // أيقونة
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isFocused
                        ? const Color(0xFF00C8FF)
                        : const Color(0xFF00C8FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.live_tv_rounded,
                    color: _isFocused ? Colors.black : const Color(0xFF00C8FF),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // الاسم والعدد
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB800).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.count} قناة',
                              style: const TextStyle(
                                color: Color(0xFFFFB800),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // سهم
                Icon(
                  Icons.arrow_back_ios_rounded,
                  color: _isFocused ? const Color(0xFF00C8FF) : Colors.white38,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================
//  صفحة تفاصيل الباقة
// ==========================================================
class _PackageDetailPage extends StatelessWidget {
  final String title;
  final List<Channel> channels;

  const _PackageDetailPage({required this.title, required this.channels});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: Column(
            children: [
              // الشريط العلوي
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${channels.length} قناة',
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

              // الشبكة
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: channels.length,
                  itemBuilder: (context, i) {
                    final ch = channels[i];
                    return ChannelCard(
                      channel: ch,
                      width: 200,
                      height: 200,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(
                              streamUrl: ch.streamUrl,
                              channelName: ch.name,
                              channelLogo: ch.logo,
                            ),
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
