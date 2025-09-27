// lib/pages/upload_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ---------------------------
/// UploadPage
/// ---------------------------
class UploadPage extends StatefulWidget {
  final void Function(Map<String, String>) onSave; // kept for compatibility
  const UploadPage({super.key, required this.onSave});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  String? partName;
  String? applicantName; // replaces "notes" on starter page
  PlatformFile? selectedFile;

  final _applicantNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hydrateApplicantFromSupabase(); // ⬅️ auto-fill on load
  }

  @override
  void dispose() {
    _applicantNameCtrl.dispose();
    super.dispose();
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
      _applicantNameCtrl.text = name;
      applicantName = name;
      setState(() {}); // reflect into UI if needed
    } catch (_) {
      // ignore; leave blank
    }
  }

  String _emailPrefix(String email) {
    final ix = email.indexOf('@');
    return ix > 0 ? email.substring(0, ix) : email;
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null) {
      setState(() => selectedFile = result.files.single);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _goToForm() async {
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
          initialApplicantName: applicantName!.trim(), // ⬅️ passed forward
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

                // Part name
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Part Name *",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => partName = v,
                ),
                const SizedBox(height: 12),

                // Applicant name (auto-filled)
                TextField(
                  controller: _applicantNameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Applicant Name *",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => applicantName = v,
                ),
                const SizedBox(height: 12),

                // Optional file picker
                GestureDetector(
                  onTap: pickFile,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey[50],
                    ),
                    child: Center(
                      child: Text(
                        selectedFile?.name ?? "Tap to select file (optional)",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Continue
                FilledButton.icon(
                  onPressed: _goToForm,
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

  // Manufacturer
  bool _includePrevManufacturer = false;
  String? _selectedManufacturer;
  String? _selectedManufacturerId;

  // ACF (Application / Category / Function) -> stored together into "ACF"
  String? _selectedApplication;
  String? _selectedCategory;
  String? _selectedFunction;

  // Team requesting
  String? _selectedTeam;

  // Status
  String _status = 'normal'; // 'normal' | 'urgent'

  // Physical key-value pairs
  final List<MapEntry<TextEditingController, TextEditingController>> _physical =
      [MapEntry(TextEditingController(), TextEditingController())];

  bool _submitting = false;

  // Sample dropdown data
  final List<String> _teams = const [
    'R&D',
    'Manufacturing',
    'Quality',
    'Supply Chain',
    'Field Service',
    'Other',
  ];

  final Map<String, List<String>> _manufacturers = const {
    'Acme Corp': ['ACM-101', 'ACM-202', 'ACM-303'],
    'Globex': ['GLO-11', 'GLO-22'],
    'Initech': ['INI-A', 'INI-B'],
  };

  final List<String> _applications = const [
    'Radiation Therapy',
    'Imaging',
    'Robotics',
    'Electromechanical',
    'General',
  ];
  final List<String> _categories = const [
    'Hardware',
    'Software',
    'Firmware',
    'Packaging',
    'Documentation',
  ];
  final List<String> _functions = const [
    'Cooling',
    'Motion',
    'Sensing',
    'Processing',
    'UI/UX',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill from UploadPage
    if ((widget.initialPartName ?? '').isNotEmpty) {
      _partNameCtrl.text = widget.initialPartName!;
    }
    if ((widget.initialApplicantName ?? '').isNotEmpty) {
      _applicantNameCtrl.text = widget.initialApplicantName!;
    } else {
      _hydrateApplicantFromSupabase(); // ⬅️ fallback auto-fill if nothing passed
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
      // ignore; leave as-is
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
    for (final kv in _physical) {
      kv.key.dispose();
      kv.value.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final acf = [
      _selectedApplication,
      _selectedCategory,
      _selectedFunction,
    ].where((e) => (e ?? '').isNotEmpty).join(' | ');

    final Map<String, String> physicalMap = {};
    for (final kv in _physical) {
      final k = kv.key.text.trim();
      final v = kv.value.text.trim();
      if (k.isNotEmpty && v.isNotEmpty) {
        physicalMap[k] = v;
      }
    }

    final notesStored =
        '${_applicantNameCtrl.text.trim()}:${_notesCtrl.text.trim()}';

    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.from('info').insert({
        'partname': _partNameCtrl.text.trim(),
        'Manufacturer': _includePrevManufacturer ? _selectedManufacturer : null,
        'manufacturer_id': _includePrevManufacturer
            ? _selectedManufacturerId
            : null,
        'ACF': acf.isEmpty ? null : acf,
        'team_requesting': _selectedTeam,
        'reason': _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text,
        'Description_of_requirement': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text,
        'physical': physicalMap.isEmpty ? null : jsonEncode(physicalMap),
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
      _physical.add(MapEntry(TextEditingController(), TextEditingController()));
    });
  }

  void _removePhysicalRow(int index) {
    if (_physical.length == 1) return;
    setState(() {
      _physical.removeAt(index);
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
              onChanged: (v) {
                setState(() {
                  _includePrevManufacturer = v;
                  if (!v) {
                    _selectedManufacturer = null;
                    _selectedManufacturerId = null;
                  }
                });
              },
              title: const Text('Include previous manufacturer info'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_includePrevManufacturer) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedManufacturer,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer *',
                        border: OutlineInputBorder(),
                      ),
                      items: _manufacturers.keys
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedManufacturer = v;
                          _selectedManufacturerId = null;
                        });
                      },
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedManufacturerId,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer ID *',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          (_selectedManufacturer == null
                                  ? const <String>[]
                                  : _manufacturers[_selectedManufacturer]!)
                              .map(
                                (id) => DropdownMenuItem(
                                  value: id,
                                  child: Text(id),
                                ),
                              )
                              .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedManufacturerId = v),
                      validator: (v) => (_selectedManufacturer == null)
                          ? null
                          : (v == null || v.isEmpty)
                          ? 'Required'
                          : null,
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
                  child: DropdownButtonFormField<String>(
                    value: _selectedApplication,
                    decoration: const InputDecoration(
                      labelText: 'Application',
                      border: OutlineInputBorder(),
                    ),
                    items: _applications
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedApplication = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedFunction,
                    decoration: const InputDecoration(
                      labelText: 'Function',
                      border: OutlineInputBorder(),
                    ),
                    items: _functions
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedFunction = v),
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

            _sectionTitle('Physical (key–value pairs)'),
            ...List.generate(_physical.length, (i) {
              final keyCtrl = _physical[i].key;
              final valCtrl = _physical[i].value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == _physical.length - 1 ? 0 : 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: keyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Key (e.g., dimensions)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: valCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Value (e.g., 11x12x13)',
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

            _sectionTitle('Notes (stored as "applicant: message")'),
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
