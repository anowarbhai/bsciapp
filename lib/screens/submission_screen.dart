import 'package:bsciapp/api/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class SubmissionScreen extends StatefulWidget {
  final bool caseSubmission;
  final int? conferenceId;
  const SubmissionScreen({
    super.key,
    required this.caseSubmission,
    this.conferenceId,
  });

  @override
  State<SubmissionScreen> createState() => _SubmissionScreenState();
}

class _SubmissionScreenState extends State<SubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _details = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _designation = TextEditingController();
  final _workplace = TextEditingController();
  String? _filePath;
  String? _fileName;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _fullName.dispose();
    _email.dispose();
    _designation.dispose();
    _workplace.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: widget.caseSubmission
          ? ['pdf', 'jpg', 'jpeg', 'png', 'webp']
          : ['pdf', 'doc', 'docx'],
    );
    if (result != null && mounted) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.caseSubmission && _filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a PDF, DOC or DOCX abstract file.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final result = widget.caseSubmission
        ? await ApiService().submitCase(
            title: _title.text.trim(),
            description: _details.text.trim(),
            filePath: _filePath,
          )
        : await ApiService().submitAbstract(
            conferenceId: widget.conferenceId ?? 1,
            submittedName: _fullName.text.trim(),
            submittedEmail: _email.text.trim(),
            designation: _designation.text.trim(),
            workplace: _workplace.text.trim(),
            title: _title.text.trim(),
            abstractSummary: _details.text.trim(),
            filePath: _filePath!,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? 'Done')),
    );
    if (result['status'] == 'success') Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.caseSubmission ? 'Case Submission' : 'Abstract Submission',
      ),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.caseSubmission
                ? 'Submit Your Clinical Case'
                : 'Submit Your Research Abstract',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0B1739),
            ),
          ),
          const SizedBox(height: 20),
          if (!widget.caseSubmission) ...[
            TextFormField(
              controller: _fullName,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Full name is required'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || !v.contains('@')
                  ? 'Enter a valid email address'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _designation,
              decoration: const InputDecoration(
                labelText: 'Designation',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Designation is required'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _workplace,
              decoration: const InputDecoration(
                labelText: 'Workplace',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Workplace is required'
                  : null,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _title,
            maxLength: widget.caseSubmission ? null : 30,
            minLines: widget.caseSubmission ? 1 : 2,
            maxLines: widget.caseSubmission ? 1 : 3,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Title is required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _details,
            maxLength: widget.caseSubmission ? null : 200,
            minLines: widget.caseSubmission ? 4 : 5,
            maxLines: widget.caseSubmission ? 8 : 7,
            decoration: InputDecoration(
              labelText: widget.caseSubmission
                  ? 'Case description'
                  : 'Abstract summary',
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'This field is required' : null,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.attach_file),
            label: Text(
              _fileName ??
                  (widget.caseSubmission
                      ? 'Attach file (optional)'
                      : 'Select PDF, DOC or DOCX file'),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: const Color(0xFFD20A17),
            ),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Submit'),
          ),
        ],
      ),
    ),
  );
}
