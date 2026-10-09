import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'catalogue.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
  } catch (error, stack) {
    debugPrint('Database initialization failed: $error\n$stack');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not open local storage. Restart the app and check the logs.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget {
  const DirectoryApp({super.key, required this.helper});
  final DatabaseHelper helper;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Fall Festival Roster',
    home: CatalogueScreen(helper: helper),
  );
}

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, required this.helper});
  final DatabaseHelper helper;
  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  int _count = 0;
  int? _selectedId;
  bool _busy = false;
  String? _readError;
  String _feedback = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // Called only while the caller owns the busy guard.
  Future<bool> _load() async {
    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();
      if (!mounted) return false;
      setState(() {
        _rows = rows;
        _count = count;
        _readError = null;
      });
      debugPrint('ROSTER rows=$rows count=$count');
      return true;
    } catch (error, stack) {
      debugPrint('Read failed: $error\n$stack');
      if (mounted) {
        setState(
          () => _readError = 'Could not read guests. Tap Refresh to retry.',
        );
      }
      return false;
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearForm() {
    _selectedId = null;
    _name.clear();
    _age.clear();
    _form.currentState?.reset();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final id = _selectedId;
    final values = <String, dynamic>{
      DatabaseHelper.columnName: _name.text.trim(),
      DatabaseHelper.columnAge: int.parse(_age.text.trim()),
    };
    setState(() => _busy = true);
    try {
      String message;
      bool succeeded;
      try {
        if (id == null) {
          final inserted = await widget.helper.insert(values);
          message = 'Added guest ID $inserted.';
          succeeded = true;
        } else {
          final affected = await widget.helper.update({
            DatabaseHelper.columnId: id,
            ...values,
          });
          succeeded = affected == 1;
          message = succeeded
              ? 'Updated ID $id: $affected row affected.'
              : 'ID $id not found: $affected rows affected. Refreshing.';
        }
      } catch (error, stack) {
        debugPrint('Write failed: $error\n$stack');
        if (mounted) {
          setState(
            () => _feedback =
                'Save failed. Input kept; retry Save or check logs.',
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        if (succeeded) _clearForm();
        _feedback = message;
      });
      final loaded = await _load();
      if (!mounted) return;
      if (!loaded) {
        setState(
          () => _feedback = succeeded
              ? '$message Saved, but refresh failed. Tap Refresh.'
              : '$message Read failed. Tap Refresh.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _edit(Map<String, dynamic> row) {
    if (_busy) return;
    setState(() {
      _form.currentState?.reset();
      _selectedId = row[DatabaseHelper.columnId] as int;
      _name.text = row[DatabaseHelper.columnName] as String;
      _age.text = '${row[DatabaseHelper.columnAge]}';
      _feedback = 'Editing ID $_selectedId.';
    });
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (_busy) return;
    final id = row[DatabaseHelper.columnId] as int;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete guest?'),
          content: Text('Delete ID $id: ${row[DatabaseHelper.columnName]}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        setState(() => _feedback = 'Deletion canceled. ID $id kept.');
        return;
      }
      int affected;
      try {
        affected = await widget.helper.delete(id);
      } catch (error, stack) {
        debugPrint('Delete failed: $error\n$stack');
        if (mounted) {
          setState(() => _feedback = 'Delete failed. Retry or check logs.');
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        if (affected == 1 && _selectedId == id) _clearForm();
        _feedback = affected == 1
            ? 'Deleted ID $id: $affected row affected.'
            : 'ID $id not found: $affected rows affected. Refreshing.';
      });
      final loaded = await _load();
      if (!mounted) return;
      if (!loaded) {
        setState(
          () => _feedback += affected == 1
              ? ' Deleted, but refresh failed. Tap Refresh.'
              : ' Read failed. Tap Refresh.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fall Festival Roster')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _selectedId == null
                ? 'Register a guest'
                : 'Editing ID $_selectedId',
          ),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a nonempty name.'
                      : null,
                ),
                TextFormField(
                  controller: _age,
                  enabled: !_busy,
                  // Text keyboard permits testing nonnumeric and decimal rejection.
                  decoration: const InputDecoration(labelText: 'Age (0–130)'),
                  validator: (value) {
                    final age = int.tryParse((value ?? '').trim());
                    return age == null || age < 0 || age > 130
                        ? 'Enter an integer age from 0 to 130.'
                        : null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_selectedId == null ? 'Add' : 'Save'),
              ),
              if (_selectedId != null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _clearForm();
                          _feedback = 'Edit canceled. No changes saved.';
                        }),
                  child: const Text('Cancel edit'),
                ),
              OutlinedButton(
                onPressed: _busy ? null : _refresh,
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          if (_feedback.isNotEmpty) Text(_feedback),
          if (_readError != null) Text(_readError!),
          Text(
            _readError == null
                ? 'Record count: $_count'
                : 'Last known count: $_count',
          ),
          const Divider(),
          if (!_busy && _readError == null && _rows.isEmpty)
            const Text('No festival guests yet'),
          for (final row in _rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ID ${row[DatabaseHelper.columnId]} • ${row[DatabaseHelper.columnName]}\nAge ${row[DatabaseHelper.columnAge]}',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _edit(row),
                      child: const Text('Edit'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _delete(row),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
