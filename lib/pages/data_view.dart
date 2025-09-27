// lib/pages/data_view.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/units.dart'; // must provide UnitRecognition + recognizeUnit()

class DataViewPage extends StatefulWidget {
  final List<Map<String, String>> records; // compat (unused)
  const DataViewPage({super.key, required this.records});

  @override
  State<DataViewPage> createState() => _DataViewPageState();
}

class _DataViewPageState extends State<DataViewPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await supabase
        .from('info')
        .select('*')
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Records')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Load failed: ${snap.error}'));
          }
          final data = snap.data ?? const [];
          if (data.isEmpty) {
            return const Center(child: Text('No records yet.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final r = data[i];
                final hasNotes =
                    (r['notes'] as String?)?.trim().isNotEmpty == true;

                return _RecordTile(
                  row: r,
                  onOpen: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordDetailPage(row: r),
                      ),
                    );
                    if (changed == true)
                      _refresh(); // ← immediate refresh after delete/save
                  },
                  onNotesTap: hasNotes
                      ? () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Notes'),
                              content: _NotesBody(
                                notes: (r['notes'] ?? '') as String,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        }
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

Color _statusColor(String s) {
  switch ((s).toLowerCase()) {
    case 'urgent':
      return const Color(0xFFE53935);
    case 'approved':
      return const Color(0xFF2E7D32);
    case 'denied':
      return const Color(0xFF8E24AA);
    default:
      return const Color(0xFF1976D2);
  }
}

class _RecordTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onOpen;
  final VoidCallback? onNotesTap;

  const _RecordTile({required this.row, required this.onOpen, this.onNotesTap});

  @override
  Widget build(BuildContext context) {
    final part = (row['partname'] ?? '') as String;
    final status = (row['status'] ?? 'normal') as String;
    final team = (row['team_requesting'] ?? '') as String;
    final applicant = (row['applicant_name'] ?? '') as String;
    final createdRaw = (row['created_at'] ?? '') as String;
    DateTime? created;
    try {
      created = DateTime.tryParse(createdRaw);
    } catch (_) {}

    final subtle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.7),
    );

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              spreadRadius: -2,
              offset: const Offset(0, 8),
              color: Colors.black.withOpacity(.06),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.description_outlined,
                color: _statusColor(status),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          part.isEmpty ? '(untitled)' : part,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusPill(
                        text: status.toUpperCase(),
                        color: _statusColor(status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.badge_outlined, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                applicant.isEmpty ? '-' : applicant,
                                style: subtle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.group_outlined, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                team.isEmpty ? '-' : team,
                                style: subtle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (created != null) ...[
                        const SizedBox(width: 10),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${created.year}-${_2(created.month)}-${_2(created.day)}',
                              style: subtle,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (onNotesTap != null)
              IconButton(
                tooltip: 'Show notes',
                onPressed: onNotesTap,
                icon: const Icon(Icons.comment_outlined),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  String _2(int n) => n.toString().padLeft(2, '0');
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .3,
          color: color,
        ),
      ),
    );
  }
}

class _NotesBody extends StatelessWidget {
  final String notes;
  const _NotesBody({required this.notes});

  @override
  Widget build(BuildContext context) {
    final parts = notes
        .replaceAll('\r\n', '\n')
        .split(',,')
        .expand((e) => e.split('\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return const Text('(no notes)');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in parts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(line)),
              ],
            ),
          ),
      ],
    );
  }
}

class RecordDetailPage extends StatefulWidget {
  final Map<String, dynamic> row;
  const RecordDetailPage({super.key, required this.row});

  @override
  State<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> {
  final supabase = Supabase.instance.client;

  bool _isExec = false;
  bool _isCreator = false;
  String _currentUserName = 'User';
  bool _loadingGate = true;

  // bottom actions state
  bool _contactChecked = false; // placeholder
  bool _wantsNote = false;
  final _newNoteCtrl = TextEditingController();

  String _statusChoice = 'approved';
  final List<String> _statusOptions = const [
    'approved',
    'forwarded to',
    'denied',
    'needs further clarification on',
    'other',
  ];
  final _statusMsgCtrl = TextEditingController();

  // ---------- local, in-memory Physical rows for interactive display ----------
  final List<_PhysRow> _physRows = [];
  bool _physParsed = false;

  @override
  void initState() {
    super.initState();
    _gate();
    _parsePhysicalOnce();
  }

  void _parsePhysicalOnce() {
    if (_physParsed) return;
    _physParsed = true;

    final raw = (widget.row['physical'] as String?)?.trim() ?? '';
    if (raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final e in decoded.whereType<Map>()) {
          _physRows.add(
            _PhysRow(
              key: '${e['key'] ?? ''}',
              value: '${e['value'] ?? ''}',
              units: '${e['units'] ?? ''}',
            ),
          );
        }
      } else if (decoded is Map) {
        // legacy map -> present as key/value only
        decoded.cast<String, dynamic>().forEach((k, v) {
          _physRows.add(_PhysRow(key: k, value: '$v', units: ''));
        });
      }
    } catch (_) {
      // fall back to raw later
    }
  }

  Future<void> _gate() async {
    try {
      final auth = supabase.auth.currentUser;
      if (auth == null) {
        setState(() {
          _isExec = false;
          _isCreator = false;
          _loadingGate = false;
        });
        return;
      }
      final userRow = await supabase
          .from('users')
          .select('user, clearance, email')
          .eq('id', auth.id)
          .maybeSingle();

      final clearance = (userRow?['clearance'] as String?) ?? '';
      final name = ((userRow?['user'] as String?) ?? '').trim();
      final fallback = (auth.email?.split('@').first ?? 'User');
      final display = name.isEmpty ? fallback : name;

      final applicant = (widget.row['applicant_name'] as String?)?.trim() ?? '';
      setState(() {
        _isExec = clearance.toLowerCase() == 'executive';
        _currentUserName = display;
        _isCreator = applicant.isNotEmpty && applicant == display;
        _loadingGate = false;
      });
    } catch (_) {
      setState(() => _loadingGate = false);
    }
  }

  @override
  void dispose() {
    _newNoteCtrl.dispose();
    _statusMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveExecChanges() async {
    final id = widget.row['id'];
    if (id == null) return;

    String? newNotes;
    final prev = (widget.row['notes'] as String?)?.trim() ?? '';
    final addNote = _wantsNote && _newNoteCtrl.text.trim().isNotEmpty;

    if (addNote) {
      final entry = '${_currentUserName}:${_newNoteCtrl.text.trim()}';
      if (prev.isEmpty) {
        newNotes = entry;
      } else {
        newNotes = '$prev ,, $entry';
      }
    }

    final needsMsg = _statusChoice != 'approved';
    if (needsMsg && _statusMsgCtrl.text.trim().isNotEmpty) {
      final entry =
          '${_currentUserName}: ${_statusChoice} - ${_statusMsgCtrl.text.trim()}';
      if ((newNotes ?? prev).isEmpty) {
        newNotes = entry;
      } else {
        newNotes = '${(newNotes ?? prev)} ,, $entry';
      }
    }

    final update = <String, dynamic>{'status': _statusChoice};
    if ((newNotes ?? '').isNotEmpty) {
      update['notes'] = newNotes;
    }

    try {
      await supabase.from('info').update(update).eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Changes saved')));
      widget.row['status'] = _statusChoice;
      if (update.containsKey('notes')) {
        widget.row['notes'] = update['notes'];
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteRecord() async {
    final id = widget.row['id'];
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete record?'),
        content: const Text(
          'This will permanently delete the record. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await supabase.from('info').delete().eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Record deleted')));
      Navigator.pop(context, true); // ← list screen refreshes immediately
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ───────────── Convert picker: choose target unit, update UI row only ─────────────
  Future<void> _pickUnitAndApply({
    required int index,
    required UnitRecognition rec,
    required double value,
  }) async {
    final convs = rec.conversions(value);
    if (convs.isEmpty) return;

    final targetUnit = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Convert to'),
        children: [
          for (final c in convs)
            ListTile(
              dense: true,
              title: Text(c.unit),
              onTap: () => Navigator.pop(context, c.unit),
            ),
        ],
      ),
    );
    if (targetUnit == null) return;

    final chosen = convs.firstWhere(
      (c) => c.unit == targetUnit,
      orElse: () => convs.first,
    );

    setState(() {
      _physRows[index] = _physRows[index].copyWith(
        value: _fmtNum(chosen.value),
        units: chosen.unit,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final status = (r['status'] ?? 'normal') as String;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text((r['partname'] ?? '(record)') as String)),
            const SizedBox(width: 8),
            _StatusPill(
              text: status.toUpperCase(),
              color: _statusColor(status),
            ),
          ],
        ),
      ),
      body: _loadingGate
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                _twoCol(
                  'Team Requesting',
                  r['team_requesting'],
                  'Applicant Name',
                  r['applicant_name'],
                ),
                _field('Reason', r['reason'], multi: true),
                _field(
                  'Description of Requirement',
                  r['Description_of_requirement'],
                  multi: true,
                ),
                _acfChips(r['ACF'] as String?),
                _manufacturerSection(r),

                _physicalSectionInteractiveOrRaw(r['physical'] as String?),

                _notesSection(r['notes'] as String?),

                // ───────────── EXEC-ONLY CONTROLS ─────────────
                if (_isExec) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Reviewer Actions (executive only)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  CheckboxListTile(
                    value: _contactChecked,
                    onChanged: (v) => setState(() => _contactChecked = v!),
                    title: const Text('Contact'),
                    subtitle: const Text('Placeholder — not wired yet'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),

                  CheckboxListTile(
                    value: _wantsNote,
                    onChanged: (v) => setState(() => _wantsNote = v!),
                    title: const Text('Would you like to add a note?'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),

                  if (_wantsNote) ...[
                    const SizedBox(height: 8),
                    _card(
                      child: TextField(
                        controller: _newNoteCtrl,
                        minLines: 2,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'New note',
                          hintText:
                              'Type the message to append (will store as "name: message")',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Text(
                    'Set status',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _statusChoice,
                    items: _statusOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _statusChoice = v!),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_statusChoice != 'approved') ...[
                    const SizedBox(height: 8),
                    _card(
                      child: TextField(
                        controller: _statusMsgCtrl,
                        minLines: 2,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: _statusChoice == 'forwarded to'
                              ? 'Forwarded to (add details/message)'
                              : 'Add reviewer message',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveExecChanges,
                      icon: const Icon(Icons.save),
                      label: const Text('Save changes'),
                    ),
                  ),
                ],

                if (_isCreator) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _deleteRecord,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  // ---------- Pretty sections ----------

  Widget _twoCol(String l1, dynamic v1, String l2, dynamic v2) {
    return Row(
      children: [
        Expanded(child: _field(l1, v1)),
        const SizedBox(width: 12),
        Expanded(child: _field(l2, v2)),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(.12),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(.05),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }

  Widget _label(String s) => Text(
    s,
    style: TextStyle(
      fontSize: 12,
      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.7),
    ),
  );

  Widget _field(String label, dynamic value, {bool multi = false}) {
    final v = (value as String?)?.trim();
    if (v == null || v.isEmpty || v.toLowerCase() == 'null') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(label),
            const SizedBox(height: 6),
            Text(
              v,
              style: const TextStyle(fontSize: 14),
              maxLines: multi ? null : 3,
              overflow: multi ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _acfChips(String? acf) {
    final s = (acf ?? '').trim();
    if (s.isEmpty) return const SizedBox.shrink();
    final parts = s.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('ACF'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: parts
                  .map(
                    (p) => Chip(
                      label: Text(p),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _manufacturerSection(Map<String, dynamic> r) {
    final m = (r['Manufacturer'] as String?)?.trim();
    final mid = (r['manufacturer_id'] as String?)?.trim();
    if ((m == null || m.isEmpty) && (mid == null || mid.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Manufacturer'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (m != null && m.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.factory_outlined, size: 16),
                    label: Text(m),
                    visualDensity: VisualDensity.compact,
                  ),
                if (mid != null && mid.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.tag_outlined, size: 16),
                    label: Text(mid),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Physical (smart, interactive). Falls back to raw if JSON invalid.
  Widget _physicalSectionInteractiveOrRaw(String? physicalJson) {
    final raw = (physicalJson ?? '').trim();
    if (raw.isEmpty) return const SizedBox.shrink();

    // If parsing failed earlier, show raw:
    if (_physRows.isEmpty) {
      try {
        jsonDecode(raw); // validate
      } catch (_) {
        return _field('Physical (raw)', raw, multi: true);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Physical'),
            const SizedBox(height: 8),
            if (_physRows.isEmpty)
              const Text('(none)')
            else
              Column(
                children: [
                  // header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Key',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Value',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Units',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        SizedBox(width: 32),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (int i = 0; i < _physRows.length; i++)
                    _buildPhysRow(i, _physRows[i]),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhysRow(int index, _PhysRow row) {
    final borderColor = Theme.of(context).colorScheme.outline.withOpacity(.15);

    final numVal = _tryParseNum(row.value);
    final rec = recognizeUnit(row.units);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(row.key.isEmpty ? '—' : row.key)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: Text(row.value.isEmpty ? '—' : row.value)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(child: Text(row.units.isEmpty ? '—' : row.units)),
                const SizedBox(width: 6),
                if (rec.recognized)
                  const Tooltip(
                    message: 'Unit recognized',
                    child: Icon(Icons.verified, size: 18, color: Colors.green),
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    tooltip: 'Unit not auto recognized',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unit not auto recognized'),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (rec.recognized && numVal != null)
            IconButton(
              tooltip: 'Convert',
              onPressed: () =>
                  _pickUnitAndApply(index: index, rec: rec, value: numVal),
              icon: const Icon(Icons.swap_horiz),
            ),
        ],
      ),
    );
  }

  // ---------- small helpers ----------

  String _fmtNum(double v) {
    final abs = v.abs();
    if (abs == 0) return '0';
    if (abs >= 1000 || abs < 0.01) {
      return v.toStringAsExponential(3);
    }
    return (v.toStringAsFixed(4)).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  double? _tryParseNum(String s) {
    final t = s.replaceAll(',', '').trim();
    return double.tryParse(t);
  }

  Widget _notesSection(String? notes) {
    final n = (notes ?? '').trim();
    if (n.isEmpty) return const SizedBox.shrink();
    final parts = n
        .replaceAll('\r\n', '\n')
        .split(',,')
        .expand((e) => e.split('\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Notes'),
            const SizedBox(height: 8),
            for (final line in parts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(line)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ----- simple holder for physical rows in UI
class _PhysRow {
  final String key;
  final String value;
  final String units;
  _PhysRow({required this.key, required this.value, required this.units});

  _PhysRow copyWith({String? key, String? value, String? units}) => _PhysRow(
    key: key ?? this.key,
    value: value ?? this.value,
    units: units ?? this.units,
  );
}
