import 'dart:io';
import 'dart:math';

import 'package:book_app/layout/chapter_layout.dart';
import 'package:flutter/material.dart';

/// Night pictures are a little darker, not to glare (ADR 0008 п. 6).
const _nightDim = Color(0x2E000000);

/// The pictures of [page] at their places over the page text (ADR 0008
/// п. 6): decoded no larger than shown, a frame with an icon if the file
/// is broken or gone.
class PageImages extends StatelessWidget {
  const PageImages({
    super.key,
    required this.chapter,
    required this.page,
    required this.imagesDir,
    required this.dim,
    required this.frameColor,
  });

  final ChapterLayout chapter;
  final int page;
  final Directory imagesDir;

  /// Night theme: darken a little.
  final bool dim;
  final Color frameColor;

  @override
  Widget build(BuildContext context) {
    final images = chapter.pageImages(page);
    if (images.isEmpty) return const SizedBox.shrink();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return SizedBox.fromSize(
      size: chapter.pageSize,
      child: Stack(
        children: [
          for (final image in images)
            Positioned.fromRect(
              rect: image.rect,
              child: Image(
                image: pageImageProvider(imagesDir, image, ratio),
                fit: BoxFit.fill,
                gaplessPlayback: true,
                color: dim ? _nightDim : null,
                colorBlendMode: dim ? BlendMode.srcATop : null,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: frameColor),
                  ),
                  child: Center(
                    child: Icon(Icons.broken_image_outlined, color: frameColor),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The picture decoded at the width it takes on screen, not more than its
/// own: memory stays bounded by the screen (ADR 0008 п. 6).
ImageProvider pageImageProvider(
  Directory imagesDir,
  PageImage image,
  double devicePixelRatio,
) => ResizeImage(
  FileImage(File('${imagesDir.path}/${image.assetId}')),
  width: min(image.width, (image.rect.width * devicePixelRatio).ceil()),
);

/// Decodes the pictures of [pages] ahead, so turning to them shows them at
/// once.
void precachePageImages(
  BuildContext context,
  ChapterLayout chapter,
  Iterable<int> pages,
  Directory imagesDir,
) {
  final ratio = MediaQuery.devicePixelRatioOf(context);
  for (final page in pages) {
    if (page < 0 || page >= chapter.pages.length) continue;
    for (final image in chapter.pageImages(page)) {
      precacheImage(
        pageImageProvider(imagesDir, image, ratio),
        context,
        onError: (_, _) {},
      );
    }
  }
}
