import 'package:flutter/material.dart';
import 'package:bsciapp/api/api_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _red = Color(0xFFD20A17);
const _navy = Color(0xFF0B1739);
const _blue = Color(0xFF0A43B5);
const _muted = Color(0xFF667085);

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<dynamic> _apiNotices = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _officialNotices = [
    {
      'id': 'pinned-1',
      'title': 'Extension of Abstract Submission Deadline for BD Intervention 2026',
      'ref': 'BSCI/SCI/2026-089',
      'category': 'Conference',
      'date': '12 Oct 2026',
      'is_pinned': true,
      'is_urgent': true,
      'summary':
          'The Scientific Sub-Committee is pleased to announce that the deadline for abstract & complex clinical case submissions has been extended to August 15, 2026. Accepted abstracts will be published in the supplementary edition of the BJCI.',
      'authority': 'Scientific Sub-Committee, BSCI',
      'pdf_url': 'https://bsci.digitrixlabs.io/notices/BSCI-SCI-2026-089.pdf',
      'pdf_size': '240 KB',
    },
    {
      'id': 'conf-2',
      'title': 'Call for Complex Live Coronary Case Submissions & Operators',
      'ref': 'BSCI/CONF/2026-084',
      'category': 'Conference',
      'date': '05 Oct 2026',
      'is_pinned': false,
      'is_urgent': false,
      'summary':
          'Cardiologists and intervention fellows are invited to submit unedited DICOM recordings of interesting and complex coronary or structural cases for transmission during BD Intervention 2026.',
      'authority': 'Conference Secretariat, Pan Pacific Sonargaon',
      'pdf_url': 'https://bsci.digitrixlabs.io/notices/BSCI-CONF-2026-084.pdf',
      'pdf_size': '380 KB',
    },
    {
      'id': 'mem-3',
      'title': 'Annual Membership Verification & Life Member Directory Update 2026-27',
      'ref': 'BSCI/MEM/2026-078',
      'category': 'Membership',
      'date': '28 Sep 2026',
      'is_pinned': false,
      'is_urgent': false,
      'summary':
          'All Life and General members are requested to review and verify their official BMDC registration number, contact phone, and hospital affiliation in the online portal before printing of the annual directory.',
      'authority': 'BSCI Central Secretariat',
      'pdf_url': 'https://bsci.digitrixlabs.io/notices/BSCI-MEM-2026-078.pdf',
      'pdf_size': '195 KB',
    },
    {
      'id': 'agm-4',
      'title': 'Notice of the 12th Annual General Meeting (AGM) of BSCI',
      'ref': 'BSCI/AGM/2026-071',
      'category': 'AGM',
      'date': '18 Sep 2026',
      'is_pinned': false,
      'is_urgent': false,
      'summary':
          'The 12th Annual General Meeting of the Bangladesh Society of Cardiovascular Intervention will be held on Saturday, 17 October 2026 at 06:30 PM at Grand Ballroom, Pan Pacific Sonargaon, Dhaka.',
      'authority': 'Secretary General, BSCI',
      'pdf_url': 'https://bsci.digitrixlabs.io/notices/BSCI-AGM-2026-071.pdf',
      'pdf_size': '510 KB',
    },
    {
      'id': 'aca-5',
      'title': 'Young Interventionalist Travel Grant Award Announcement 2026',
      'ref': 'BSCI/ACA/2026-065',
      'category': 'Academic',
      'date': '02 Sep 2026',
      'is_pinned': false,
      'is_urgent': false,
      'summary':
          'Applications are invited for 5 competitive travel grants to support young cardiology fellows presenting accepted original research at BD Intervention 2026.',
      'authority': 'Academic & Fellowship Committee',
      'pdf_url': 'https://bsci.digitrixlabs.io/notices/BSCI-ACA-2026-065.pdf',
      'pdf_size': '1.2 MB',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  Future<void> _fetchNotices() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getNotices();
      if (mounted) {
        setState(() {
          _apiNotices = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filteredNotices() {
    final combined = <Map<String, dynamic>>[];
    for (final item in _apiNotices) {
      if (item is Map) combined.add(item.cast<String, dynamic>());
    }
    combined.addAll(_officialNotices);

    return combined.where((n) {
      final cat = n['category'] as String? ?? '';
      final matchesCategory = _selectedCategory == 'All' ||
          cat.toLowerCase() == _selectedCategory.toLowerCase();
      final title = (n['title'] as String? ?? '').toLowerCase();
      final summary = (n['summary'] as String? ?? '').toLowerCase();
      final ref = (n['ref'] as String? ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase().trim();
      final matchesQuery = q.isEmpty ||
          title.contains(q) ||
          summary.contains(q) ||
          ref.contains(q);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document URL.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading circular document...')),
      );
    }
  }

  void _shareNotice(Map<String, dynamic> notice) {
    final title = notice['title'] as String? ?? '';
    final ref = notice['ref'] as String? ?? '';
    final summary = notice['summary'] as String? ?? '';
    final url = notice['pdf_url'] as String? ?? 'https://bscibd.org';
    SharePlus.instance.share(
      ShareParams(
        text: 'BSCI Official Notice: $title\nRef: $ref\n\n$summary\n\nView details: $url',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notices = _filteredNotices();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _navy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Official Notice Board',
              style: TextStyle(
                color: _navy,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Bangladesh Society of Cardiovascular Intervention',
              style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _fetchNotices,
            icon: const Icon(Icons.refresh_rounded, color: _navy),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotices,
        color: _red,
        child: Column(
          children: [
            // Search Bar & Filter Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search circulars, notices, ref #...',
                      hintStyle: const TextStyle(color: _muted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Category Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _categoryChip('All', 'All (${_officialNotices.length})'),
                        _categoryChip('Conference', 'Summit 2026'),
                        _categoryChip('Membership', 'Membership'),
                        _categoryChip('AGM', 'AGM Circulars'),
                        _categoryChip('Academic', 'Academic & Grants'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Notice List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _red))
                  : notices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: _muted.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              const Text(
                                'No notices found matching your criteria.',
                                style: TextStyle(color: _muted, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: notices.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _buildNoticeCard(notices[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String categoryKey, String label) {
    final active = _selectedCategory == categoryKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = categoryKey),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _red : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : _navy,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> item) {
    final isPinned = item['is_pinned'] == true;
    final isUrgent = item['is_urgent'] == true;
    final title = item['title'] as String? ?? '';
    final ref = item['ref'] as String? ?? '';
    final date = item['date'] as String? ?? '';
    final summary = item['summary'] as String? ?? '';
    final category = item['category'] as String? ?? 'General';
    final authority = item['authority'] as String? ?? 'BSCI Authority';
    final pdfUrl = item['pdf_url'] as String? ?? '';
    final pdfSize = item['pdf_size'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPinned ? _red : const Color(0xFFE2E8F0),
          width: isPinned ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Tags
          Row(
            children: [
              if (isPinned) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '📌 PINNED',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (isUrgent) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'URGENT',
                    style: TextStyle(color: Color(0xFF991B1B), fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: const TextStyle(color: _blue, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
              const Spacer(),
              Text(
                date,
                style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Ref ID
          Text(
            'Ref: $ref',
            style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 4),

          // Title
          Text(
            title,
            style: const TextStyle(
              color: _navy,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 6),

          // Summary
          Text(
            summary,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 12,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          const SizedBox(height: 10),

          // Bottom Authority & Actions
          Row(
            children: [
              Expanded(
                child: Text(
                  authority,
                  style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 18, color: _muted),
                onPressed: () => _shareNotice(item),
                tooltip: 'Share',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => _openPdf(pdfUrl),
                icon: const Icon(Icons.download_rounded, size: 14),
                label: Text(pdfSize.isNotEmpty ? 'PDF ($pdfSize)' : 'Download PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPinned ? _red : const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
