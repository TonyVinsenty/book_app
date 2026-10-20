import 'package:flutter/material.dart';

/// A short message at the bottom that a tap on it closes (owner,
/// 2026-10-21); every snack bar of the app goes through here.
void showNotice(
  BuildContext context,
  String text, {
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
  bool? persist,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      // The padding moves inside, so the whole bar takes the tap.
      padding: EdgeInsets.zero,
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: messenger.hideCurrentSnackBar,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            24,
            14,
            action == null ? 24 : 0,
            14,
          ),
          child: Text(text),
        ),
      ),
      action: action,
      duration: duration,
      persist: persist,
    ),
  );
}
