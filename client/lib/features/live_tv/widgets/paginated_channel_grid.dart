import 'package:flutter/material.dart';

import '../../../data/models/channel.dart';
import 'channel_card.dart';

/// شبكة قنوات مع Pagination
/// تُحمّل 50 قناة أولاً، ثم 50 إضافية عند الوصول لنهاية القائمة
class PaginatedChannelGrid extends StatefulWidget {
  final List<Channel> channels;
  final ValueChanged<Channel>? onChannelTap;

  /// عدد العناصر في كل دفعة
  final int itemsPerPage;

  /// هوامش الحواف
  final EdgeInsets padding;

  /// نسبة العرض/الارتفاع للبطاقة
  final double aspectRatio;

  const PaginatedChannelGrid({
    super.key,
    required this.channels,
    this.onChannelTap,
    this.itemsPerPage = 50,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 24),
    this.aspectRatio = 0.95,
  });

  @override
  State<PaginatedChannelGrid> createState() => _PaginatedChannelGridState();
}

class _PaginatedChannelGridState extends State<PaginatedChannelGrid> {
  final ScrollController _scrollController = ScrollController();
  late int _visibleCount;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.itemsPerPage.clamp(0, widget.channels.length);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;

    // ✅ عند الوصول إلى 80% من التمرير → حمّل المزيد
    if (position.pixels >= position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_visibleCount >= widget.channels.length) return;

    final newCount = (_visibleCount + widget.itemsPerPage)
        .clamp(0, widget.channels.length);

    if (newCount != _visibleCount) {
      setState(() {
        _visibleCount = newCount;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleChannels = widget.channels.take(_visibleCount).toList();

    return GridView.builder(
      controller: _scrollController,
      padding: widget.padding,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: widget.aspectRatio,
      ),
      itemCount: visibleChannels.length,
      itemBuilder: (context, index) {
        final channel = visibleChannels[index];
        return ChannelCard(
          channel: channel,
          width: 200,
          height: 200,
          onTap: () => widget.onChannelTap?.call(channel),
        );
      },
    );
  }
}
