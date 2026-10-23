import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// The tests read the Russian texts: the phone language is Russian unless a
/// test sets another.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('ru', 'RU'),
    ];
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearLocalesTestValue();
  });
  await testMain();
}
