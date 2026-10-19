import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Native file access (ADR 0005): `MainActivity.kt`, later `AppDelegate.swift`.
const filesChannelName = 'com.tonyvinsenty.bookapp/files';
const pickBooksMethod = 'pickBooks';

/// Lets the user choose book files; returns paths to private copies in the
/// cache folder (empty when cancelled). The caller deletes the copies.
typedef PickBooks = Future<List<String>> Function();

const _channel = MethodChannel(filesChannelName);

Future<List<String>> _pickBooks() async {
  final paths = await _channel.invokeListMethod<String>(pickBooksMethod);
  return paths ?? const [];
}

/// Tests override it with a fake.
final pickBooksProvider = Provider<PickBooks>((ref) => _pickBooks);
