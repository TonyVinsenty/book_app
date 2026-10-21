import 'dart:async';

import 'package:book_app/data/folders/folder_scanner.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Looks for new books in the folders (ADR 0007): after the first frame,
/// so the last book opens without waiting, and on every return to the app.
class FolderScans extends ConsumerStatefulWidget {
  const FolderScans({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FolderScans> createState() => _FolderScansState();
}

class _FolderScansState extends ConsumerState<FolderScans> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _scan);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scan();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _scan() => unawaited(ref.read(scanFoldersProvider)());

  @override
  Widget build(BuildContext context) => widget.child;
}
