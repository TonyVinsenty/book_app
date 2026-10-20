import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the paid features are on (ADR 0004, addendum for stage 10 п. 2):
/// the one check they go through. Always on until the paid tier is decided.
final proUnlockedProvider = Provider<bool>((ref) => true);
