import 'dart:io';
import 'dart:math' as math;

import 'package:bsciapp/api/api_service.dart';
import 'package:bsciapp/services/pdf_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _journalNavy = Color(0xFF0B1739);
const _journalRed = Color(0xFFD91E32);
const _journalMuted = Color(0xFF64748B);
const _journalBorder = Color(0xFFE2E8F0);

class JournalDetailScreen extends StatefulWidget {
  final Map<String, dynamic> publication;
  final List<Map<String, dynamic>>? allPublications;

  const JournalDetailScreen({
    super.key,
    required this.publication,
    this.allPublications,
  });

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  late final Map<String, dynamic> _pub = widget.publication;
  bool _flipMode = false;
  bool _pointerInsidePdfReader = false;
  late final ScrollController _articleScrollController;
  double _lockedArticleOffset = 0;
  bool _restoringArticleOffset = false;

  void _setPdfGestureActive(bool active) {
    _pointerInsidePdfReader = active;
    if (active && _articleScrollController.hasClients) {
      _lockedArticleOffset = _articleScrollController.offset;
    }
  }

  void _keepArticleStillWhileReading() {
    if (!_pointerInsidePdfReader ||
        _restoringArticleOffset ||
        !_articleScrollController.hasClients) {
      return;
    }
    if ((_articleScrollController.offset - _lockedArticleOffset).abs() < 0.5) {
      return;
    }
    _restoringArticleOffset = true;
    _articleScrollController.jumpTo(_lockedArticleOffset);
    _restoringArticleOffset = false;
  }

  File? _cachedPdfFile;
  bool _isPdfDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _articleScrollController = ScrollController()
      ..addListener(_keepArticleStillWhileReading);
    _recordPublicationView();
    _loadAndCachePdf();
  }

  @override
  void dispose() {
    _articleScrollController
      ..removeListener(_keepArticleStillWhileReading)
      ..dispose();
    super.dispose();
  }

  void _loadAndCachePdf() async {
    final pdfUrl =
        _pub['viewer_url']?.toString() ??
        _pub['download_url']?.toString() ??
        '';
    if (pdfUrl.isEmpty) return;

    final pubId = _pub['id'];

    // 1. Check if already cached locally
    final existing = await PdfCacheService().getCachedPdf(pdfUrl, pubId: pubId);
    if (existing != null && mounted) {
      setState(() {
        _cachedPdfFile = existing;
        _downloadProgress = 1.0;
      });
      return;
    }

    // 2. Not cached yet: begin download with real-time progress
    if (!mounted) return;
    setState(() {
      _isPdfDownloading = true;
      _downloadProgress = 0.0;
      _downloadError = null;
    });

    try {
      final file = await PdfCacheService().getOrDownloadPdf(
        pdfUrl,
        pubId: pubId,
        onProgress: (p) {
          if (mounted) {
            setState(() => _downloadProgress = p);
          }
        },
      );
      if (mounted) {
        setState(() {
          _cachedPdfFile = file;
          _isPdfDownloading = false;
          _downloadProgress = 1.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPdfDownloading = false;
          _downloadError = e.toString();
        });
      }
    }
  }

  void _shareArticle() {
    final title = _pub['title']?.toString() ?? 'BJCI Article';
    final shareUrl =
        _pub['web_url']?.toString() ??
        _pub['viewer_url']?.toString() ??
        _pub['download_url']?.toString() ??
        '';
    SharePlus.instance.share(
      ShareParams(
        text:
            '$title\n\nRead online in Bangladesh Journal of Cardiovascular Intervention (BJCI):\n$shareUrl',
      ),
    );
  }

  Future<void> _recordPublicationView() async {
    final publicationId = int.tryParse(_pub['id']?.toString() ?? '');
    if (publicationId == null) return;

    final response = await ApiService().getPublication(publicationId);
    final publication = response['publication'];
    if (!mounted || response['status'] != 'success' || publication is! Map) {
      return;
    }
    setState(() => _pub.addAll(publication.cast<String, dynamic>()));
  }

  Future<void> _recordCachedDownload() async {
    final publicationId = int.tryParse(_pub['id']?.toString() ?? '');
    if (publicationId == null) return;

    final response = await ApiService().recordPublicationDownload(
      publicationId,
    );
    if (!mounted || response['status'] != 'success') return;
    setState(() {
      _pub['views_count'] = response['views_count'] ?? _pub['views_count'];
      _pub['downloads_count'] =
          response['downloads_count'] ?? _pub['downloads_count'];
    });
  }

  void _incrementDownloadOptimistically() {
    if (!mounted) return;
    final current =
        int.tryParse(_pub['downloads_count']?.toString() ?? '') ?? 0;
    setState(() => _pub['downloads_count'] = current + 1);
  }

  void _downloadPdf() async {
    if (_cachedPdfFile != null) {
      await _recordCachedDownload();
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(_cachedPdfFile!.path)],
          text: _pub['title']?.toString() ?? 'BJCI Manuscript',
        ),
      );
      return;
    }

    final downloadUrl =
        _pub['download_url']?.toString() ??
        _pub['viewer_url']?.toString() ??
        '';
    if (downloadUrl.isNotEmpty) {
      final launched = await launchUrl(
        Uri.parse(downloadUrl),
        mode: LaunchMode.externalApplication,
      );
      if (launched) _incrementDownloadOptimistically();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF download link is not available.')),
      );
    }
  }

  void _copyCitation() {
    final title = _pub['title']?.toString() ?? 'BJCI Article';
    final authors = _pub['authors']?.toString() ?? 'BSCI Research Group';
    final volume = _pub['issue_volume']?.toString() ?? 'Vol. 4';
    final citation =
        '$authors. $title. Bangladesh Journal of Cardiovascular Intervention (BJCI). 2026; $volume.';
    Clipboard.setData(ClipboardData(text: citation));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Article citation copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openFullScreenReader() {
    final pdfUrl =
        _pub['viewer_url']?.toString() ??
        _pub['download_url']?.toString() ??
        '';
    if (pdfUrl.isEmpty && _cachedPdfFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manuscript PDF is not available.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenReader(
          title: _pub['title']?.toString() ?? 'BJCI Reader',
          pdfFile: _cachedPdfFile,
          pdfUrl: pdfUrl,
          pagesUrl: _pub['reader_pages_url']?.toString() ?? '',
          initialFlipMode: _flipMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _pub['title']?.toString() ?? 'BSCI Journal Article';
    final authors = _pub['authors']?.toString() ?? '';
    final volume = _pub['issue_volume']?.toString() ?? 'BJCI Journal';
    final articleType =
        _pub['article_type']?.toString().replaceAll('_', ' ').toUpperCase() ??
        'ORIGINAL RESEARCH';
    final abstractText = _pub['abstract']?.toString() ?? '';
    final description = _pub['description']?.toString() ?? '';
    final pdfUrl =
        _pub['viewer_url']?.toString() ??
        _pub['download_url']?.toString() ??
        '';
    final views = _pub['views_count']?.toString() ?? '0';
    final downloads = _pub['downloads_count']?.toString() ?? '0';
    final doi = _pub['doi']?.toString() ?? '10.5847/bjci.2026.04.002';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Article Details',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Share Article',
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareArticle,
          ),
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.download_rounded),
            onPressed: _downloadPdf,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        controller: _articleScrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= 1. ARTICLE HERO & METADATA =================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _journalBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0B1739),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE8EA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          volume,
                          style: const TextStyle(
                            color: _journalRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          articleType,
                          style: const TextStyle(
                            color: _journalNavy,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _journalNavy,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Authors
                  if (authors.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.person_pin_circle_outlined,
                            size: 16,
                            color: _journalRed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authors,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // DOI & Metadata Pills
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'DOI: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _journalMuted,
                                ),
                              ),
                              TextSpan(text: doi),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _journalNavy,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_open_rounded,
                              size: 11,
                              color: Color(0xFF059669),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'OPEN ACCESS',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _journalRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _openFullScreenReader,
                          icon: const Icon(Icons.menu_book_rounded, size: 18),
                          label: const Text(
                            'Read Fullscreen',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: _journalBorder),
                        ),
                        onPressed: _copyCitation,
                        icon: const Icon(Icons.format_quote_rounded, size: 18),
                        label: const Text(
                          'Cite',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _journalNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ================= 2. STRUCTURED ABSTRACT =================
            if (abstractText.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _journalBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0B1739),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE8EA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.summarize_rounded,
                            size: 17,
                            color: _journalRed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Abstract',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _journalNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      abstractText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF334155),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // ================= 3. DETAILED CLINICAL OVERVIEW =================
            if (description.isNotEmpty && description != abstractText) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _journalBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0B1739),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.article_rounded,
                            size: 17,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Full Study Overview',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _journalNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._buildFormattedSections(description),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // ================= 4. READING PORTAL (PDF READER & PAGE FLIP) =================
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _journalBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0B1739),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Portal Header & Segmented Controller
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    color: const Color(0xFF07183D),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'JOURNAL READING PORTAL',
                                    style: TextStyle(
                                      color: Color(0xFFFF858D),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Interactive Manuscript Viewer',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Expand Fullscreen',
                              icon: const Icon(
                                Icons.fullscreen_rounded,
                                color: Colors.white,
                              ),
                              onPressed: _openFullScreenReader,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<bool>(
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              backgroundColor: const Color(0xFF16254F),
                              selectedBackgroundColor: _journalRed,
                              selectedForegroundColor: Colors.white,
                              foregroundColor: const Color(0xFFBFCAE1),
                              side: const BorderSide(color: Color(0x33FFFFFF)),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: false,
                                icon: Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  'PDF Reader',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              ButtonSegment(
                                value: true,
                                icon: Icon(
                                  Icons.auto_stories_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  '3D Page Flip',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            selected: {_flipMode},
                            onSelectionChanged: (value) =>
                                setState(() => _flipMode = value.first),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reading Viewport (500px Height)
                  SizedBox(height: 500, child: _buildViewportContent(pdfUrl)),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ================= 5. CITATION & METRICS FOOTER =================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _journalBorder),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final stats = [
                    _statItem(Icons.remove_red_eye_outlined, '$views Views'),
                    _statItem(
                      Icons.file_download_outlined,
                      '$downloads Downloads',
                    ),
                    _statItem(Icons.lock_open_rounded, 'CC BY 4.0'),
                  ];
                  if (compact) {
                    return Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: 14,
                      runSpacing: 12,
                      children: stats,
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      stats[0],
                      Container(height: 24, width: 1, color: _journalBorder),
                      stats[1],
                      Container(height: 24, width: 1, color: _journalBorder),
                      stats[2],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewportContent(String fallbackUrl) {
    if (_isPdfDownloading && _cachedPdfFile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                size: 44,
                color: _journalRed,
              ),
              const SizedBox(height: 16),
              Text(
                _downloadProgress > 0
                    ? 'Caching Manuscript (${(_downloadProgress * 100).toInt()}%)'
                    : 'Connecting to BJCI Archive…',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: _journalNavy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Saving locally on device so pages turn instantly with zero lag and no repeated downloads.',
                style: TextStyle(
                  fontSize: 12,
                  color: _journalMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  minHeight: 7,
                  color: _journalRed,
                  backgroundColor: const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_downloadError != null && _cachedPdfFile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: _journalMuted,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not cache manuscript locally.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _journalNavy,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _loadAndCachePdf,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry Download'),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _flipMode
          ? _LocalPdfFlipViewer(
              key: ValueKey('flip-${_cachedPdfFile?.path ?? fallbackUrl}'),
              pdfFile: _cachedPdfFile,
              pdfUrl: fallbackUrl,
            )
          : Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _setPdfGestureActive(true),
              onPointerUp: (_) => _setPdfGestureActive(false),
              onPointerCancel: (_) => _setPdfGestureActive(false),
              child: _PdfReaderView(
                key: ValueKey('pdf-${_cachedPdfFile?.path ?? fallbackUrl}'),
                pdfFile: _cachedPdfFile,
                pdfUrl: fallbackUrl,
              ),
            ),
    );
  }

  Widget _statItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _journalMuted),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _journalNavy,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFormattedSections(String raw) {
    final lines = raw.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.endsWith(':') ||
          trimmed.startsWith('BACKGROUND') ||
          trimmed.startsWith('METHODS') ||
          trimmed.startsWith('RESULTS') ||
          trimmed.startsWith('CONCLUSION') ||
          trimmed.startsWith('EXECUTIVE SUMMARY') ||
          trimmed.startsWith('CLINICAL IMPLICATIONS')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              trimmed,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _journalRed,
                letterSpacing: 0.3,
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              trimmed,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF334155),
                height: 1.55,
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

// ---------------------------------------------------------------------------
// Standard PDF Viewer View (uses local file if available)
// ---------------------------------------------------------------------------
class _PdfReaderView extends StatelessWidget {
  final File? pdfFile;
  final String pdfUrl;
  const _PdfReaderView({super.key, this.pdfFile, required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    const readerParams = PdfViewerParams(
      backgroundColor: Color(0xFFE8EDF4),
      margin: 8,
      panAxis: PanAxis.vertical,
      scrollPhysics: ClampingScrollPhysics(),
      interactionDelegateProvider:
          PdfViewerScrollInteractionDelegateProviderPhysics(),
      verticalCacheExtent: 2,
    );
    if (pdfFile != null && pdfFile!.existsSync()) {
      return PdfViewer.file(pdfFile!.path, params: readerParams);
    }

    if (pdfUrl.isNotEmpty) {
      return PdfViewer.uri(
        Uri.parse(pdfUrl),
        timeout: const Duration(seconds: 45),
        params: readerParams,
      );
    }

    return const Center(
      child: Text(
        'PDF is not available for this article.',
        style: TextStyle(color: _journalMuted),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fallback Local PDF Flip Viewer (Optimized with single DocRef & zero network)
// ---------------------------------------------------------------------------
class _LocalPdfFlipViewer extends StatefulWidget {
  final File? pdfFile;
  final String pdfUrl;

  const _LocalPdfFlipViewer({super.key, this.pdfFile, required this.pdfUrl});

  @override
  State<_LocalPdfFlipViewer> createState() => _LocalPdfFlipViewerState();
}

class _LocalPdfFlipViewerState extends State<_LocalPdfFlipViewer> {
  late final PageController _controller = PageController();
  final ValueNotifier<int> _pageNotifier = ValueNotifier<int>(0);
  late final PdfDocumentRef _docRef;

  @override
  void initState() {
    super.initState();
    if (widget.pdfFile != null && widget.pdfFile!.existsSync()) {
      _docRef = PdfDocumentRefFile(widget.pdfFile!.path);
    } else {
      _docRef = PdfDocumentRefUri(Uri.parse(widget.pdfUrl));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PdfDocumentViewBuilder(
      documentRef: _docRef,
      loadingBuilder: (_) =>
          const Center(child: CircularProgressIndicator(color: _journalRed)),
      errorBuilder: (_, error, _) => const Center(
        child: Text(
          'Could not load manuscript document.',
          style: TextStyle(color: _journalMuted),
        ),
      ),
      builder: (_, document) {
        if (document == null) return const SizedBox.shrink();
        final count = document.pages.length;
        return Column(
          children: [
            // Top Navigation & Page Counter (Updates via ValueListenableBuilder ONLY)
            Container(
              color: const Color(0xFF0F1E3D),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: ValueListenableBuilder<int>(
                valueListenable: _pageNotifier,
                builder: (_, currentPage, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        iconSize: 20,
                        onPressed: currentPage == 0
                            ? null
                            : () => _controller.previousPage(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                              ),
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Page ${currentPage + 1} of $count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      IconButton(
                        iconSize: 20,
                        onPressed: currentPage >= count - 1
                            ? null
                            : () => _controller.nextPage(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                              ),
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // 3D Page View with cached pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: count,
                onPageChanged: (page) {
                  // Updates ONLY the header ValueNotifier without rebuilding the document
                  _pageNotifier.value = page;
                },
                itemBuilder: (_, index) => _KeepAlivePage(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, child) {
                      var value = 0.0;
                      if (_controller.position.haveDimensions) {
                        value = (_controller.page ?? 0) - index;
                      }
                      value = value.clamp(-1.0, 1.0);
                      return Transform(
                        alignment: value > 0
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, .0015)
                          ..rotateY(value * math.pi / 3.2),
                        child: child,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: PdfPageView(
                          document: document,
                          pageNumber: index + 1,
                          maximumDpi: 200,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Keep Alive helper to prevent re-rasterization of pages
// ---------------------------------------------------------------------------
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ---------------------------------------------------------------------------
// Immersive Full Screen Reader
// ---------------------------------------------------------------------------
class _FullScreenReader extends StatefulWidget {
  final String title;
  final File? pdfFile;
  final String pdfUrl;
  final String pagesUrl;
  final bool initialFlipMode;

  const _FullScreenReader({
    required this.title,
    this.pdfFile,
    required this.pdfUrl,
    required this.pagesUrl,
    this.initialFlipMode = false,
  });

  @override
  State<_FullScreenReader> createState() => _FullScreenReaderState();
}

class _FullScreenReaderState extends State<_FullScreenReader> {
  late bool _flipMode = widget.initialFlipMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07183D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07183D),
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: _flipMode
                ? 'Switch to Standard PDF'
                : 'Switch to 3D Page Flip',
            icon: Icon(
              _flipMode
                  ? Icons.picture_as_pdf_outlined
                  : Icons.auto_stories_outlined,
            ),
            onPressed: () => setState(() => _flipMode = !_flipMode),
          ),
        ],
      ),
      body: _flipMode
          ? _LocalPdfFlipViewer(pdfFile: widget.pdfFile, pdfUrl: widget.pdfUrl)
          : _PdfReaderView(pdfFile: widget.pdfFile, pdfUrl: widget.pdfUrl),
    );
  }
}
