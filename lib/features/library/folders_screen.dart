import 'dart:async';

import 'package:book_app/app/notice.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/folders/folder_scan.dart';
import 'package:book_app/data/folders/folder_scanner.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

void openFolders(BuildContext context) => unawaited(
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const FoldersScreen())),
);

/// Where books come from by themselves (ADR 0007): the own folder with a
/// hint where it is, the picked folders, "Подключить папку".
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final folders = ref.watch(foldersProvider).value ?? const <FolderRow>[];
    final pick = ref.watch(pickFolderProvider);
    final own = folders.where((f) => f.kind == FolderKind.own).firstOrNull;
    final picked = [
      for (final f in folders)
        if (f.kind == FolderKind.picked) f,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.folders)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (own != null) _OwnFolder(folder: own),
          for (final folder in picked) ...[
            const SizedBox(height: 8),
            _PickedFolder(folder: folder, canPick: pick != null),
          ],
          if (pick != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 12),
              child: Text(
                [
                  l10n.foldersPickedHint,
                  if (Theme.of(context).platform == TargetPlatform.android)
                    l10n.foldersPickedHintAndroid,
                ].join('\n\n'),
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: () => unawaited(_connect(context, ref)),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(l10n.foldersConnect),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await _pick(context, ref);
    if (chosen == null || !context.mounted) return;
    final repo = ref.read(folderRepositoryProvider);
    if ((await repo.folders()).any((f) => f.ref == chosen.ref)) {
      if (context.mounted) showNotice(context, l10n.foldersAlready);
      return;
    }
    if (!context.mounted) return;
    var collect = false;
    if (chosen.name.trim().isNotEmpty) {
      final answer = await showDialog<bool>(
        context: context,
        builder: (_) => _ConnectDialog(name: chosen.name),
      );
      if (answer == null) {
        // Cancelled: the access isn't needed after all.
        await ref.read(releaseFolderProvider)(chosen.ref);
        return;
      }
      collect = answer;
    }
    final collection = collect
        ? await ref.read(collectionRepositoryProvider).named(chosen.name)
        : null;
    await repo.addPicked(
      ref: chosen.ref,
      name: chosen.name,
      collectionId: collection?.id,
    );
    unawaited(ref.read(scanFoldersProvider)());
  }
}

/// "Подключить папку «Книги»?" with the collection checkbox (ADR 0007,
/// p. 6); pops whether to collect, null when cancelled.
class _ConnectDialog extends StatefulWidget {
  const _ConnectDialog({required this.name});

  final String name;

  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  var _collect = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.foldersConnectTitle(widget.name)),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
      content: CheckboxListTile(
        value: _collect,
        onChanged: (v) => setState(() => _collect = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(l10n.foldersCollect(widget.name)),
        subtitle: Text(l10n.foldersCollectHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_collect),
          child: Text(l10n.foldersConnectButton),
        ),
      ],
    );
  }
}

/// The picker's answer; null when cancelled or failed (said in a notice).
Future<PickedFolder?> _pick(BuildContext context, WidgetRef ref) async {
  final pick = ref.read(pickFolderProvider);
  if (pick == null) return null;
  try {
    return await pick();
  } on PlatformException {
    if (context.mounted) {
      showNotice(context, AppLocalizations.of(context).foldersPickFailed);
    }
    return null;
  }
}

/// "Просмотрена 21 окт., 14:05".
String _scanned(AppLocalizations l10n, DateTime? at, String locale) {
  if (at == null) return l10n.foldersNotScanned;
  final day = at.year == DateTime.now().year
      ? DateFormat.MMMd(locale)
      : DateFormat.yMMMd(locale);
  return l10n.foldersScannedAt(
    '${day.format(at)}, ${DateFormat.Hm(locale).format(at)}',
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: context.readingColors.surface,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _OwnFolder extends StatelessWidget {
  const _OwnFolder({required this.folder});

  final FolderRow folder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final hint = switch (Theme.of(context).platform) {
      TargetPlatform.iOS => l10n.foldersOwnHintIos(l10n.appTitle),
      _ => l10n.foldersOwnHintAndroid,
    };
    return _Card(
      child: ListTile(
        minTileHeight: 60,
        leading: Icon(Icons.folder_special_outlined, color: colors.accent),
        title: Text(
          l10n.foldersOwn,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$hint\n${_scanned(l10n, folder.scannedAt, locale)}',
          style: TextStyle(color: colors.textSecondary),
        ),
      ),
    );
  }
}

class _PickedFolder extends ConsumerWidget {
  const _PickedFolder({required this.folder, required this.canPick});

  final FolderRow folder;
  final bool canPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final error = Theme.of(context).colorScheme.error;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final reconnect = folder.lost && canPick;
    final collection = ref
        .watch(collectionsProvider)
        .value
        ?.where((c) => c.id == folder.collectionId)
        .firstOrNull;
    return _Card(
      child: ListTile(
        minTileHeight: 60,
        leading: Icon(
          folder.lost ? Icons.folder_off_outlined : Icons.folder_outlined,
          color: folder.lost ? error : colors.textSecondary,
        ),
        title: Text(
          folder.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            if (folder.lost)
              l10n.foldersLost
            else
              _scanned(l10n, folder.scannedAt, locale),
            if (folder.tooBig) l10n.foldersTooBig(maxFolderBooks),
            if (collection != null) l10n.foldersInCollection(collection.name),
          ].join('\n'),
          style: TextStyle(color: folder.lost ? error : colors.textSecondary),
        ),
        onTap: reconnect ? () => unawaited(_reconnect(context, ref)) : null,
        trailing: PopupMenuButton<_Action>(
          tooltip: l10n.moreActions,
          onSelected: (action) => unawaited(switch (action) {
            _Action.reconnect => _reconnect(context, ref),
            _Action.disconnect => _disconnect(context, ref),
          }),
          itemBuilder: (_) => [
            if (reconnect)
              PopupMenuItem(
                value: _Action.reconnect,
                child: Text(l10n.foldersReconnect),
              ),
            PopupMenuItem(
              value: _Action.disconnect,
              child: Text(l10n.foldersDisconnect),
            ),
          ],
        ),
      ),
    );
  }

  /// The access is back with a new handle; the seen files are kept.
  Future<void> _reconnect(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await _pick(context, ref);
    if (chosen == null) return;
    final repo = ref.read(folderRepositoryProvider);
    if ((await repo.folders()).any(
      (f) => f.id != folder.id && f.ref == chosen.ref,
    )) {
      // Another folder row: sharing the handle, one disconnect would cut
      // the other off.
      if (context.mounted) showNotice(context, l10n.foldersAlready);
      return;
    }
    final old = folder.ref;
    await repo.setRef(folder.id, chosen.ref);
    if (old != null && old != chosen.ref) {
      await ref.read(releaseFolderProvider)(old);
    }
    unawaited(ref.read(scanFoldersProvider)());
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.foldersDisconnectTitle(folder.name)),
        content: Text(l10n.foldersDisconnectBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.foldersDisconnect),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(folderRepositoryProvider).remove(folder.id);
    final handle = folder.ref;
    if (handle != null) await ref.read(releaseFolderProvider)(handle);
  }
}

enum _Action { reconnect, disconnect }
