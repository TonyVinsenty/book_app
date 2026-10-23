import 'package:book_app/layout/strip_map.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';

/// The pages as one seamless scroll (ADR 0003, addendum 5 п. 4): chapters
/// one under another, the top of chapter [StripMap.center] at offset 0. A
/// laid-out chapter is its pages, each only as tall as its text
/// ([StripPages.pageExtent]); chapters not laid out are blank space of their
/// estimated height, laid out by the reader before they reach the window.
class PageStrip extends StatelessWidget {
  const PageStrip({
    super.key,
    required this.map,
    required this.controller,
    required this.tile,
    this.physics,
  });

  final StripMap map;
  final ScrollController controller;

  /// Page [page] of laid-out chapter [section] ([pages], as the strip was
  /// built with it), as tall as its extent.
  final Widget Function(int section, StripPages pages, int page) tile;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: physics,
      center: ValueKey<int>(map.center),
      // Tiles are built only near the window (ADR 0003, addendum 5 п. 4).
      scrollCacheExtent: const ScrollCacheExtent.viewport(0.5),
      slivers: [
        // Room above the book: its first line comes to the window top.
        SliverToBoxAdapter(child: SizedBox(height: map.windowTop)),
        ..._chapters(),
      ],
    );
  }

  /// A sliver per laid-out chapter; a run of chapters not laid out is one
  /// blank box (the center starts a sliver of its own).
  Iterable<Widget> _chapters() sync* {
    var s = 0;
    while (s < map.sectionCount) {
      final pages = map.pagesOf(s);
      if (pages != null) {
        yield _chapter(s, pages);
        s++;
        continue;
      }
      final first = s;
      var height = 0.0;
      do {
        height += map.chapterExtent(s);
        s++;
      } while (s < map.sectionCount &&
          s != map.center &&
          map.pagesOf(s) == null);
      yield SliverToBoxAdapter(
        key: ValueKey<int>(first),
        child: SizedBox(height: height),
      );
    }
  }

  Widget _chapter(int section, StripPages pages) => SliverPadding(
    key: ValueKey<int>(section),
    padding: EdgeInsets.only(top: map.gapBefore(section)),
    sliver: SliverVariedExtentList(
      itemExtentBuilder: (i, _) =>
          i < pages.pageCount ? pages.pageExtent(i) : null,
      delegate: SliverChildBuilderDelegate(
        (_, i) => tile(section, pages, i),
        childCount: pages.pageCount,
      ),
    ),
  );
}
