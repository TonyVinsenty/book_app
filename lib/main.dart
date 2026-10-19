import 'package:book_app/app/app.dart';
import 'package:book_app/app/font_licenses.dart';
import 'package:book_app/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final overrides = await openStorageOverrides();
  runApp(ProviderScope(overrides: overrides, child: const BookApp()));
}
