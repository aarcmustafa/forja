import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/channel.dart';
import '../../data/providers/playlist_provider.dart';
import 'widgets/category_tabs.dart';
import 'widgets/sub_category_chips.dart';
import 'widgets/channel_card.dart';

/// الشاشة الرئيسية للبث المباشر
/// تجمع: التصنيفات + الباقات + شبكة القنوات + البحث + التحديث
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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    // ⚠️ لا نحمّل هنا — التحميل يتم من HomeScreen عند فتح التطبيق
    // نكتفي بتحميل احتياطي فقط إذا لم تكن هناك قنوات
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
    _scrollController.dispose();
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
  //  الشريط العلوي: عنوان + بحث + تحديث
  // ==========================================================
  Widget _buildTopBar(PlaylistState state, PlaylistNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // الشعار والاسم
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00C8FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.play_circle_fill,
              color: Color(0xFF00C8FF),
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
                'بث مباشر',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(width: 24),

          // عدّاد القنوات
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
                  color: Color(0xFF00C8FF),
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

          // حقل البحث (يظهر عند الضغط على أيقونة البحث)
          if (_showSearch)
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ابحث عن قناة...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF00C8FF),
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

  // ==========================================================
  //  قسم التصنيفات الرئيسية
  // ==========================================================
  Widget _buildCategorySection(PlaylistState state) {
    return CategoryTabs(
      categories: state.categories,
      selectedSlug: state.selectedCategorySlug,
      onSelected: (slug) {
        ref.read(playlistProvider.notifier).selectCategory(slug);
      },
    );
  }

  // ==========================================================
  //  قسم الباقات الفرعية
  // ==========================================================
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
  //  جسم الشاشة: شبكة القنوات / تحميل / خطأ / فارغ
  // ==========================================================
  Widget _buildBody(PlaylistState state, PlaylistNotifier notifier) {
    // 1) التحميل
    if (state.isLoading && state.allChannels.isEmpty) {
      return _buildLoading();
    }

    // 2) الخطأ
    if (state.error != null && state.allChannels.isEmpty) {
      return _buildError(state.error!);
    }

    // 3) فارغ
    if (state.filteredChannels.isEmpty) {
      return _buildEmpty();
    }

    // 4) شبكة القنوات
    return _buildGrid(state);
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF00C8FF),
            strokeWidth: 3,
          ),
          SizedBox(height: 20),
          Text(
            'جارٍ تحميل القنوات...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
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
          const
