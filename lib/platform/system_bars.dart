import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows or hides the phone status bar: hidden while reading, shown with
/// the reader panels (ADR 0003, addendum 2 п. 3). Flutter does it itself,
/// no native code; the navigation bar stays as it is.
typedef ShowStatusBar = Future<void> Function(bool shown);

/// Both ways go through `manual`: on Android, `edgeToEdge` uses other means
/// and keeps the status bar from hiding again.
Future<void> _showStatusBar(bool shown) => SystemChrome.setEnabledSystemUIMode(
  SystemUiMode.manual,
  overlays: shown ? SystemUiOverlay.values : [SystemUiOverlay.bottom],
);

/// Tests override it to see the calls.
final showStatusBarProvider = Provider<ShowStatusBar>((ref) => _showStatusBar);
