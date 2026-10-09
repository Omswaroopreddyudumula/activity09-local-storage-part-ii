import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'models.dart';
import 'main.dart' show DirectoryScreen;

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({super.key, required this.helper, this.folder});
  final DatabaseHelper helper;
  final Folder? folder;
  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  List<Folder> _folders = [];
  List<CardRecord> _cards = [];
  bool _busy = false;
  String? _error;
  String _feedback = '';
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _load() async {
    try {
      final folders = await widget.helper.getFoldersWithCounts();
      final cards = widget.folder == null
          ? <CardRecord>[]
          : await widget.helper.getCards(widget.folder!.id!);
      debugPrint('CATALOGUE ${await widget.helper.diagnostics()}');
      if (mounted) {
        setState(() {
          _folders = folders;
          _cards = cards;
          _error = null;
        });
      }
    } catch (e, stack) {
      debugPrint('Catalogue read: $e\n$stack');
      if (mounted) {
        setState(
          () => _error = 'Could not refresh. Retry Refresh; do not repeat a successful save.',
        );
      }
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove(String name, int id, bool folder) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $name (ID $id)?'),
        content: Text(
          folder
              ? 'All cards in this folder will also be deleted.'
              : 'This card will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || _busy) return;
    if (yes != true) {
      setState(() => _feedback = 'Deletion canceled; ID $id kept.');
      return;
    }
    setState(() => _busy = true);
    try {
      final n = folder
          ? await widget.helper.deleteFolder(id)
          : await widget.helper.deleteCard(id);
      if (mounted) {
        setState(
          () => _feedback = n == 1
              ? 'Deleted ID $id: $n row affected'
              : 'ID $id no longer exists; $n rows affected',
        );
      }
      await _load();
    } catch (e, stack) {
      debugPrint('Delete: $e\n$stack');
      if (mounted) {
        setState(
          () => _feedback = 'Delete failed. No deletion was confirmed; refresh and try again.',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _folderForm([Folder? folder]) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => FolderForm(helper: widget.helper, folder: folder),
    );
    if (!mounted) return;
    if (result != null) setState(() => _feedback = result);
    await _refresh();
  }

  Future<void> _cardForm([CardRecord? card]) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CardForm(
          helper: widget.helper,
          folders: _folders,
          folderId: widget.folder!.id!,
          card: card,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _feedback = result ?? 'Edit canceled; no write performed.');
    await _refresh();
  }

  Widget _image(CardRecord c) {
    final placeholder = SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Text(
          c.symbol,
          style: TextStyle(
            fontSize: 32,
            color: ['Hearts', 'Diamonds'].contains(c.suit)
                ? Colors.red
                : Colors.black,
          ),
        ),
      ),
    );
    final ref = c.imageRef;
    if (ref == null) return placeholder;
    if (ref.startsWith('assets/')) {
      return Image.asset(
        ref,
        width: 48,
        height: 48,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    final uri = Uri.tryParse(ref);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      return Image.network(
        ref,
        width: 48,
        height: 48,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
      );
    }
    return placeholder;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.folder == null
            ? 'Activity 09 · Folders'
            : '${widget.folder!.name} · ${_cards.length} cards',
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
        if (widget.folder == null)
          IconButton(
            tooltip: 'Part I guests',
            onPressed: _busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DirectoryScreen(helper: widget.helper),
                    ),
                  ),
            icon: const Icon(Icons.people),
          ),
      ],
    ),
    body: Column(
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_feedback.isNotEmpty)
          Padding(padding: const EdgeInsets.all(8), child: Text(_feedback)),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: widget.folder == null
              ? (_folders.isEmpty && !_busy
                    ? const Center(child: Text('No folders yet. Add a folder.'))
                    : ListView(
                        children: _folders
                            .map(
                              (f) => ListTile(
                                title: Text(f.name),
                                subtitle: Text(
                                  'Folder ID ${f.id} · ${f.cardCount} cards',
                                ),
                                onTap: _busy
                                    ? null
                                    : () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CatalogueScreen(
                                              helper: widget.helper,
                                              folder: f,
                                            ),
                                          ),
                                        );
                                        await _refresh();
                                      },
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Rename ${f.name}',
                                      onPressed: _busy
                                          ? null
                                          : () => _folderForm(f),
                                      icon: const Icon(Icons.edit),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete ${f.name}',
                                      onPressed: _busy
                                          ? null
                                          : () => _remove(f.name, f.id!, true),
                                      icon: const Icon(Icons.delete),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ))
              : (_cards.isEmpty && !_busy
                    ? const Center(child: Text('No cards in this folder.'))
                    : ListView(
                        children: _cards
                            .map(
                              (c) => ListTile(
                                leading: _image(c),
                                title: Text(c.title),
                                subtitle: Text(
                                  'Card ID ${c.id} · ${c.suit} · Folder ${c.folderId}\n${c.notes}',
                                ),
                                isThreeLine: true,
                                onTap: _busy ? null : () => _cardForm(c),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit card ${c.id}',
                                      onPressed: _busy
                                          ? null
                                          : () => _cardForm(c),
                                      icon: const Icon(Icons.edit),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete card ${c.id}',
                                      onPressed: _busy
                                          ? null
                                          : () =>
                                                _remove(c.title, c.id!, false),
                                      icon: const Icon(Icons.delete),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      )),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy
          ? null
          : () {
              if (widget.folder == null) {
                _folderForm();
              } else {
                _cardForm();
              }
            },
      icon: const Icon(Icons.add),
      label: Text(widget.folder == null ? 'Add folder' : 'Add card'),
    ),
  );
}

class FolderForm extends StatefulWidget {
  const FolderForm({super.key, required this.helper, this.folder});
  final DatabaseHelper helper;
  final Folder? folder;
  @override
  State<FolderForm> createState() => _FolderFormState();
}

class _FolderFormState extends State<FolderForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.folder?.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final f = widget.folder;
      final n = f == null
          ? await widget.helper.insertFolder(_name.text)
          : await widget.helper.updateFolder(
              Folder(id: f.id, name: _name.text, createdAt: f.createdAt),
            );
      if (mounted) {
        Navigator.pop(
          context,
          f == null
              ? 'Created folder ID $n'
              : 'Updated folder ID ${f.id}: $n rows affected',
        );
      }
    } catch (e, stack) {
      debugPrint('Folder save: $e\n$stack');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is DatabaseException && e.isUniqueConstraintError()
              ? 'A folder with this name already exists. Choose another name.'
              : 'Could not save folder. Input retained; try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.folder == null ? 'Add folder' : 'Rename folder'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Folder name'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter a nonempty folder name'
                  : null,
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class CardForm extends StatefulWidget {
  const CardForm({
    super.key,
    required this.helper,
    required this.folders,
    required this.folderId,
    this.card,
  });
  final DatabaseHelper helper;
  final List<Folder> folders;
  final int folderId;
  final CardRecord? card;
  @override
  State<CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<CardForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _notes, _image;
  late int _folderId;
  late String _suit;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final c = widget.card;
    _title = TextEditingController(text: c?.title);
    _notes = TextEditingController(text: c?.notes);
    _image = TextEditingController(text: c?.imageRef);
    _folderId = c?.folderId ?? widget.folderId;
    _suit = c?.suit ?? 'Hearts';
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = CardRecord(
        id: widget.card?.id,
        title: _title.text,
        suit: _suit,
        folderId: _folderId,
        notes: _notes.text,
        imageRef: _image.text.trim().isEmpty ? null : _image.text,
      );
      final n = c.id == null
          ? await widget.helper.insertCard(c)
          : await widget.helper.updateCard(c);
      if (mounted) {
        Navigator.pop(
          context,
          c.id == null
              ? 'Created card ID $n'
              : (n == 1
                    ? 'Updated card ID ${c.id}: 1 row affected'
                    : 'Card ID ${c.id} no longer exists; $n rows affected'),
        );
      }
    } catch (e, stack) {
      debugPrint('Card save: $e\n$stack');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save card. Input retained; check the folder and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.card == null ? 'Add card' : 'Edit card ID ${widget.card!.id}',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter a nonempty title'
                  : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _suit,
              decoration: const InputDecoration(labelText: 'Suit'),
              items: CardRecord.suits
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: _busy ? null : (v) => setState(() => _suit = v!),
              validator: (v) =>
                  CardRecord.suits.contains(v) ? null : 'Choose a suit',
            ),
            DropdownButtonFormField<int>(
              initialValue: _folderId,
              decoration: const InputDecoration(labelText: 'Folder'),
              items: widget.folders
                  .map(
                    (f) => DropdownMenuItem(
                      value: f.id,
                      child: Text('${f.name} (ID ${f.id})'),
                    ),
                  )
                  .toList(),
              onChanged: _busy ? null : (v) => setState(() => _folderId = v!),
              validator: (v) => widget.folders.any((f) => f.id == v)
                  ? null
                  : 'Choose an existing folder',
            ),
            TextFormField(
              controller: _notes,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            TextFormField(
              controller: _image,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Image reference (optional)',
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}
