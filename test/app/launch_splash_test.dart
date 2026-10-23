import 'package:book_app/app/launch_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var now = DateTime(2026, 10, 24, 9);

  Future<void> pumpSplash(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: LaunchSplash(clock: () => now, child: const Text('app')),
    ),
  );

  bool splashShown() => find
      .descendant(
        of: find.byType(LaunchSplash),
        matching: find.byType(CustomPaint),
      )
      .evaluate()
      .isNotEmpty;

  Future<void> leaveFor(WidgetTester tester, Duration away) async {
    final binding = tester.binding;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    now = now.add(away);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
  }

  testWidgets('shows on start over the app, then goes away', (tester) async {
    await pumpSplash(tester);
    expect(splashShown(), isTrue);
    expect(find.text('app'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(splashShown(), isTrue);
    await tester.pumpAndSettle();
    expect(splashShown(), isFalse);
  });

  testWidgets('shows again only after an hour away', (tester) async {
    await pumpSplash(tester);
    await tester.pumpAndSettle();

    await leaveFor(tester, const Duration(minutes: 59));
    expect(splashShown(), isFalse);

    await leaveFor(tester, splashAfterAway);
    expect(splashShown(), isTrue);
    await tester.pumpAndSettle();
    expect(splashShown(), isFalse);
  });
}
