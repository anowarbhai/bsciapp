import 'dart:convert';

import 'package:bsciapp/api/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api = ApiService();
  final _keys = List.generate(4, (_) => GlobalKey<FormState>());
  final _page = PageController();
  final Map<String, TextEditingController> _c = {
    for (final key in [
      'name',
      'name_bangla',
      'father_name',
      'mother_name',
      'date_of_birth',
      'email',
      'phone',
      'address',
      'nationality',
      'nid',
      'institution',
      'designation',
      'medical_societies',
      'password',
      'password_confirmation',
      'payment_reference',
    ])
      key: TextEditingController(),
  };
  List<dynamic> _tiers = [];
  final List<_Entry> _academic = [
    _Entry(['degree', 'year', 'institution', 'country']),
  ];
  final List<_Entry> _training = [
    _Entry(['institution', 'country', 'from', 'to', 'duration']),
  ];
  final List<_Entry> _experience = [
    _Entry([
      'procedure',
      'independent_count',
      'training_place',
      'from',
      'to',
      'duration',
    ]),
  ];
  final List<_Entry> _publications = [
    _Entry(['journal', 'year', 'title', 'co_author']),
  ];
  final List<_Entry> _referees = [
    _Entry(['name', 'membership_number', 'institution']),
    _Entry(['name', 'membership_number', 'institution']),
  ];
  static const _degrees = [
    'MBBS',
    'MD (CARD)',
    'FCPS (CARD)',
    'D.CARD',
    'PhD (CARD)',
    'FCPS/MRCP (MEDICINE)',
    'MD/DCH (PAED)',
  ];
  static const _procedures = [
    'PCI',
    'Valvuloplasty',
    'Device Closure',
    'Vascular Intervention',
    'PPM',
    'CRT',
    'EP Ablation',
  ];
  int? _tierId;
  int _step = 0;
  bool _busy = false;
  String? _photoPath,
      _photoName,
      _identityPath,
      _identityName,
      _trainingPath,
      _trainingName;
  List<String> _academicPaths = [], _academicNames = [];
  bool _declared = false;
  String? _paymentProvider;
  Map<String, String> _serverErrors = {};
  String? _refereeError;

  @override
  void initState() {
    super.initState();
    _c['nationality']!.text = 'Bangladeshi';
    _loadTiers();
  }

  @override
  void dispose() {
    _page.dispose();
    for (final controller in _c.values) {
      controller.dispose();
    }
    for (final entries in [
      _academic,
      _training,
      _experience,
      _publications,
      _referees,
    ]) {
      for (final entry in entries) {
        entry.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadTiers() async {
    final tiers = await _api.getMembershipTiers();
    if (!mounted) return;
    setState(() {
      _tiers = tiers;
      _tierId = tiers.isEmpty ? null : tiers.first['id'] as int;
    });
  }

  Future<void> _pick(String type) async {
    final imageOnly = type == 'photo';
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: type == 'academic',
      allowedExtensions: imageOnly
          ? ['jpg', 'jpeg', 'png', 'webp']
          : ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || !mounted) return;
    setState(() {
      if (type == 'photo') {
        _photoPath = result.files.first.path;
        _photoName = result.files.first.name;
      }
      if (type == 'identity') {
        _identityPath = result.files.first.path;
        _identityName = result.files.first.name;
      }
      if (type == 'training') {
        _trainingPath = result.files.first.path;
        _trainingName = result.files.first.name;
      }
      if (type == 'academic') {
        _academicPaths = result.files
            .map((f) => f.path)
            .whereType<String>()
            .toList();
        _academicNames = result.files.map((f) => f.name).toList();
      }
    });
  }

  void _next() {
    if (!_keys[_step].currentState!.validate()) return;
    if (_step == 2 && !_validateReferees()) return;
    if (_step == 2 &&
        (_photoPath == null ||
            _identityPath == null ||
            _academicPaths.isEmpty)) {
      _message('Photo, identity copy and academic certificate are required.');
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
      _page.animateToPage(
        _step,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
    _page.animateToPage(
      _step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _submit() async {
    if (!_declared) {
      _message('Please accept the declaration.');
      return;
    }
    setState(() => _busy = true);
    final fields = <String, String>{
      'name': _v('name'),
      'name_bangla': _v('name_bangla'),
      'father_name': _v('father_name'),
      'mother_name': _v('mother_name'),
      'date_of_birth': _v('date_of_birth'),
      'email': _v('email'),
      'phone': _v('phone'),
      'mailing_address': _v('address'),
      'nationality': _v('nationality'),
      'national_id_passport': _v('nid'),
      'institution': _v('institution'),
      'designation': _v('designation'),
      'qualification': _academic.first.value('degree'),
      'medical_societies': _v('medical_societies'),
      'recommending_fellow': _referees
          .map((row) => row.value('name'))
          .join('; '),
      'membership_tier_id': _tierId.toString(),
      'password': _v('password'),
      'password_confirmation': _v('password_confirmation'),
      'declaration': '1',
      'academic_qualifications': jsonEncode([
        for (final row in _academic) row.values,
      ]),
      'cardiology_trainings': jsonEncode(_nonEmptyRows(_training)),
      'practical_experiences': jsonEncode(_nonEmptyRows(_experience)),
      'publications_authored': jsonEncode(_nonEmptyRows(_publications)),
      'referees': jsonEncode([for (final row in _referees) row.values]),
    };
    if (_paymentProvider != null && _v('payment_reference').isNotEmpty) {
      fields['payment_provider'] = _paymentProvider!;
      fields['payment_reference'] = _v('payment_reference');
    }
    final result = await _api.registerApplication(
      fields: fields,
      photoPath: _photoPath!,
      identityPath: _identityPath!,
      academicCertificatePaths: _academicPaths,
      trainingCertificatePath: _trainingPath,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result['status'] == 'success') {
      _message(result['message']?.toString() ?? 'Application submitted.');
      Navigator.pop(context);
      return;
    }
    _showServerErrors(result);
  }

  String _v(String key) => _c[key]!.text.trim();
  List<Map<String, String>> _nonEmptyRows(List<_Entry> rows) => rows
      .map((row) => row.values)
      .where((row) => row.values.any((value) => value.isNotEmpty))
      .toList();
  bool _validateReferees() {
    if (_referees.length < 2) {
      setState(() => _refereeError = 'At least two referees are required.');
      return false;
    }
    final seen = <String>{};
    for (final referee in _referees) {
      final membership = referee.value('membership_number').toLowerCase();
      final nameInstitution =
          '${referee.value('name')}|${referee.value('institution')}'
              .toLowerCase();
      final identity = membership.isNotEmpty
          ? 'id:$membership'
          : 'name:$nameInstitution';
      if (!seen.add(identity)) {
        setState(
          () => _refereeError = 'The same referee cannot be added twice.',
        );
        return false;
      }
    }
    setState(() => _refereeError = null);
    return true;
  }

  void _showServerErrors(Map<String, dynamic> result) {
    final errors = result['errors'];
    final parsed = <String, String>{};
    if (errors is Map) {
      for (final item in errors.entries) {
        final values = item.value;
        if (values is List && values.isNotEmpty) {
          final key = switch (item.key.toString()) {
            'mailing_address' => 'address',
            'national_id_passport' => 'nid',
            _ => item.key.toString(),
          };
          parsed[key] = values.first.toString();
        }
      }
    }
    final field = parsed.keys.isEmpty ? null : parsed.keys.first;
    final step = _stepForField(field);
    setState(() {
      _serverErrors = parsed;
      if (step != null) _step = step;
    });
    if (step != null) {
      _page.animateToPage(
        step,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
    _message(
      field == null
          ? (result['message']?.toString() ?? 'Registration failed.')
          : 'Please correct the highlighted field.',
    );
  }

  int? _stepForField(String? field) {
    if (field == null) return null;
    if ([
      'name',
      'name_bangla',
      'father_name',
      'mother_name',
      'date_of_birth',
      'email',
      'phone',
      'address',
      'nationality',
      'nid',
    ].contains(field)) {
      return 0;
    }
    if (field.startsWith('academic_') ||
        field.startsWith('cardiology_') ||
        field.startsWith('practical_') ||
        field.startsWith('publications_') ||
        field == 'institution' ||
        field == 'designation' ||
        field == 'qualification' ||
        field == 'membership_tier_id') {
      return 1;
    }
    if (field.startsWith('referees') ||
        field == 'photo' ||
        field == 'identity_attachment' ||
        field.startsWith('academic_certificates') ||
        field == 'training_certificate') {
      return 2;
    }
    if (field.startsWith('password') || field == 'declaration') return 3;
    return null;
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F6FA),
    appBar: AppBar(
      title: const Text('Membership Application'),
      leading: IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back)),
    ),
    body: Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              Row(
                children: List.generate(
                  4,
                  (i) => Expanded(
                    child: Container(
                      height: 5,
                      margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? const Color(0xFFD20A17)
                            : const Color(0xFFE3E7EF),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Step ${_step + 1} of 4',
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                  Text(
                    ['Personal', 'Professional', 'Documents', 'Confirm'][_step],
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B2A67),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _page,
            physics: const NeverScrollableScrollPhysics(),
            children: [_personal(), _professional(), _documents(), _confirm()],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _busy ? null : _next,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD20A17),
                minimumSize: const Size.fromHeight(52),
              ),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_step == 3 ? 'Submit Application' : 'Continue'),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _personal() =>
      _form(0, 'Personal Information', 'As shown on your official documents', [
        _input('name', 'Name in English *'),
        _input('name_bangla', 'Name in Bangla', required: false),
        _input('father_name', "Father's Name *"),
        _input('mother_name', "Mother's Name *"),
        _dateOfBirthInput(),
        _input('email', 'Email *', type: TextInputType.emailAddress),
        _input('phone', 'Phone', required: false, type: TextInputType.phone),
        _input('address', 'Mailing Address *', lines: 3),
        _input('nationality', 'Nationality *'),
        _input('nid', 'NID / Passport Number *'),
      ]);
  Widget _professional() => _form(
    1,
    'Professional Profile',
    'Qualifications, training and experience',
    [
      _tier(),
      _input('institution', 'Current Institution / Hospital *'),
      _input('designation', 'Present Designation *'),
      _academicSection(),
      _trainingSection(),
      _experienceSection(),
      _input(
        'medical_societies',
        'Medical Society / Fellowship',
        required: false,
        lines: 2,
      ),
      _publicationSection(),
    ],
  );
  Widget _documents() => _form(
    2,
    'Referees & Enclosures',
    'At least two referees and supporting documents',
    [
      _refereeSection(),
      _file(
        'Applicant Photo *',
        _photoName,
        () => _pick('photo'),
        errorKey: 'photo',
      ),
      _file(
        'NID / Passport Copy *',
        _identityName,
        () => _pick('identity'),
        errorKey: 'identity_attachment',
      ),
      _file(
        'Academic Certificates *',
        _academicNames.isEmpty
            ? null
            : '${_academicNames.length} file(s) selected',
        () => _pick('academic'),
        errorKey: 'academic_certificates',
      ),
      _file(
        'Training Certificate',
        _trainingName,
        () => _pick('training'),
        errorKey: 'training_certificate',
      ),
    ],
  );
  Widget _confirm() => _form(
    3,
    'Security & Declaration',
    'Review and submit to the Secretariat',
    [
      _input('password', 'Choose Password *', password: true),
      _input(
        'password_confirmation',
        'Confirm Password *',
        password: true,
        confirm: true,
      ),
      DropdownButtonFormField<String>(
        initialValue: _paymentProvider,
        decoration: InputDecoration(
          labelText: 'Payment method (optional)',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: const [
          DropdownMenuItem(value: 'bkash', child: Text('bKash')),
          DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
          DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
          DropdownMenuItem(value: 'manual', child: Text('Other / manual')),
        ],
        onChanged: (value) => setState(() => _paymentProvider = value),
      ),
      const SizedBox(height: 14),
      _input(
        'payment_reference',
        'Payment transaction reference',
        required: false,
      ),
      CheckboxListTile(
        value: _declared,
        onChanged: (v) => setState(() => _declared = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'I declare that all information is true and agree to abide by BSCI rules.',
          style: TextStyle(fontSize: 14),
        ),
      ),
    ],
  );

  Widget _form(
    int index,
    String title,
    String subtitle,
    List<Widget> children,
  ) => Form(
    key: _keys[index],
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0B1739),
          ),
        ),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: Color(0xFF667085))),
        const SizedBox(height: 22),
        ...children,
      ],
    ),
  );
  Widget _input(
    String key,
    String label, {
    bool required = true,
    bool password = false,
    bool confirm = false,
    int lines = 1,
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: _c[key],
      obscureText: password,
      maxLines: password ? 1 : lines,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Required';
        }
        if (password && value!.length < 8) return 'Use at least 8 characters';
        if (confirm && value != _v('password')) return 'Passwords do not match';
        return null;
      },
      forceErrorText: _serverErrors[key],
    ),
  );
  Widget _dateOfBirthInput() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: _c['date_of_birth'],
      readOnly: true,
      onTap: () async {
        final initial =
            DateTime.tryParse(_v('date_of_birth')) ??
            DateTime(DateTime.now().year - 30);
        final selected = await showDatePicker(
          context: context,
          initialDate: initial.isAfter(DateTime.now())
              ? DateTime.now()
              : initial,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (selected != null) {
          setState(
            () => _c['date_of_birth']!.text =
                '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
          );
        }
      },
      decoration: _decoration(
        'Date of Birth *',
      ).copyWith(suffixIcon: const Icon(Icons.calendar_month_outlined)),
      validator: (value) =>
          value == null || value.isEmpty ? 'Select your date of birth' : null,
      forceErrorText: _serverErrors['date_of_birth'],
    ),
  );

  Widget _refereeSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader(
        'Referees',
        'Add at least two trainers. Duplicate referees are blocked.',
        _referees.length >= 5
            ? null
            : () => setState(
                () => _referees.add(
                  _Entry(['name', 'membership_number', 'institution']),
                ),
              ),
      ),
      if (_refereeError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _refereeError!,
            style: const TextStyle(
              color: Color(0xFFB42318),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ..._referees.asMap().entries.map((item) {
        final index = item.key;
        final row = item.value;
        return _entryCard(
          index: index,
          remove: _referees.length <= 2
              ? null
              : () => setState(() {
                  row.dispose();
                  _referees.removeAt(index);
                }),
          children: [
            _entryInput(row, 'name', 'Referee name *', required: true),
            _entryInput(row, 'membership_number', 'Membership number'),
            _entryInput(
              row,
              'institution',
              'Institution / hospital *',
              required: true,
            ),
          ],
        );
      }),
    ],
  );

  Widget _tier() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<int>(
      initialValue: _tierId,
      decoration: InputDecoration(
        labelText: 'Membership Type *',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _tiers
          .map(
            (t) => DropdownMenuItem<int>(
              value: t['id'] as int,
              child: Text('${t['name']} — BDT ${_price(t['price'])}'),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _tierId = v),
      validator: (v) => v == null ? 'Required' : null,
    ),
  );

  String _price(dynamic value) {
    final price = double.tryParse(value?.toString() ?? '') ?? 0;
    return price
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(?<!^)(?=(\d{3})+$)'), (match) => ',');
  }

  Widget _sectionHeader(String title, String hint, VoidCallback? onAdd) =>
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF0B2A67),
                    ),
                  ),
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add new'),
            ),
          ],
        ),
      );

  Widget _entryCard({
    required int index,
    VoidCallback? remove,
    required List<Widget> children,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD9E1EE)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Entry ${index + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B2A67),
              ),
            ),
            const Spacer(),
            if (remove != null)
              IconButton(
                onPressed: remove,
                tooltip: 'Remove entry',
                color: const Color(0xFFD20A17),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        ...children,
      ],
    ),
  );

  Widget _academicSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader(
        'Academic Qualifications',
        'Add each qualification once.',
        () => setState(
          () => _academic.add(
            _Entry(['degree', 'year', 'institution', 'country']),
          ),
        ),
      ),
      ..._academic.asMap().entries.map((item) {
        final index = item.key;
        final row = item.value;
        final selected = _academic
            .where((entry) => entry != row)
            .map((entry) => entry.value('degree'))
            .where((value) => value.isNotEmpty)
            .toSet();
        return _entryCard(
          index: index,
          remove: () => setState(() {
            row.dispose();
            _academic.removeAt(index);
          }),
          children: [
            DropdownButtonFormField<String>(
              initialValue: row.value('degree').isEmpty
                  ? null
                  : row.value('degree'),
              decoration: _decoration('Degree *'),
              items: _degrees
                  .where((degree) => !selected.contains(degree))
                  .map(
                    (degree) =>
                        DropdownMenuItem(value: degree, child: Text(degree)),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => row.set('degree', value ?? '')),
              validator: (value) => value == null ? 'Select a degree' : null,
            ),
            const SizedBox(height: 10),
            _entryInput(row, 'year', 'Year'),
            _entryInput(row, 'institution', 'Institution'),
            _entryInput(row, 'country', 'Country'),
          ],
        );
      }),
    ],
  );

  Widget _trainingSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader(
        'Training in Cardiology',
        'Add only if applicable.',
        () => setState(
          () => _training.add(
            _Entry(['institution', 'country', 'from', 'to', 'duration']),
          ),
        ),
      ),
      ..._training.asMap().entries.map((item) {
        final i = item.key;
        final row = item.value;
        return _entryCard(
          index: i,
          remove: () => setState(() {
            row.dispose();
            _training.removeAt(i);
          }),
          children: [
            _entryInput(row, 'institution', 'Institution'),
            _entryInput(row, 'country', 'Country'),
            _entryInput(row, 'from', 'From'),
            _entryInput(row, 'to', 'To'),
            _entryInput(row, 'duration', 'Duration (year/month)'),
          ],
        );
      }),
    ],
  );

  Widget _experienceSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader(
        'Practical Experience',
        'Choose each procedure once.',
        () => setState(
          () => _experience.add(
            _Entry([
              'procedure',
              'independent_count',
              'training_place',
              'from',
              'to',
              'duration',
            ]),
          ),
        ),
      ),
      ..._experience.asMap().entries.map((item) {
        final i = item.key;
        final row = item.value;
        final selected = _experience
            .where((entry) => entry != row)
            .map((entry) => entry.value('procedure'))
            .where((value) => value.isNotEmpty)
            .toSet();
        return _entryCard(
          index: i,
          remove: () => setState(() {
            row.dispose();
            _experience.removeAt(i);
          }),
          children: [
            DropdownButtonFormField<String>(
              initialValue: row.value('procedure').isEmpty
                  ? null
                  : row.value('procedure'),
              decoration: _decoration('Procedure'),
              items: _procedures
                  .where((procedure) => !selected.contains(procedure))
                  .map(
                    (procedure) => DropdownMenuItem(
                      value: procedure,
                      child: Text(procedure),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => row.set('procedure', value ?? '')),
            ),
            const SizedBox(height: 10),
            _entryInput(
              row,
              'independent_count',
              'Done independently (number)',
              type: TextInputType.number,
            ),
            _entryInput(row, 'training_place', 'Training place'),
            _entryInput(row, 'from', 'From'),
            _entryInput(row, 'to', 'To'),
            _entryInput(row, 'duration', 'Duration (year/month)'),
          ],
        );
      }),
    ],
  );

  Widget _publicationSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader(
        'Publications as Primary Author',
        'Add only if applicable.',
        () => setState(
          () => _publications.add(
            _Entry(['journal', 'year', 'title', 'co_author']),
          ),
        ),
      ),
      ..._publications.asMap().entries.map((item) {
        final i = item.key;
        final row = item.value;
        return _entryCard(
          index: i,
          remove: () => setState(() {
            row.dispose();
            _publications.removeAt(i);
          }),
          children: [
            _entryInput(row, 'journal', 'Journal name'),
            _entryInput(row, 'year', 'Year'),
            _entryInput(row, 'title', 'Title', lines: 2),
            _entryInput(row, 'co_author', 'Co-author', lines: 2),
          ],
        );
      }),
    ],
  );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFFDFEFF),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
  Widget _entryInput(
    _Entry row,
    String key,
    String label, {
    int lines = 1,
    TextInputType? type,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextFormField(
      controller: row.controllers[key],
      maxLines: lines,
      keyboardType: type,
      decoration: _decoration(label),
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
    ),
  );
  Widget _file(
    String label,
    String? name,
    VoidCallback pick, {
    String? errorKey,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: pick,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            alignment: Alignment.centerLeft,
          ),
          icon: const Icon(Icons.attach_file),
          label: Text(name ?? label, overflow: TextOverflow.ellipsis),
        ),
        if (errorKey != null && _serverErrors[errorKey] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _serverErrors[errorKey]!,
              style: const TextStyle(color: Color(0xFFB42318), fontSize: 12),
            ),
          ),
      ],
    ),
  );
}

class _Entry {
  _Entry(Iterable<String> keys)
    : controllers = {for (final key in keys) key: TextEditingController()};

  final Map<String, TextEditingController> controllers;

  String value(String key) => controllers[key]?.text.trim() ?? '';

  Map<String, String> get values => {
    for (final item in controllers.entries) item.key: item.value.text.trim(),
  };

  void set(String key, String value) => controllers[key]?.text = value;

  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}
