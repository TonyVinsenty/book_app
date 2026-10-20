import 'package:book_app/app/theme/page_texture.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every texture but none has a tile', () {
    for (final texture in PageTexture.values) {
      expect(
        texture.image == null,
        texture == PageTexture.none,
        reason: texture.name,
      );
    }
  });

  testWidgets('changing the texture keeps the page state', (tester) async {
    var created = 0;
    final container = ProviderContainer(
      overrides: [readingSettingsProvider.overrideWith(_Unstored.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: TexturedPage(child: _Counted(onCreate: () => created++)),
        ),
      ),
    );
    final notifier = container.read(readingSettingsProvider.notifier);
    for (final texture in [PageTexture.mattress, PageTexture.none]) {
      notifier.set(
        container.read(readingSettingsProvider).copyWith(texture: texture),
      );
      await tester.pump();
    }
    expect(created, 1);
  });
}

/// Shows a change without the settings table.
class _Unstored extends ReadingSettingsNotifier {
  @override
  void set(ReadingSettings next) => state = next;
}

class _Counted extends StatefulWidget {
  const _Counted({required this.onCreate});

  final VoidCallback onCreate;

  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
