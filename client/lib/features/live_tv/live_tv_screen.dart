import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/playlist_provider.dart';
import '../../data/providers/history_provider.dart';
import '../../core/animations/app_animations.dart';
import 'widgets/category_tabs.dart';
import 'widgets/sub_category_chips.dart';
import 'widgets/channel_card.dart';
import 'widgets/paginated_channel_grid.dart';
import 'widgets/sports_matches_widget.dart';

/// الشاشة الرئيسية للبث المباشر
class LiveTvScreen extends ConsumerStatefulWidget {
  final List<String> playlistUrls;
  final ValueChanged<Channel>? onChannelTap;

  const LiveTvScreen({
    super.key,
    required this.playlistUrls,
    this.onChannelTap,
  });

  @override
  ConsumerState<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends ConsumerState<LiveTvScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(playlistProvider);
      if (widget.playlistUrls.isNotEmpty &&
          state.allChannels.isEmpty &&
          !state.isLoading) {
        ref
            .read(playlistProvider.notifier)
            .loadPlaylists(widget.playlistUrls);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playlistProvider);
    final notifier = ref.read(playlistProvider.notifier);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(state, notifier),
              if (state.isInitialChecking) _buildInitialCheckBar(state),
              if (state.isLoadingMore) _buildLoadingMoreBar(),
              const SizedBox(height: 16),
              _buildCategorySection(state),
              const SizedBox(height: 12),
              _buildSubCategorySection(state),
              const SizedBox(height: 20),
              Expanded(child: _buildBody(state, notifier)),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  //  شريط الفحص الأولي
  // ==========================================================
  Widget _buildInitialCheckBar(PlaylistState state) {
    final total = state.initialCheckTotal;
    final done = state.initialCheckDone;
    final progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Color(0xFF4CAF50),
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'جارٍ فحص القنوات...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$done / $total  ($percent%)',
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(
                Color(0xFF4CAF50),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'سيتم إخفاء القنوات غير الشغالة تلقائياً',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  //  شريط جلب المزيد
  // ==========================================================
  Widget _buildLoadingMoreBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141A2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              color: Color(0xFF00C8FF),
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'جارٍ جلب قنوات إضافية...',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  //  الشريط العلوي
  // ==========================================================
  Widget _buildTopBar(PlaylistState state, PlaylistNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.sports_soccer_rounded,
              color: Color(0xFF4CAF50),
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'استيتن فرجة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'الرياضية - بث مباشر',
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
            child: Row(
              children: [
                const Icon(
                  Icons.live_tv_rounded,
                  color: Color(0xFF4CAF50),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${state.filteredChannels.length} قناة',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
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
                  hintText: 'ابحث عن قناة رياضية...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF4CAF50),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () {
                      setState(() {
                        _showSearch = false;
                        _searchController.clear();
                        notifier.search('');
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
                onChanged: (value) => notifier.search(value),
              ),
            )
          else
            _TopBarIconButton(
              icon: Icons.search,
              tooltip: 'بحث',
              onPressed: () => setState(() => _showSearch = true),
            ),
          const SizedBox(width: 12),
          _TopBarIconButton(
            icon: Icons.refresh,
            tooltip: 'تحديث',
            onPressed: state.isLoading
                ? null
                : () => notifier.refresh(widget.playlistUrls),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(PlaylistState state) {
    return CategoryTabs(
      categories: state.categories,
      selectedSlug: state.selectedCategorySlug,
      onSelected: (slug) {
        ref.read(playlistProvider.notifier).selectCategory(slug);
      },
    );
  }

  Widget _buildSubCategorySection(PlaylistState state) {
    if (state.selectedCategorySlug == null) {
      return const SizedBox.shrink();
    }

    final currentCat = state.categories.firstWhere(
      (c) => c.slug == state.selectedCategorySlug,
      orElse: () => throw StateError('Category not found'),
    );

    return SubCategoryChips(
      subCategories: currentCat.subCategories,
      selectedSlug: state.selectedSubCategorySlug,
      onSelected: (slug) {
        ref.read(playlistProvider.notifier).selectSubCategory(slug);
      },
    );
  }
  // ==========================================================
//  الجسم
// ==========================================================
Widget _buildBody(PlaylistState state, PlaylistNotifier notifier) {
  if (state.isLoading && state.allChannels.isEmpty) {
    return _buildLoading();
  }

  if (state.error != null && state.allChannels.isEmpty) {
    return _buildError(state.error!);
  }

  if (state.filteredChannels.isEmpty) {
    return _buildEmpty();
  }

  final recentIds = ref.watch(historyProvider).liveIds;
  final showRecent = state.selectedCategorySlug == null &&
      state.searchQuery.isEmpty &&
      recentIds.isNotEmpty;

  if (showRecent) {
    return _buildBodyWithRecent(state, recentIds);
  }

  if (state.selectedCategorySlug == 'sport' &&
      state.selectedSubCategorySlug == null &&
      state.searchQuery.isEmpty) {
    return _buildSportsBody(state);
  }

  return _buildGrid(state);
}

Widget _buildSportsBody(PlaylistState state) {
  return CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: FadeInSlide(
          child: SportsMatchesWidget(
            onChannelTap: (channel) => widget.onChannelTap?.call(channel),
          ),
        ),
      ),
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              SizedBox(
                width: 5,
                height: 24,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF4CAF50),
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'كل القنوات الرياضية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.95,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final channel = state.filteredChannels[i];
              return ChannelCard(
                channel: channel,
                width: 200,
                height: 200,
                onTap: () => widget.onChannelTap?.call(channel),
              );
            },
            childCount: state.filteredChannels.length,
          ),
        ),
      ),
    ],
  );
}

Widget _buildBodyWithRecent(PlaylistState state, List<String> recentIds) {
  final map = {for (final c in state.allChannels) c.id: c};
  final recent = recentIds
      .map((id) => map[id])
      .whereType<Channel>()
      .toList();

  if (recent.isEmpty) return _buildGrid(state);

  return CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: FadeInSlide(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 24,
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
                          fontSize: 20,
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
                          color: const Color(0xFFFFB800).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${recent.length}',
                          style: const TextStyle(
                            color: Color(0xFFFFB800),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    itemCount: recent.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) {
                      return ChannelCard(
                        channel: recent[i],
                        width: 180,
                        height: 200,
                        onTap: () => widget.onChannelTap?.call(recent[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              SizedBox(
                width: 5,
                height: 24,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF4CAF50),
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'كل القنوات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.95,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final channel = state.filteredChannels[i];
              return ChannelCard(
                channel: channel,
                width: 200,
                height: 200,
                onTap: () => widget.onChannelTap?.call(channel),
              );
            },
            childCount: state.filteredChannels.length,
          ),
        ),
      ),
    ],
  );
}
    // ==========================================================
  //  التحميل + الخطأ + الفارغ
  // ==========================================================
  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                ShimmerLoading(width: 120, height: 24),
                SizedBox(width: 12),
                ShimmerLoading(width: 60, height: 24),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ShimmerGrid(
              itemCount: 15,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 64),
          const SizedBox(height: 16),
          const Text(
            'حدث خطأ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => ref
                .read(playlistProvider.notifier)
                .refresh(widget.playlistUrls),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C8FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
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
          Icon(Icons.tv_off_rounded, color: Colors.white24, size: 80),
          SizedBox(height: 16),
          Text(
            'لا توجد قنوات رياضية',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'جرّب تصنيفاً آخر أو ابحث بكلمة مختلفة',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(PlaylistState state) {
    final filterKey = '${state.selectedCategorySlug ?? "all"}_'
        '${state.selectedSubCategorySlug ?? "all"}_'
        '${state.searchQuery}';

    return PaginatedChannelGrid(
      key: ValueKey(filterKey),
      channels: state.filteredChannels,
      onChannelTap: (channel) => widget.onChannelTap?.call(channel),
    );
  }
}
// ==========================================================
//  زر الشريط العلوي
// ==========================================================
class _TopBarIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  State<_TopBarIconButton> createState() => _TopBarIconButtonState();
}

class _TopBarIconButtonState extends State<_TopBarIconButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return Tooltip(
      message: widget.tooltip,
      child: Focus(
        onFocusChange: (hasFocus) {
          setState(() => _isFocused = hasFocus);
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _isFocused
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF141A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFocused ? Colors.white : const Color(0xFF2A3350),
                width: _isFocused ? 2 : 1,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.5),
                        blurRadius: 12,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              widget.icon,
              color: !enabled
                  ? Colors.white24
                  : _isFocused
                      ? Colors.white
                      : Colors.white70,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
