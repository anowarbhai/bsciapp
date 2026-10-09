import 'package:bsciapp/api/api_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.caseId});
  final int caseId;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  final _api = ApiService();
  final _comment = TextEditingController();
  Map<String, dynamic>? _case;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  int? _selectedPoll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.getCaseDetails(widget.caseId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['status'] == 'success') {
        _case = (result['case'] as Map).cast<String, dynamic>();
      } else {
        _error = '${result['message']}';
      }
    });
  }

  Future<void> _vote() async {
    if (_selectedPoll == null) return;
    final result = await _api.voteCasePoll(widget.caseId, _selectedPoll!);
    if (!mounted) return;
    _notice(
      result['status'] == 'success'
          ? 'Your poll response was saved.'
          : '${result['message']}',
    );
    if (result['status'] == 'success') await _load();
  }

  Future<void> _submitComment() async {
    final value = _comment.text.trim();
    if (value.isEmpty || _sending) return;
    setState(() => _sending = true);
    final result = await _api.submitCaseDiscussion(widget.caseId, value);
    if (!mounted) return;
    setState(() => _sending = false);
    if (result['status'] == 'success') {
      _comment.clear();
      _notice('Comment sent for moderator approval.');
    } else {
      _notice('${result['message']}');
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Case Details')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: _content(),
            ),
          ),
  );

  List<Widget> _content() {
    final item = _case!;
    final media = (item['media'] as List? ?? const []).cast<Map>();
    final discussions = (item['case_discussions'] as List? ?? const [])
        .cast<Map>();
    final pollOptions = (item['poll_options'] as List? ?? const []);
    return [
      Text(
        '${item['category'] ?? 'Clinical case'}'
            .replaceAll('_', ' ')
            .toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFD32F2F),
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '${item['title']}',
        style: const TextStyle(
          color: Color(0xFF0B1739),
          fontSize: 28,
          fontWeight: FontWeight.w900,
          height: 1.15,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Presented by ${item['user']?['name'] ?? 'BSCI Clinical Team'} · ${item['views_count'] ?? 0} views',
        style: const TextStyle(color: Color(0xFF64748B)),
      ),
      const SizedBox(height: 20),
      _card(
        Text(
          '${item['description'] ?? ''}',
          style: const TextStyle(fontSize: 16, height: 1.65),
        ),
      ),
      if (media.isNotEmpty) ...[
        const SizedBox(height: 20),
        const Text(
          'Case Media',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...media.map((entry) => _media(entry.cast<String, dynamic>())),
      ],
      if (item['poll_question'] != null && pollOptions.length >= 2) ...[
        const SizedBox(height: 20),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Clinical Poll',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text('${item['poll_question']}'),
              RadioGroup<int>(
                groupValue: _selectedPoll,
                onChanged: (value) => setState(() => _selectedPoll = value),
                child: Column(
                  children: List.generate(
                    pollOptions.length,
                    (index) => RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      value: index,
                      title: Text('${pollOptions[index]}'),
                    ),
                  ),
                ),
              ),
              FilledButton(
                onPressed: _selectedPoll == null ? null : _vote,
                child: const Text('Save Vote'),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 22),
      const Text(
        'Member Discussion',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 10),
      if (discussions.isEmpty) _card(const Text('No approved discussion yet.')),
      ...discussions.map(
        (entry) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry['user']?['name'] ?? 'BSCI Member'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${entry['comment_body'] ?? ''}',
                  style: const TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a clinical observation',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _comment,
              minLines: 3,
              maxLines: 7,
              maxLength: 3000,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Your comment will be reviewed before publication.',
              ),
            ),
            FilledButton(
              onPressed: _sending ? null : _submitComment,
              child: Text(_sending ? 'Sending…' : 'Send for Review'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _media(Map<String, dynamic> media) {
    final url = '${media['url']}';
    final mime = '${media['mime_type']}';
    if (mime.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (_, _, _) => const SizedBox(
              height: 140,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton.icon(
        onPressed: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        icon: Icon(
          mime.startsWith('video/')
              ? Icons.play_circle_outline
              : Icons.picture_as_pdf_outlined,
        ),
        label: Text('Open ${media['original_name'] ?? 'case media'}'),
      ),
    );
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: child,
  );
}
