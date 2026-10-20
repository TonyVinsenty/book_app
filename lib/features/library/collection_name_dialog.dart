import 'package:book_app/data/collection_repository.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Asks for a collection name until [save] takes it; a wrong name is
/// explained under the field. Null when cancelled.
Future<T?> askCollectionName<T>(
  BuildContext context, {
  required String title,
  required String action,
  required Future<T> Function(String name) save,
  String initial = '',
}) => showDialog<T>(
  context: context,
  builder: (_) => _CollectionNameDialog<T>(
    title: title,
    action: action,
    save: save,
    initial: initial,
  ),
);

class _CollectionNameDialog<T> extends StatefulWidget {
  const _CollectionNameDialog({
    required this.title,
    required this.action,
    required this.save,
    required this.initial,
  });

  final String title;
  final String action;
  final Future<T> Function(String name) save;
  final String initial;

  @override
  State<_CollectionNameDialog<T>> createState() =>
      _CollectionNameDialogState<T>();
}

class _CollectionNameDialogState<T> extends State<_CollectionNameDialog<T>> {
  late final _name = TextEditingController(text: widget.initial);
  CollectionNameError? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.save(_name.text);
      if (mounted) Navigator.of(context).pop(saved);
    } on CollectionNameException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.error;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: l10n.collectionName,
          errorText: switch (_error) {
            CollectionNameError.empty => l10n.collectionNameEmpty,
            CollectionNameError.taken => l10n.collectionNameTaken,
            null => null,
          },
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}
