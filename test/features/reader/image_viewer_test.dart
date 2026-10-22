import 'dart:io';
import 'dart:ui' as ui;

import 'package:book_app/features/reader/image_viewer.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late File picture;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('viewer_test');
    picture = File('${dir.path}/1.png');
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.teal, BlendMode.src);
    final image = await recorder.endRecording().toImage(40, 60);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.writeAsBytesSync(png!.buffer.asUint8List());
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> openViewer(WidgetTester tester, File file) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => ImageViewerScreen.open(
              context,
              file: file,
              width: 40,
              height: 60,
              dim: false,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsOneWidget);
  }

  double scale(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!
      .value
      .getMaxScaleOnAxis();

  Future<void> doubleTap(WidgetTester tester) async {
    final center = tester.getCenter(find.byType(ImageViewerScreen));
    await tester.tapAt(center);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(center);
    await tester.pumpAndSettle();
  }

  testWidgets('a double tap zooms in and back out; a tap closes', (
    tester,
  ) async {
    await openViewer(tester, picture);
    expect(scale(tester), 1);

    await doubleTap(tester);
    expect(scale(tester), closeTo(2.5, 0.01));
    expect(find.byType(ImageViewerScreen), findsOneWidget);

    await doubleTap(tester);
    expect(scale(tester), closeTo(1, 0.01));

    // A single tap waits to be sure it is not a double one.
    await tester.tap(find.byType(ImageViewerScreen));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short swipe down springs back, a long one closes', (
    tester,
  ) async {
    await openViewer(tester, picture);
    final viewer = find.byType(InteractiveViewer);

    await tester.timedDrag(
      viewer,
      const Offset(0, 60),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsOneWidget);
    expect(
      tester
          .widget<Transform>(
            find.ancestor(of: viewer, matching: find.byType(Transform)).first,
          )
          .transform
          .getTranslation()
          .y,
      0,
    );

    await tester.drag(viewer, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsNothing);
  });

  testWidgets('a zoomed picture pans, it does not close', (tester) async {
    await openViewer(tester, picture);
    await doubleTap(tester);
    await tester.drag(find.byType(InteractiveViewer), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsOneWidget);
  });

  testWidgets('back closes; a lost picture is an icon', (tester) async {
    await openViewer(tester, File('${dir.path}/lost.png'));
    for (
      var i = 0;
      i < 50 && find.byIcon(Icons.broken_image_outlined).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
