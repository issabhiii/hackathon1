// lib/pages/data_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataViewPage extends StatefulWidget {
  final List<Map<String, String>>
  records; // kept for compatibility (unused now)
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
    // rows is List<dynamic>
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    const chipUrgent = Color(0xFFE53935);
    const chipNormal = Color(0xFF43A047);

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
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r = data[i];
                final hasNotes =
                    (r['notes'] as String?)?.trim().isNotEmpty == true;

                return _RecordTile(
                  partName: (r['partname'] ?? '') as String,
                  status: (r['status'] ?? '') as String,
                  team: (r['team_requesting'] ?? '') as String,
                  applicant: (r['applicant_name'] ?? '') as String,
                  hasNotes: hasNotes,
                  statusColor: ((r['status'] ?? '') == 'urgent')
                      ? chipUrgent
                      : chipNormal,
                  onOpen: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordDetailPage(row: r),
                      ),
                    );
                    if (changed == true) _refresh();
                  },
                  onNotesTap: hasNotes
                      ? () {
                          final text = (r['notes'] ?? '') as String;
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Notes'),
                              content: SingleChildScrollView(child: Text(text)),
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

class _RecordTile extends StatelessWidget {
  final String partName;
  final String status;
  final String team;
  final String applicant;
  final bool hasNotes;
  final Color statusColor;
  final VoidCallback onOpen;
  final VoidCallback? onNotesTap;

  const _RecordTile({
    required this.partName,
    required this.status,
    required this.team,
    required this.applicant,
    required this.hasNotes,
    required this.statusColor,
    required this.onOpen,
    this.onNotesTap,
  });

  @override
  Widget build(BuildContext context) {
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
            color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              spreadRadius: -2,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(.06),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // first row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          partName.isEmpty ? '(untitled)' : partName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusColor.withOpacity(.5),
                          ),
                        ),
                        child: Text(
                          (status.isEmpty ? 'normal' : status).toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .3,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // second row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          team.isEmpty ? '-' : team,
                          style: subtle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(applicant.isEmpty ? '-' : applicant, style: subtle),
                    ],
                  ),
                ],
              ),
            ),
            if (hasNotes) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Show notes',
                onPressed: onNotesTap,
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ],
        ),
      ),
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

  @override
  void initState() {
    super.initState();
    _gate();
  }

  Future<void> _gate() async {
    try {
      final auth = supabase.auth.currentUser;
      if (auth == null) {
        setState(() {
          _isExec = false;
          _loadingGate = false;
        });
        return;
      }
      final userRow = await supabase
          .from('users')
          .select('user, clearance')
          .eq('id', auth.id)
          .maybeSingle();

      final clearance = (userRow?['clearance'] as String?) ?? '';
      final name = (userRow?['user'] as String?) ?? '';
      setState(() {
        _isExec = clearance.toLowerCase() == 'executive';
        _currentUserName = name.trim().isEmpty
            ? (auth.email?.split('@').first ?? 'User')
            : name;
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

    // Build new notes string if any
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

    // If status needs extra message, append to notes too
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
      // update local row so UI reflects
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

  @override
  Widget build(BuildContext context) {
    final r = widget.row;

    return Scaffold(
      appBar: AppBar(title: Text((r['partname'] ?? '(record)') as String)),
      body: _loadingGate
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                _field('Part Name', r['partname']),
                _field('Manufacturer', r['Manufacturer']),
                _field('Manufacturer ID', r['manufacturer_id']),
                _acfChips(r['ACF'] as String?),
                _field('Team Requesting', r['team_requesting']),
                _field('Applicant Name', r['applicant_name']),
                _field('Reason', r['reason'], multi: true),
                _field(
                  'Description of Requirement',
                  r['Description_of_requirement'],
                  multi: true,
                ),
                _physicalBox(r['physical'] as String?),
                _field('Status', r['status']),
                _field('Notes', r['notes'], multi: true),

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
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _statusChoice,
                          items: _statusOptions
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _statusChoice = v!),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
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
              ],
            ),
    );
  }

  // ---------- Detail helpers ----------

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(.15),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }

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
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(.7),
              ),
            ),
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
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: parts
              .map(
                (p) =>
                    Chip(label: Text(p), visualDensity: VisualDensity.compact),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _physicalBox(String? physicalJson) {
    final raw = (physicalJson ?? '').trim();
    if (raw.isEmpty) return const SizedBox.shrink();

    Map<String, dynamic>? map;
    try {
      map = jsonDecode(raw) as Map<String, dynamic>?;
    } catch (_) {
      // show raw on decode error
      return _field('Physical (raw)', raw, multi: true);
    }
    if (map == null || map.isEmpty) return const SizedBox.shrink();

    final entries = map.entries.toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Physical',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(.7),
              ),
            ),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
              },
              children: [
                for (final e in entries)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 6,
                        ),
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 6,
                        ),
                        child: Text('${e.value}'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
