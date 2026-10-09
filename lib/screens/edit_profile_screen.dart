import 'package:bsciapp/api/api_service.dart';
import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const EditProfileScreen({super.key, required this.user});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _fields = {
      for (final key in [
        'name',
        'email',
        'phone',
        'institution',
        'designation',
        'qualification',
      ])
        key: TextEditingController(text: widget.user[key]?.toString() ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    final result = await ApiService().updateProfile(
      _fields.map((k, v) => MapEntry(k, v.text.trim())),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ??
              (result['status'] == 'success'
                  ? 'Profile updated.'
                  : 'Update failed.'),
        ),
      ),
    );
    if (result['status'] == 'success') Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Profile')),
    body: Form(
      key: _key,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final entry in _fields.entries) ...[
            TextFormField(
              controller: entry.value,
              keyboardType: entry.key == 'email'
                  ? TextInputType.emailAddress
                  : entry.key == 'phone'
                  ? TextInputType.phone
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: _label(entry.key),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  entry.key != 'phone' && (v == null || v.trim().isEmpty)
                  ? 'Required'
                  : null,
            ),
            const SizedBox(height: 14),
          ],
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD20A17),
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(_busy ? 'Saving…' : 'Save Changes'),
          ),
        ],
      ),
    ),
  );
  String _label(String key) => {
    'name': 'Full name',
    'email': 'Email',
    'phone': 'Phone',
    'institution': 'Institution',
    'designation': 'Designation',
    'qualification': 'Qualification',
  }[key]!;
}
