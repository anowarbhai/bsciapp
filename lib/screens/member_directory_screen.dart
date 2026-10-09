import 'dart:async';

import 'package:bsciapp/api/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const _directoryRed = Color(0xFFD20A17);
const _directoryNavy = Color(0xFF0B1739);
const _directoryMuted = Color(0xFF667085);
const _directoryBorder = Color(0xFFE2E8F0);

class MemberDirectoryScreen extends StatefulWidget {
  const MemberDirectoryScreen({super.key});

  @override
  State<MemberDirectoryScreen> createState() => _MemberDirectoryScreenState();
}

class _MemberDirectoryScreenState extends State<MemberDirectoryScreen> {
  final _api = ApiService();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  final List<dynamic> _members = [];
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _total = 0;

  String _searchQuery = '';
  String _selectedTier = 'All';

  final List<String> _tiers = const [
    'All',
    'Life Membership',
    'General Membership',
    'Associate Membership',
    'Honorary Membership',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 420 &&
        !_loadingMore &&
        _hasMore) {
      _load();
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
      _load(reset: true);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    if (_searchQuery.isNotEmpty) {
      setState(() => _searchQuery = '');
      _load(reset: true);
    }
  }

  void _selectTier(String tier) {
    if (_selectedTier == tier) return;
    setState(() => _selectedTier = tier);
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _error = null;
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }

    final result = await _api.getMembers(
      page: _page,
      query: _searchQuery.isNotEmpty ? _searchQuery : null,
      tier: _selectedTier != 'All' ? _selectedTier : null,
    );

    if (!mounted) return;
    if (result['status'] != 'success') {
      setState(() {
        _error = result['message']?.toString() ?? 'Unable to load members.';
        _loading = false;
        _loadingMore = false;
      });
      return;
    }

    final incoming = result['members'] as List? ?? const [];
    final pagination = (result['pagination'] as Map?) ?? const {};
    setState(() {
      if (reset) _members.clear();
      _members.addAll(incoming);
      _total =
          int.tryParse(pagination['total']?.toString() ?? '') ??
          _members.length;
      _hasMore = pagination['has_more'] == true;
      if (_hasMore) _page++;
      _loading = false;
      _loadingMore = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showMemberProfile(Map<String, dynamic> member) {
    final photo = member['photo_url']?.toString() ?? '';
    final name = member['name']?.toString() ?? 'BSCI Member';
    final designation = member['designation']?.toString() ?? '';
    final qualification = member['qualification']?.toString() ?? '';
    final institution = member['institution']?.toString() ?? '';
    final bmdc = member['bmdc_number']?.toString() ?? '';
    final tier = member['membership_tier']?.toString() ?? '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: photo.isEmpty
                        ? _photoFallback(size: 40)
                        : CachedNetworkImage(
                            imageUrl: photo,
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                            placeholder: (_, _) => const ColoredBox(
                              color: Color(0xFFF0F3F8),
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, _, _) => _photoFallback(size: 40),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _directoryNavy,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF0284C7),
                            size: 20,
                          ),
                        ],
                      ),
                      if (qualification.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          qualification,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _directoryRed,
                          ),
                        ),
                      ],
                      if (tier.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE8EA),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            tier,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _directoryRed,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            if (designation.isNotEmpty)
              _profileRow(Icons.badge_outlined, 'Designation', designation),
            if (institution.isNotEmpty)
              _profileRow(Icons.local_hospital_outlined, 'Hospital / Institution', institution),
            if (bmdc.isNotEmpty)
              _profileRow(Icons.fingerprint_rounded, 'BM&DC Registration', bmdc),
            _profileRow(
              Icons.shield_outlined,
              'Society Status',
              'Verified Interventional Cardiologist · BSCI Bangladesh',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: const BorderSide(color: _directoryBorder),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close Profile',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _directoryNavy,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _directoryNavy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _directoryMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _directoryNavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _directoryRed,
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. TOP HEADER BANNER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF07183D), Color(0xFF0F2E6B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x220B1739),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0x22FFFFFF),
                      child: Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BSCI Member Directory',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _loading
                                ? 'Searching registry…'
                                : '$_total verified cardiologists & specialists',
                            style: const TextStyle(
                              color: Color(0xFFBFCAE1),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. SEARCH BAR & TIER FILTERS (STICKY-FEEL)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modern Search Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _searchQuery.isNotEmpty
                            ? _directoryRed.withValues(alpha: 0.5)
                            : _directoryBorder,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _directoryNavy,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by name, BMDC, hospital, designation…',
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
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFF64748B),
                                  size: 19,
                                ),
                                onPressed: _clearSearch,
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

                  const SizedBox(height: 10),

                  // Horizontal Tier Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _tiers.map((tier) {
                        final selected = _selectedTier == tier;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              tier == 'All' ? 'All Members' : tier,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: selected ? Colors.white : _directoryNavy,
                              ),
                            ),
                            selected: selected,
                            selectedColor: _directoryRed,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: selected
                                  ? _directoryRed
                                  : const Color(0xFFE2E8F0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            showCheckmark: false,
                            onSelected: (_) => _selectTier(tier),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. MAIN MEMBERS LIST / LOADING / EMPTY STATE
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: _directoryRed),
              ),
            )
          else if (_error != null && _members.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: _directoryMuted)),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _directoryRed),
                      onPressed: () => _load(reset: true),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          else if (_members.isEmpty)
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
                          Icons.person_search_rounded,
                          size: 40,
                          color: _directoryRed,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No members found matching "$_searchQuery"'
                            : 'No members in this category.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _directoryNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Check the doctor name spelling, BMDC number, or clear your filters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _directoryMuted,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty || _selectedTier != 'All') ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _selectedTier = 'All';
                            });
                            _load(reset: true);
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList.separated(
                itemCount: _members.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _memberCard(
                  (_members[index] as Map).cast<String, dynamic>(),
                ),
              ),
            ),

          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 28),
                child: Center(
                  child: CircularProgressIndicator(color: _directoryRed),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _memberCard(Map<String, dynamic> member) {
    final photo = member['photo_url']?.toString() ?? '';
    final tier = member['membership_tier']?.toString() ?? '';
    final bmdc = member['bmdc_number']?.toString() ?? '';
    final qualification = member['qualification']?.toString() ?? '';
    final designation = member['designation']?.toString() ?? '';
    final institution = member['institution']?.toString() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMemberProfile(member),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _directoryBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080B1739),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 66,
                  height: 66,
                  child: photo.isEmpty
                      ? _photoFallback()
                      : CachedNetworkImage(
                          imageUrl: photo,
                          fit: BoxFit.cover,
                          memCacheWidth: 160,
                          placeholder: (_, _) => const ColoredBox(
                            color: Color(0xFFF0F3F8),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, _, _) => _photoFallback(),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            member['name']?.toString() ?? 'BSCI Member',
                            style: const TextStyle(
                              color: _directoryNavy,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8),
                          size: 18,
                        ),
                      ],
                    ),
                    if (designation.isNotEmpty || qualification.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        designation.isNotEmpty ? designation : qualification,
                        style: const TextStyle(
                          color: _directoryRed,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (institution.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: _directoryMuted,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              institution,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _directoryMuted,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (tier.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE8EA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tier,
                              style: const TextStyle(
                                color: _directoryRed,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (bmdc.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'BMDC: $bmdc',
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoFallback({double size = 32}) => ColoredBox(
    color: const Color(0xFFF1F5F9),
    child: Icon(
      Icons.person_outline_rounded,
      color: const Color(0xFF94A3B8),
      size: size,
    ),
  );
}
