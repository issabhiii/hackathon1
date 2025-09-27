// lib/pages/upload_page.dart
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart'; // for Login / Sign Up CTA

/// ---------------------------
/// UploadPage (auth/clearance-gated)
/// ---------------------------
class UploadPage extends StatefulWidget {
  final void Function(Map<String, String>) onSave; // kept for compatibility
  const UploadPage({super.key, required this.onSave});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  // basic fields
  String? partName;
  String? applicantName;
  PlatformFile? selectedFile;

  final _applicantNameCtrl = TextEditingController();

  // auth/clearance
  User? _authUser;
  String? _clearance; // "executive", "employee", "uncleared", etc.

  bool get _loginRequired => _authUser == null;
  bool get _awaitingApproval =>
      _authUser != null && (_clearance ?? '').toLowerCase() == 'uncleared';
  bool get _blocked => _loginRequired || _awaitingApproval;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _listenAuthChanges();
  }

  @override
  void dispose() {
    _applicantNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _authUser = Supabase.instance.client.auth.currentUser;
    if (_authUser == null) {
      setState(() {
        _clearance = null;
        _applicantNameCtrl.text = '';
        applicantName = null;
      });
      return;
    }
    await _hydrateFromUsersRow(_authUser!.id, _authUser!.email);
  }

  void _listenAuthChanges() {
    Supabase.instance.client.auth.onAuthStateChange.listen((state) async {
      final session = state.session;
      if (!mounted) return;
      if (session?.user != null) {
        _authUser = session!.user;
        await _hydrateFromUsersRow(_authUser!.id, _authUser!.email);
      } else {
        setState(() {
          _authUser = null;
          _clearance = null;
          _applicantNameCtrl.text = '';
          applicantName = null;
        });
      }
    });
  }

  Future<void> _hydrateFromUsersRow(String id, String? email) async {
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('user, clearance')
          .eq('id', id)
          .maybeSingle();

      final fallback = _emailPrefix(email ?? '');
      final name = ((row?['user'] as String?)?.trim().isNotEmpty ?? false)
          ? (row!['user'] as String).trim()
          : fallback;

      setState(() {
        _clearance = (row?['clearance'] as String?)?.trim();
        _applicantNameCtrl.text = name;
        applicantName = name;
      });
    } catch (_) {
      final fallback = _emailPrefix(email ?? '');
      setState(() {
        _clearance = null;
        _applicantNameCtrl.text = fallback;
        applicantName = fallback;
      });
    }
  }

  String _emailPrefix(String email) {
    final ix = email.indexOf('@');
    return ix > 0 ? email.substring(0, ix) : email;
  }

  Future<void> pickFile() async {
    if (_blocked) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null) {
      setState(() => selectedFile = result.files.single);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _goToForm() async {
    if (_blocked) {
      _snack(
        _loginRequired
            ? 'Please log in to continue.'
            : 'Awaiting approval. You cannot submit requests yet.',
        error: true,
      );
      return;
    }

    if ((partName ?? '').trim().isEmpty ||
        (applicantName ?? '').trim().isEmpty) {
      _snack('Please enter both Part Name and Applicant Name.', error: true);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApplicantFormPage(
          initialPartName: partName!.trim(),
          initialApplicantName: applicantName!.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always fill the viewport so the overlay is truly full-screen.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            children: [
              _buildContent(),
              if (_blocked)
                _BlockOverlay(
                  loginRequired: _loginRequired,
                  onLoginTap: () async {
                    if (!_loginRequired) return;
                    final name = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                    if (name != null && name.trim().isNotEmpty) {
                      _authUser = Supabase.instance.client.auth.currentUser;
                      if (_authUser != null) {
                        await _hydrateFromUsersRow(
                          _authUser!.id,
                          _authUser!.email,
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  "Start a New Request",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),

                TextField(
                  enabled: !_blocked,
                  decoration: const InputDecoration(
                    labelText: "Part Name *",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => partName = v,
                ),
                const SizedBox(height: 12),

                TextField(
                  enabled: !_blocked,
                  controller: _applicantNameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Applicant Name *",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => applicantName = v,
                ),
                const SizedBox(height: 12),

                GestureDetector(
                  onTap: pickFile,
                  child: AbsorbPointer(
                    absorbing: _blocked,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[50],
                      ),
                      child: Center(
                        child: Text(
                          selectedFile?.name ??
                              (_blocked
                                  ? (_loginRequired
                                        ? "Please log in to attach files"
                                        : "Locked (awaiting approval)")
                                  : "Tap to select file (optional)"),
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: _blocked ? null : _goToForm,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text("Continue to Form"),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------
/// Full-screen blocking overlay
/// ---------------------------
class _BlockOverlay extends StatelessWidget {
  final bool loginRequired;
  final VoidCallback? onLoginTap;

  const _BlockOverlay({required this.loginRequired, this.onLoginTap});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withOpacity(0.38)),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 18,
                        color: Colors.black.withOpacity(0.25),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        loginRequired ? Icons.lock_outline : Icons.block,
                        color: loginRequired ? Colors.indigo : Colors.redAccent,
                        size: 72,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        loginRequired
                            ? 'Sign in required'
                            : 'Awaiting approval',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loginRequired
                            ? 'Please sign in to start a new request. You can still browse existing records.'
                            : 'Your account is currently uncleared. You can browse records, but cannot submit new requests until an executive approves your access.',
                        textAlign: TextAlign.center,
                      ),
                      if (loginRequired) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: onLoginTap,
                          icon: const Icon(Icons.login),
                          label: const Text('Login / Sign Up'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------
/// ApplicantFormPage
/// ---------------------------
class ApplicantFormPage extends StatefulWidget {
  final String? initialPartName;
  final String? initialApplicantName;

  const ApplicantFormPage({
    super.key,
    this.initialPartName,
    this.initialApplicantName,
  });

  @override
  State<ApplicantFormPage> createState() => _ApplicantFormPageState();
}

class _ApplicantFormPageState extends State<ApplicantFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Core fields
  final _partNameCtrl = TextEditingController();
  final _applicantNameCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Manufacturer (now free-text like A/C/F)
  bool _includePrevManufacturer = false;
  final _manufacturerCtrl = TextEditingController();
  final _manufacturerIdCtrl = TextEditingController();

  // ACF now free-text (nullable)
  final _applicationCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _functionCtrl = TextEditingController();

  // Team requesting (keep dropdown)
  String? _selectedTeam;

  // Status
  String _status = 'normal'; // 'normal' | 'urgent'

  // Physical rows: key, value, units
  final List<_KVU> _physical = [
    _KVU(
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ),
  ];

  bool _submitting = false;

  // Team options
  final List<String> _teams = const [
    'R&D',
    'Manufacturing',
    'Quality',
    'Supply Chain',
    'Field Service',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if ((widget.initialPartName ?? '').isNotEmpty) {
      _partNameCtrl.text = widget.initialPartName!;
    }
    if ((widget.initialApplicantName ?? '').isNotEmpty) {
      _applicantNameCtrl.text = widget.initialApplicantName!;
    } else {
      _hydrateApplicantFromSupabase(); // fallback
    }
  }

  Future<void> _hydrateApplicantFromSupabase() async {
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      final email = authUser?.email;
      if (email == null) return;

      final row = await Supabase.instance.client
          .from('users')
          .select('user')
          .eq('email', email)
          .maybeSingle();

      final fallback = _emailPrefix(email);
      final name = ((row?['user'] as String?)?.trim().isNotEmpty ?? false)
          ? (row!['user'] as String).trim()
          : fallback;

      if (!mounted) return;
      if (_applicantNameCtrl.text.trim().isEmpty) {
        setState(() => _applicantNameCtrl.text = name);
      }
    } catch (_) {
      /* ignore */
    }
  }

  String _emailPrefix(String email) {
    final ix = email.indexOf('@');
    return ix > 0 ? email.substring(0, ix) : email;
  }

  @override
  void dispose() {
    _partNameCtrl.dispose();
    _applicantNameCtrl.dispose();
    _reasonCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();

    _manufacturerCtrl.dispose();
    _manufacturerIdCtrl.dispose();

    _applicationCtrl.dispose();
    _categoryCtrl.dispose();
    _functionCtrl.dispose();

    for (final triple in _physical) {
      triple.key.dispose();
      triple.value.dispose();
      triple.units.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // ACF: nullable free text
    final app = _applicationCtrl.text.trim();
    final cat = _categoryCtrl.text.trim();
    final fun = _functionCtrl.text.trim();
    final acfString = [app, cat, fun].where((e) => e.isNotEmpty).join(' | ');
    final acfOrNull = acfString.isEmpty ? null : acfString;

    // Manufacturer: nullable free text (behind toggle)
    final manufacturerText = _manufacturerCtrl.text.trim();
    final manufacturerIdText = _manufacturerIdCtrl.text.trim();
    final manufacturerOrNull =
        _includePrevManufacturer && manufacturerText.isNotEmpty
        ? manufacturerText
        : null;
    final manufacturerIdOrNull =
        _includePrevManufacturer && manufacturerIdText.isNotEmpty
        ? manufacturerIdText
        : null;

    // Physical as array of {key,value,units}
    final List<Map<String, String>> physicalList = [];
    for (final row in _physical) {
      final k = row.key.text.trim();
      final v = row.value.text.trim();
      final u = row.units.text.trim();
      if (k.isNotEmpty || v.isNotEmpty || u.isNotEmpty) {
        physicalList.add({'key': k, 'value': v, 'units': u});
      }
    }

    // Notes: ",," -> newline for display later
    final cleanedNotes = _notesCtrl.text.replaceAll(',,', '\n');
    final notesStored =
        '${_applicantNameCtrl.text.trim()}:${cleanedNotes.trim()}';

    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.from('info').insert({
        'partname': _partNameCtrl.text.trim(),
        'Manufacturer': manufacturerOrNull,
        'manufacturer_id': manufacturerIdOrNull,
        'ACF': acfOrNull,
        'team_requesting': _selectedTeam,
        'reason': _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text,
        'Description_of_requirement': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text,
        'physical': physicalList.isEmpty ? null : jsonEncode(physicalList),
        'status': _status,
        'notes': _notesCtrl.text.trim().isEmpty ? null : notesStored,
        'applicant_name': _applicantNameCtrl.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request submitted')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submit failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _addPhysicalRow() {
    setState(() {
      _physical.add(
        _KVU(
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ),
      );
    });
  }

  void _removePhysicalRow(int index) {
    if (_physical.length == 1) return;
    setState(() {
      final removed = _physical.removeAt(index);
      removed.key.dispose();
      removed.value.dispose();
      removed.units.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF005EB8);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Specification Request'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Applicant'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _applicantNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Applicant name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTeam,
                    decoration: const InputDecoration(
                      labelText: 'Team requesting',
                      border: OutlineInputBorder(),
                    ),
                    items: _teams
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedTeam = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _sectionTitle('Part'),
            TextFormField(
              controller: _partNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Part name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            _sectionTitle('Manufacturer'),
            SwitchListTile.adaptive(
              value: _includePrevManufacturer,
              onChanged: (v) => setState(() => _includePrevManufacturer = v),
              title: const Text('Include previous manufacturer info'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_includePrevManufacturer) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manufacturerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _manufacturerIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer ID (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            _sectionTitle('ACF (Application • Category • Function)'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _applicationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Application (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _categoryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Category (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _functionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Function (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _sectionTitle('Reason & Requirements'),
            TextFormField(
              controller: _reasonCtrl,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Reason for requesting',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Description of requirement',
                hintText:
                    'Use this space to describe exactly what went wrong or what specifications we need precisely and absolutely.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            _sectionTitle('Physical (key–value–units)'),
            ...List.generate(_physical.length, (i) {
              final row = _physical[i];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == _physical.length - 1 ? 0 : 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: row.key,
                        decoration: const InputDecoration(
                          labelText: 'Key (e.g., dimensions)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: row.value,
                        decoration: const InputDecoration(
                          labelText: 'Value (e.g., 11x12x13)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: row.units,
                        decoration: const InputDecoration(
                          labelText: 'Units (opt.)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _removePhysicalRow(i),
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addPhysicalRow,
                icon: const Icon(Icons.add),
                label: const Text('Add another'),
              ),
            ),
            const SizedBox(height: 16),

            _sectionTitle('Status'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'normal', label: Text('Normal')),
                ButtonSegment(value: 'urgent', label: Text('Urgent')),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
            const SizedBox(height: 16),

            _sectionTitle('Notes (use ",," for new lines)'),
            TextField(
              controller: _notesCtrl,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'Submitting…' : 'Submit request'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );
}

/// Small holder for Physical rows
class _KVU {
  final TextEditingController key;
  final TextEditingController value;
  final TextEditingController units;
  _KVU(this.key, this.value, this.units);
}
