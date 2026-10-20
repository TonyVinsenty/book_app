import 'package:book_app/data/reading_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A pattern drawn over the page color (ROADMAP 8.8а). The tiles are our
/// own (`tool/textures/build_textures.py`): white and black pixels with a
/// small alpha, so they suit every palette, day and night.
enum PageTexture {
  none,
  paper,
  twill,
  scales,
  mattress;

  /// The tile, null for [none].
  AssetImage? get image =>
      this == none ? null : AssetImage('assets/textures/$name.png');

  /// The tile drawn at [opacity] (weaker at night: light pixels stand out
  /// more on a dark page), repeated from the top left.
  DecorationImage? decoration({required bool night}) => switch (image) {
    final image? => DecorationImage(
      image: image,
      repeat: ImageRepeat.repeat,
      alignment: Alignment.topLeft,
      // 512 px tiles cover 256 logical pixels.
      scale: 2,
      opacity: night ? 0.7 : 1,
      filterQuality: FilterQuality.medium,
    ),
    null => null,
  };
}

/// [texture] for its small sample in the settings: on the page it is barely
/// seen, so here it is drawn smaller, to fit a few repeats, and several
/// times over itself, so it is stronger; more at night, where the
/// light pixels are weak on a dark page (owner, 2026-10-21).
class TextureSample extends StatelessWidget {
  const TextureSample({super.key, required this.texture});

  final PageTexture texture;

  @override
  Widget build(BuildContext context) {
    final image = texture.image;
    if (image == null) return const SizedBox.expand();
    final night = Theme.of(context).brightness == Brightness.dark;
    final layers = night ? 7 : 4;
    final layer = DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: image,
          repeat: ImageRepeat.repeat,
          alignment: Alignment.topLeft,
          // 512 px tiles cover 170 logical pixels: two or three scales or
          // cushions across the sample.
          scale: 3,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [for (var i = 0; i < layers; i++) layer],
    );
  }
}

/// The chosen [PageTexture] behind [child], painted once in its own layer
/// so turning pages does not repaint it.
class TexturedPage extends ConsumerWidget {
  const TexturedPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texture = ref.watch(readingSettingsProvider.select((s) => s.texture));
    final night = Theme.of(context).brightness == Brightness.dark;
    // The same tree with or without a texture: [child] keeps its state.
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: texture.decoration(night: night),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
