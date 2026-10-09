import 'package:bsciapp/api/api_service.dart';
import 'package:bsciapp/screens/journal_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _journalNavy = Color(0xFF0B1739);
const _journalRed = Color(0xFFD91E32);
const _journalMuted = Color(0xFF64748B);
const _journalBorder = Color(0xFFE2E8F0);

class PublicationsScreen extends StatefulWidget {
  final bool embedded;
  const PublicationsScreen({super.key, this.embedded = false});

  @override
  State<PublicationsScreen> createState() => _PublicationsScreenState();
}

class _PublicationsScreenState extends State<PublicationsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _publications = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedVolume = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await ApiService().getPublications();
      if (!mounted) return;
      final parsed = items
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();
      setState(() {
        _publications = parsed;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load journal publications.';
        _loading = false;
      });
    }
  }

  List<String> get _volumeFilters {
    final volumes = <String>{'All'};
    for (final pub in _publications) {
      final vol = pub['issue_volume']?.toString().trim();
      if (vol != null && vol.isNotEmpty) {
        volumes.add(vol);
      }
    }
    return volumes.toList();
  }

  List<Map<String, dynamic>> get _filteredPublications {
    return _publications.where((pub) {
      final title = pub['title']?.toString().toLowerCase() ?? '';
      final authors = pub['authors']?.toString().toLowerCase() ?? '';
      final abstractText = pub['abstract']?.toString().toLowerCase() ?? '';
      final volume = pub['issue_volume']?.toString() ?? '';

      final matchesQuery = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          authors.contains(_searchQuery.toLowerCase()) ||
          abstractText.contains(_searchQuery.toLowerCase());

      final matchesVolume =
          _selectedVolume == 'All' || volume == _selectedVolume;

      return matchesQuery && matchesVolume;
    }).toList();
  }

  void _openDetail(Map<String, dynamic> pub) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JournalDetailScreen(
          publication: pub,
          allPublications: _publications,
        ),
      ),
    );
  }

  void _downloadPdf(String url) {
    if (url.isNotEmpty) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      color: _journalRed,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // 1. TOP BJCI JOURNAL OFFICIAL HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF07183D), Color(0xFF0F2C69)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x220B1739),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6675).withValues(alpha: 0.2),
                            border: Border.all(
                              color: const Color(0xFFFF6675).withValues(alpha: 0.4),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                size: 12,
                                color: Color(0xFFFF858D),
                              ),
                              SizedBox(width: 5),
                              Text(
                                'OFFICIAL JOURNAL OF BSCI',
                                style: TextStyle(
                                  color: Color(0xFFFF858D),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bangladesh Journal of Cardiovascular Intervention',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Peer-reviewed, open-access international journal advancing interventional cardiovascular research, registries and clinical practice.',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaPill(icon: Icons.lock_open_rounded, text: 'Open Access'),
                        _MetaPill(icon: Icons.rate_review_outlined, text: 'Peer-Reviewed'),
                        _MetaPill(icon: Icons.bookmark_border_rounded, text: 'e-ISSN: 2789-9128'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. SEARCH BAR & VOLUME FILTER CHIPS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Box
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _searchQuery.isNotEmpty
                            ? _journalRed.withValues(alpha: 0.5)
                            : _journalBorder,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _journalNavy,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search title, author, or keyword…',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.normal,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF64748B),
                          size: 22,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFF64748B),
                                  size: 19,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),

                  // Volume Filter Chips
                  if (_volumeFilters.length > 1) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _volumeFilters.map((vol) {
                          final selected = _selectedVolume == vol;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                vol == 'All' ? 'All Issues' : vol,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: selected ? Colors.white : _journalNavy,
                                ),
                              ),
                              selected: selected,
                              selectedColor: _journalRed,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: selected
                                    ? _journalRed
                                    : const Color(0xFFE2E8F0),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _selectedVolume = vol),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3. ARTICLES LIST / SKELETON / EMPTY STATE
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: _journalRed),
              ),
            )
          else if (_error != null && _publications.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: _journalMuted)),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _journalRed,
                      ),
                      onPressed: _load,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          else if (_filteredPublications.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          Icons.menu_book_outlined,
                          size: 40,
                          color: _journalRed,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No articles match "$_searchQuery"'
                            : 'No articles in this issue volume.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _journalNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Check the title spelling, search by author, or clear filters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _journalMuted,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty || _selectedVolume != 'All') ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _selectedVolume = 'All';
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Reset Search & Filters'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              sliver: SliverList.separated(
                itemCount: _filteredPublications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, index) =>
                    _articleCard(_filteredPublications[index]),
              ),
            ),
        ],
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('BSCI Journal (BJCI)'),
        centerTitle: true,
      ),
      body: body,
    );
  }

  Widget _articleCard(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? 'BSCI Publication';
    final authors = item['authors']?.toString() ?? '';
    final volume = item['issue_volume']?.toString() ?? 'BJCI Journal';
    final articleType =
        item['article_type']?.toString().replaceAll('_', ' ').toUpperCase() ??
        'ORIGINAL RESEARCH';
    final abstractText = item['abstract']?.toString() ?? '';
    final thumbnail = item['thumbnail_url']?.toString() ?? '';
    final pdfUrl =
        item['download_url']?.toString() ?? item['viewer_url']?.toString() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetail(item),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _journalBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080B1739),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badges Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8EA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      volume,
                      style: const TextStyle(
                        color: _journalRed,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      articleType,
                      style: const TextStyle(
                        color: _journalNavy,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Title & Thumbnail Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (thumbnail.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 58,
                        height: 74,
                        child: CachedNetworkImage(
                          imageUrl: thumbnail,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const ColoredBox(
                            color: Color(0xFFF0F3F8),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, _, _) => _journalIconFallback(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: _journalNavy,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Authors Row
              if (authors.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1.5),
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: _journalRed,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        authors,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Abstract Excerpt
              if (abstractText.isNotEmpty) ...[
                Text(
                  abstractText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // Bottom Actions Row
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 10,
                        ),
                        alignment: Alignment.centerLeft,
                        foregroundColor: _journalNavy,
                      ),
                      onPressed: () => _openDetail(item),
                      icon: const Icon(
                        Icons.menu_book_rounded,
                        size: 16,
                        color: _journalRed,
                      ),
                      label: const Text(
                        'Read Details & 3D Reader →',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (pdfUrl.isNotEmpty)
                    IconButton(
                      tooltip: 'Download PDF',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.file_download_outlined,
                        size: 20,
                        color: _journalNavy,
                      ),
                      onPressed: () => _downloadPdf(pdfUrl),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _journalIconFallback() => Container(
    color: const Color(0xFFF0F3F8),
    child: const Center(
      child: Icon(
        Icons.menu_book_rounded,
        size: 28,
        color: Color(0xFF94A3B8),
      ),
    ),
  );
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
