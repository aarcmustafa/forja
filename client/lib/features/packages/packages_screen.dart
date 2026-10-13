import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/playlist_provider.dart';
import '../live_tv/widgets/channel_card.dart';
import '../player/player_screen.dart';

/// شاشة الباقات الرياضية
class PackagesScreen extends ConsumerStatefulWidget {
  const PackagesScreen({super.key});

  @override
  ConsumerState<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends ConsumerState<PackagesScreen> {
  /// الباقات الرياضية الرئيسية
  static const List<Map<String, dynamic>> _sportsPackages = [
    {
      'name': 'beIN Sports',
      'slug': 'bein',
      'icon': Icons.sports_soccer_rounded,
      'color': Color(0xFF00C8FF),
    },
    {
      'name': 'SSC Sports',
      'slug': 'ssc',
      'icon': Icons.sports_soccer_rounded,
      'color': Color(0xFF4CAF50),
    },
    {
      'name': 'AD Sports',
      'slug': 'ad sport',
      'icon': Icons.sports_soccer_rounded,
      'color': Color(0xFFFFB800),
    },
    {
      'name': 'قنوات ألوان',
      'slug': 'alwan',
      'icon': Icons.sports_soccer_rounded,
      'color': Color(0xFFE91E63),
    },
    {
      'name': 'Al Kass',
      'slug': 'alkass',
      'icon': Icons.sports_soccer_rounded,
      'color': Color(0xFF9C27B0),
    },
    {
      'name': 'Dubai Sports',
      'slug': 'dubai sport',
      'icon': Icons.sports_soccer_rounded,
      'color': Color(0xFF00BCD4),
    },
    {
      'name': 'KSA Sports',
      'slug': 'ksa sport',
      'icon': Icons.sports_soccer_rounded,
      'color': Color(0xFF4CAF50),
    },
    {
      'name': 'Shahid Sports',
      'slug': 'shahid',
      'icon': Icons.sports_soccer_rounded,
      'color': Color(0xFFFF5722),
    },
    {
      'name': '1001 Sports',
      'slug': '1001',
      'icon': Icons.sports_soccer_rounded,
      'color': Color(0xFF795548),
    },
  ];

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
              'لا توجد باقات رياضية',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // احسب عدد القنوات لكل باقة
    final packsWithCount = <_PackInfo>[];
    for (final pack in _sportsPackages) {
      final slug = pack['slug'] as String;
      final channels = _findChannels(all, slug);
      if (channels.isNotEmpty) {
        packsWithCount.add(_PackInfo(
          name: pack['name'] as String,
          slug: slug,
          icon: pack['icon'] as IconData,
          color: pack['color'] as Color,
          channels: channels,
        ));
      }
    }

    if (packsWithCount.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد باقات رياضية متاحة',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // رتّب حسب عدد القنوات (الأكثر أولاً)
    packsWithCount.sort((a, b) => b.channels.length.compareTo(a.channels.length));

    return Column(
      children: [
        _buildHeader(all.length, packsWithCount.length),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.2,
            ),
            itemCount: packsWithCount.length,
            itemBuilder: (context, i) {
              final pack = packsWithCount[i];
              return _PackageCard(
                name: pack.name,
                count: pack.channels.length,
                icon: pack.icon,
                color: pack.color,
                onTap: () => _openPackage(pack),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================================
  //  الشريط العلوي
  // ==========================================================
  Widget _buildHeader(int totalChannels, int totalPacks) {
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
                'الباقات الرياضية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'تصفح القنوات الرياضية حسب الباقة',
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
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 16,
                  color: const Color(0xFF2A3350),
                ),
                const SizedBox(width: 12),
                Text(
                  '$totalPacks باقة',
                  style: const TextStyle(
                    color: Color(0xFF00C8FF),
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
  //  البحث عن قنوات باقة
  // ==========================================================
  List<Channel> _findChannels(List<Channel> all, String slug) {
    final lowerSlug = slug.toLowerCase();
    return all.where((c) {
      final name = c.name.toLowerCase();
      final group = c.group.toLowerCase();
      return name.contains(lowerSlug) || group.contains(lowerSlug);
    }).toList();
  }

  // ==========================================================
  //  فتح الباقة
  // ==========================================================
  void _openPackage(_PackInfo pack) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PackageDetailPage(
          title: pack.name,
          color: pack.color,
          channels: pack.channels,
        ),
      ),
    );
  }
}

// ==========================================================
//  نموذج داخلي
// ==========================================================
class _PackInfo {
  final String name;
  final String slug;
  final IconData icon;
  final Color color;
  final List<Channel> channels;

  const _PackInfo({
    required this.name,
    required this.slug,
    required this.icon,
    required this.color,
    required this.channels,
  });
}

// ==========================================================
//  بطاقة باقة
// ==========================================================
class _PackageCard extends StatefulWidget {
  final String name;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PackageCard({
    required this.name,
    required this.count,
    required this.icon,
    required this.color,
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
                      widget.color.withOpacity(0.3),
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
                  ? widget.color
                  : const Color(0xFF2A3350),
              width: _isFocused ? 3 : 1.5,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.4),
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
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isFocused
                        ? widget.color
                        : widget.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    widget.icon,
                    color: _isFocused ? Colors.black : widget.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${widget.count} قناة',
                              style: TextStyle(
                                color: widget.color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_back_ios_rounded,
                  color: _isFocused ? widget.color : Colors.white38,
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
  final Color color;
  final List<Channel> channels;

  const _PackageDetailPage({
    required this.title,
    required this.color,
    required this.channels,
  });

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    _BackButton(onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.sports_soccer_rounded,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
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
