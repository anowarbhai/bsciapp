import 'dart:async';

import 'package:bsciapp/api/api_service.dart';
import 'package:bsciapp/app_preferences.dart';
import 'package:bsciapp/deep_link_router.dart';
import 'package:bsciapp/screens/login_screen.dart';
import 'package:bsciapp/screens/faculty_detail_screen.dart';
import 'package:bsciapp/screens/edit_profile_screen.dart';
import 'package:bsciapp/screens/event_detail_screen.dart';
import 'package:bsciapp/screens/gallery_screen.dart';
import 'package:bsciapp/screens/past_committees_screen.dart';
import 'package:bsciapp/screens/member_center_screen.dart';
import 'package:bsciapp/screens/member_directory_screen.dart';
import 'package:bsciapp/screens/membership_center_screen.dart';
import 'package:bsciapp/screens/submission_screen.dart';
import 'package:bsciapp/screens/publications_screen.dart';
import 'package:bsciapp/screens/cases_screen.dart';
import 'package:bsciapp/screens/notice_screen.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

const _red = Color(0xFFD20A17);
const _navy = Color(0xFF0B1739);
const _blue = Color(0xFF0A43B5);
const _muted = Color(0xFF667085);

class DashboardScreen extends StatefulWidget {
  final Uri? deepLink;
  const DashboardScreen({super.key, this.deepLink});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  int _index = 0;
  bool _loading = true;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _conference;
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _homepage = {};
  Map<String, dynamic> _about = {};
  List<dynamic> _events = [];
  List<dynamic> _faculties = [];
  List<dynamic> _sliders = [];
  int _facultyTab = 0;
  String _facultyQuery = '';
  String _facultyCountry = '';
  String _facultyExpertise = '';
  final PageController _sliderController = PageController();
  Timer? _sliderTimer;
  int _sliderIndex = 0;
  Set<int> _bookmarks = {};
  Set<int> _registeredEventIds = {};
  String? _handledDeepLink;

  String get _webBase => _api.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.deepLink != oldWidget.deepLink) _handleDeepLink(widget.deepLink);
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final results = await Future.wait([
      _api.getMemberProfile(),
      _api.getConference(),
      _api.getEvents(),
      _api.getFaculties(),
      _api.getSettings(),
      _api.getSliders(),
      _api.getHomepage(),
      _api.getAbout(),
    ]);
    if (!mounted) return;
    final profileResult = results[0] as Map<String, dynamic>;
    final overviewResult = profileResult['status'] == 'success'
        ? await _api.getMemberOverview()
        : <String, dynamic>{};
    final overviewData =
        overviewResult['data'] as Map<String, dynamic>? ?? overviewResult;
    final registrations = (overviewData['registrations'] as List?) ?? const [];
    setState(() {
      _profile = profileResult['status'] == 'success'
          ? profileResult['data'] as Map<String, dynamic>
          : null;
      _conference = results[1] as Map<String, dynamic>?;
      _events = results[2] as List<dynamic>;
      _faculties = results[3] as List<dynamic>;
      _settings = results[4] as Map<String, dynamic>;
      _sliders = results[5] as List<dynamic>;
      _homepage = results[6] as Map<String, dynamic>;
      _about = results[7] as Map<String, dynamic>;
      _bookmarks = (preferences.getStringList('event_bookmarks') ?? const [])
          .map(int.parse)
          .toSet();
      _registeredEventIds = registrations
          .map((item) => int.tryParse(item['event_id'].toString()))
          .whereType<int>()
          .toSet();
      _loading = false;
    });
    _startSliderTimer();
    _handleDeepLink(widget.deepLink);
  }

  void _handleDeepLink(Uri? uri) {
    if (!mounted || uri == null || _handledDeepLink == uri.toString()) return;
    _handledDeepLink = uri.toString();
    final destination = resolveDeepLink(uri);
    if (destination == DeepLinkDestination.events) {
      setState(() => _index = 1);
    } else if (destination == DeepLinkDestination.publications) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PublicationsScreen()),
        ),
      );
    } else if (destination == DeepLinkDestination.cases) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CasesScreen()),
        ),
      );
    } else if (destination == DeepLinkDestination.gallery) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GalleryScreen()),
        ),
      );
    } else if (destination == DeepLinkDestination.notices) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openNotices());
    }
  }

  void _startSliderTimer() {
    _sliderTimer?.cancel();
    if (_sliders.length < 2) return;
    final slide = (_sliders[_sliderIndex] as Map).cast<String, dynamic>();
    if (_slideVideoUrl(slide).isNotEmpty) return;
    _sliderTimer = Timer(const Duration(seconds: 5), _advanceSlider);
  }

  void _advanceSlider() {
    if (!mounted || !_sliderController.hasClients || _sliders.length < 2) {
      return;
    }
    final next = (_sliderIndex + 1) % _sliders.length;
    _sliderController.animateToPage(
      next,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOutCubic,
    );
  }

  String _slideVideoUrl(Map<String, dynamic> slide) {
    final apiUrl = slide['video_url']?.toString() ?? '';
    if (apiUrl.isNotEmpty) return apiUrl;
    final path = slide['video_path']?.toString() ?? '';
    if (path.isEmpty) return '';
    return path.startsWith('http')
        ? path
        : '$_webBase/${path.replaceFirst(RegExp(r'^/+'), '')}';
  }

  @override
  void dispose() {
    _sliderTimer?.cancel();
    _sliderController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    setState(() {
      _profile = null;
      _index = 0;
    });
  }

  Future<bool> _requireLogin() async {
    if (_profile != null) return true;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (!mounted) return false;
    final result = await _api.getMemberProfile();
    if (result['status'] == 'success') {
      setState(() => _profile = result['data'] as Map<String, dynamic>);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _index == 0
          ? _header()
          : AppBar(
              title: Text(
                [
                  AppPreferences.text('Home', 'হোম'),
                  AppPreferences.text('Events', 'ইভেন্ট'),
                  AppPreferences.text('Members', 'সদস্য'),
                  AppPreferences.text('Journal', 'জার্নাল'),
                  AppPreferences.text('More', 'আরও'),
                  AppPreferences.text('Call for Science', 'বৈজ্ঞানিক আহ্বান'),
                  AppPreferences.text('Faculties', 'ফ্যাকাল্টি'),
                ][_index],
              ),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _index = 0),
              ),
              actions: [
                IconButton(
                  tooltip: AppPreferences.text('Notices', 'নোটিশ'),
                  icon: const Icon(Icons.campaign_outlined, color: _red),
                  onPressed: _openNotices,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: _openNotifications,
                  ),
                ),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : IndexedStack(
              index: _index,
              children: [
                _home(),
                _eventsPage(),
                const MemberDirectoryScreen(),
                const PublicationsScreen(embedded: true),
                _more(),
                _science(),
                _facultyV2(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index <= 4 ? _index : 4,
        onDestinationSelected: (value) => setState(() => _index = value),
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: const Color(0xFFFFE8EA),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: _red),
            label: AppPreferences.text('Home', 'হোম'),
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: _red),
            label: AppPreferences.text('Events', 'ইভেন্ট'),
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded, color: _red),
            label: AppPreferences.text('Members', 'সদস্য'),
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded, color: _red),
            label: AppPreferences.text('Journal', 'জার্নাল'),
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz, color: _red),
            label: AppPreferences.text('More', 'আরও'),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _header() => AppBar(
    toolbarHeight: 78,
    automaticallyImplyLeading: false,
    titleSpacing: 14,
    title: Row(
      children: [
        Image.asset(
          'assets/branding/bsci_logo.png',
          width: 50,
          height: 50,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => const SizedBox(
            width: 50,
            height: 50,
            child: Icon(Icons.favorite_rounded, color: _red, size: 36),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'BSCI',
                style: TextStyle(
                  color: Color(0xFF123378),
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                'Bangladesh Society of\nCardiovascular Intervention',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _navy, fontSize: 8.5, height: 1.05),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 2),
        child: InkWell(
          onTap: _openNotices,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _red.withValues(alpha: 0.35), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.campaign_rounded, size: 16, color: _red),
                const SizedBox(width: 4),
                Text(
                  AppPreferences.text('Notice', 'নোটিশ'),
                  style: const TextStyle(
                    color: _red,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: _red,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconButton(
          onPressed: _openNotifications,
          icon: const Badge(
            smallSize: 8,
            backgroundColor: _red,
            child: Icon(Icons.notifications_none_rounded, color: _navy),
          ),
        ),
      ),
    ],
  );

  Widget _home() => RefreshIndicator(
    onRefresh: _load,
    color: _red,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _sliderCarousel(),
        const SizedBox(height: 18),
        _welcomeSection(),
        const SizedBox(height: 16),
        _committeeSection(),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Highlights & Announcements',
          child: Column(
            children: [
              _announcement(
                Icons.calendar_month,
                'BD Intervention 2026',
                'Registration is Now Open!',
                'Join the premier cardiovascular intervention event.',
              ),
              const Divider(height: 1),
              _announcement(
                Icons.description_outlined,
                'Call for Science',
                'Abstract & case submission',
                'Share your research with the scientific community.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Quick Access',
          child: Row(
            children: [
              _quick(Icons.calendar_month_outlined, 'Events', _red, 1),
              _quick(Icons.edit_note_rounded, 'Call for\nScience', _blue, 2),
              _quick(Icons.groups_outlined, 'Faculty', Colors.deepPurple, 3),
              _quick(Icons.phone_outlined, 'Contact Us', Colors.green, 4),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _welcomeSection() {
    final welcome =
        (_homepage['welcome'] as Map?)?.cast<String, dynamic>() ?? {};
    final leaders = (welcome['leaders'] as List?) ?? const [];
    final paragraphs = (welcome['paragraphs'] as List?) ?? const [];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 19, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B2A67), Color(0xFF14214A)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WELCOME MESSAGE',
                  style: TextStyle(
                    color: Color(0xFFFF8A94),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Leadership Vision',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  welcome['title']?.toString() ??
                      'From the President & Secretary General',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (leaders.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...leaders.map((leader) => _leaderRow(leader)),
                ],
                const SizedBox(height: 8),
                ...paragraphs
                    .take(2)
                    .map(
                      (text) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Text(
                          text.toString(),
                          style: const TextStyle(color: _muted, height: 1.55),
                        ),
                      ),
                    ),
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse('$_webBase/about')),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 17),
                  label: const Text('Read the full message'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderRow(dynamic leader) {
    final item = (leader as Map).cast<String, dynamic>();
    final photo = item['photo_url']?.toString();
    final name = item['name']?.toString() ?? 'BSCI Leader';
    final initials = name
        .split(RegExp(r'\s+'))
        .where(
          (part) => ![
            'prof.',
            'prof',
            'dr.',
            'dr',
            'md.',
          ].contains(part.toLowerCase()),
        )
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFFFE8EA),
            backgroundImage: photo != null && photo.isNotEmpty
                ? CachedNetworkImageProvider(photo)
                : null,
            child: photo == null || photo.isEmpty
                ? Text(
                    initials.isEmpty ? 'BSCI' : initials,
                    style: const TextStyle(
                      color: _red,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  item['role']?.toString() ?? '',
                  style: const TextStyle(color: _red, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _committeeSection() {
    final committee =
        (_homepage['committee'] as Map?)?.cast<String, dynamic>() ?? {};
    final session = (committee['session'] as Map?)?.cast<String, dynamic>();
    final members = (committee['members'] as List?) ?? const [];
    if (members.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SOCIETY LEADERSHIP',
                            style: TextStyle(
                              color: Color(0xFFFF6672),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Executive Committee${session?['name'] != null ? ' ${session!['name']}' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${members.length} members',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              itemCount: members.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) => _committeeCard(members[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _committeeCard(dynamic member) {
    final item = (member as Map).cast<String, dynamic>();
    final photo = item['photo_url']?.toString();
    return Container(
      width: 190,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 135,
            child: photo != null && photo.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photo,
                    fit: BoxFit.cover,
                    memCacheWidth: 420,
                    placeholder: (_, _) =>
                        const ColoredBox(color: Color(0xFFE9EEF6)),
                    errorWidget: (_, _, _) => const Icon(
                      Icons.person_outline,
                      size: 62,
                      color: Color(0xFF9AA8BD),
                    ),
                  )
                : const ColoredBox(
                    color: Color(0xFFE9EEF6),
                    child: Icon(
                      Icons.person_outline,
                      size: 62,
                      color: Color(0xFF9AA8BD),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          if (item['badge']?.toString().isNotEmpty == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _red,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                item['badge'].toString().toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            item['name']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _navy, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            item['role']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _red, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _sliderCarousel() {
    final slides = _sliders.isEmpty
        ? [
            {
              'title': _conference?['title'] ?? 'BD INTERVENTION 2026',
              'image_path': 'assets/slider_conference.jpg',
            },
          ]
        : _sliders;
    return Column(
      children: [
        SizedBox(
          height: 315,
          child: PageView.builder(
            controller: _sliderController,
            itemCount: slides.length,
            onPageChanged: (index) {
              setState(() => _sliderIndex = index);
              _startSliderTimer();
            },
            itemBuilder: (context, index) =>
                _slide(slides[index], isActive: index == _sliderIndex),
          ),
        ),
        if (slides.length > 1) ...[
          const SizedBox(height: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (index) {
              final active = index == _sliderIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: active ? 24 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: active ? _red : const Color(0xFFD4D7DE),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _slide(dynamic item, {required bool isActive}) {
    final slide = (item as Map).cast<String, dynamic>();
    final videoUrl = _slideVideoUrl(slide);
    final apiImage = slide['image_url']?.toString();
    final path = slide['image_path']?.toString();
    final imageUrl = apiImage != null && apiImage.isNotEmpty
        ? apiImage
        : path == null || path.isEmpty
        ? '$_webBase/assets/slider_conference.jpg'
        : (path.startsWith('http')
              ? path
              : '$_webBase/${path.replaceFirst(RegExp(r'^/+'), '')}');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF06265D),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoUrl.isNotEmpty)
            _SlideVideo(
              key: ValueKey(videoUrl),
              url: videoUrl,
              isActive: isActive,
              onFinished: _advanceSlider,
            )
          else
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 1000,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, _) => const ColoredBox(color: Color(0xFF06265D)),
              errorWidget: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF06265D)),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x12031C4C),
                  Color(0x48031C4C),
                  Color(0xE6031C4C),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                if (slide['title']?.toString().trim().isNotEmpty == true)
                  Text(
                    slide['title'].toString().toUpperCase(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                      letterSpacing: -.35,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x100B1739),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _navy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _announcement(
    IconData icon,
    String overline,
    String title,
    String subtitle,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Container(
          width: 74,
          height: 78,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE9EA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 38, color: _red),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overline,
                style: const TextStyle(
                  color: _red,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: _muted),
      ],
    ),
  );

  Widget _quick(IconData icon, String label, Color color, int page) => Expanded(
    child: InkWell(
      onTap: () => setState(() => _index = page),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Container(
          height: 102,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .07),
            border: Border.all(color: color.withValues(alpha: .13)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _navy, fontSize: 11, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _eventsPage() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _title(
          'Upcoming Events',
          'Scientific meetings, workshops and conferences',
        ),
        const SizedBox(height: 18),
        if (_events.isEmpty)
          _empty('No upcoming events')
        else
          ..._events.map((event) => _eventCard(event)),
      ],
    ),
  );

  Widget _eventCard(dynamic event) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: _card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event, color: _red),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                event['title']?.toString() ?? '',
                style: const TextStyle(
                  color: _navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: _bookmarks.contains(event['id'])
                  ? 'Remove bookmark'
                  : 'Save event',
              onPressed: () => _toggleBookmark(event['id'] as int),
              icon: Icon(
                _bookmarks.contains(event['id'])
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: _red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '${event['date']}  •  ${event['time'] ?? 'Time TBA'}\n${event['location']}',
          style: const TextStyle(color: _muted),
        ),
        const SizedBox(height: 8),
        Text(
          event['remaining_spots'] == null
              ? '${event['registrations_count'] ?? 0} registered'
              : '${event['registrations_count'] ?? 0} registered  •  ${event['remaining_spots']} seats left  •  ${event['cme_points'] ?? 0} CME points',
          style: const TextStyle(
            color: _blue,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _openEventDetails(event),
                child: const Text('View Details'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed:
                    (_registeredEventIds.contains(event['id']) ||
                        event['is_full'] == true)
                    ? null
                    : () async {
                        if (!await _requireLogin()) return;
                        final result = await _api.registerForEvent(
                          event['id'] as int,
                        );
                        if (mounted) {
                          if (result['status'] == 'success') {
                            setState(() {
                              _registeredEventIds.add(event['id'] as int);
                              event['registrations_count'] =
                                  (int.tryParse(
                                        '${event['registrations_count'] ?? 0}',
                                      ) ??
                                      0) +
                                  1;
                              if (event['remaining_spots'] != null) {
                                event['remaining_spots'] =
                                    ((int.tryParse(
                                                  '${event['remaining_spots']}',
                                                ) ??
                                                1) -
                                            1)
                                        .clamp(0, 999999);
                              }
                            });
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['message']?.toString() ??
                                    'Registration could not be completed',
                              ),
                            ),
                          );
                        }
                      },
                style: FilledButton.styleFrom(backgroundColor: _red),
                child: Text(
                  _registeredEventIds.contains(event['id'])
                      ? 'Registered'
                      : (event['is_full'] == true
                            ? 'Event Full'
                            : 'Register Now'),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  void _openEventDetails(dynamic event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          event: (event as Map).cast<String, dynamic>(),
          memberLoggedIn: _profile != null,
          initiallyRegistered: _registeredEventIds.contains(event['id']),
          onRegister: (discountCode) =>
              _registerFromEventDetails(event, discountCode: discountCode),
          onGuestRegister: (fields) =>
              _api.registerGuestForEvent(event['id'] as int, fields),
          onPayment: (fields) =>
              _api.submitEventPayment(event['id'] as int, fields),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _registerFromEventDetails(
    dynamic event, {
    String? discountCode,
  }) async {
    if (!await _requireLogin()) {
      return {'status': 'error', 'message': 'Please log in to register.'};
    }
    final result = await _api.registerForEvent(
      event['id'] as int,
      discountCode: discountCode,
    );
    if (result['status'] == 'success' && mounted) {
      setState(() {
        _registeredEventIds.add(event['id'] as int);
        event['registrations_count'] =
            (int.tryParse('${event['registrations_count'] ?? 0}') ?? 0) + 1;
        if (event['remaining_spots'] != null) {
          event['remaining_spots'] =
              ((int.tryParse('${event['remaining_spots']}') ?? 1) - 1).clamp(
                0,
                999999,
              );
        }
      });
    }
    return result;
  }

  Widget _science() => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Container(
        height: 205,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(colors: [Color(0xFF78020B), _red]),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.manage_search_rounded, color: Colors.white, size: 52),
            SizedBox(height: 10),
            Text(
              'CALL FOR SCIENCE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Share your research and clinical experience.',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Submit your original research for scientific review.',
        style: TextStyle(color: _navy, fontSize: 17, height: 1.5),
      ),
      const SizedBox(height: 18),
      _actionCard(
        Icons.description_outlined,
        'Abstract Submission',
        'Submit original research for presentation.',
        _red,
        () => _openSubmission(false),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: () async {
          if (!await _requireLogin()) return;
          _openSubmission(false);
        },
        style: FilledButton.styleFrom(
          backgroundColor: _red,
          minimumSize: const Size.fromHeight(54),
        ),
        icon: const Icon(Icons.send_rounded),
        label: const Text('Start Your Submission'),
      ),
    ],
  );

  Widget _actionCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: _card(),
    child: InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 38),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(subtitle, style: const TextStyle(color: _muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );

  Widget _facultyV2() {
    final filtered = _faculties.where((item) {
      final text =
          '${item['name']} ${item['role']} ${item['institution']} ${item['country']} ${item['expertise']}'
              .toLowerCase();
      if (!text.contains(_facultyQuery.toLowerCase())) return false;
      if (_facultyCountry.isNotEmpty &&
          !item['country'].toString().toLowerCase().contains(
            _facultyCountry.toLowerCase(),
          )) {
        return false;
      }
      if (_facultyExpertise.isNotEmpty &&
          !item['expertise'].toString().toLowerCase().contains(
            _facultyExpertise.toLowerCase(),
          )) {
        return false;
      }
      final marker = '${item['badge']} ${item['category']}'.toLowerCase();
      final international = marker.contains('international');
      return _facultyTab == 0 ? international : marker.contains('national');
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Faculties',
                style: TextStyle(
                  color: _navy,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _facultyTabButton('International Faculty', 0),
                  _facultyTabButton('National Faculty', 1),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _facultyQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search faculty...',
                        hintStyle: const TextStyle(color: _muted),
                        prefixIcon: const Icon(Icons.search, color: _muted),
                        filled: true,
                        fillColor: const Color(0xFFF2F4F8),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 58,
                    height: 52,
                    decoration: BoxDecoration(
                      color:
                          _facultyCountry.isNotEmpty ||
                              _facultyExpertise.isNotEmpty
                          ? const Color(0xFFE8EEFF)
                          : const Color(0xFFF2F4F8),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: IconButton(
                      onPressed: _showFacultyFilters,
                      icon: const Icon(Icons.tune_rounded, color: _blue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _empty('No faculty found')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _facultyRow(
                    (filtered[index] as Map).cast<String, dynamic>(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _facultyTabButton(String label, int tab) {
    final selected = _facultyTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _facultyTab = tab),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? _red : _muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 4,
              decoration: BoxDecoration(
                color: selected ? _red : const Color(0xFFE4E7EC),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _facultyRow(Map<String, dynamic> person) {
    final path = person['photo_path']?.toString();
    final photo = path == null || path.isEmpty
        ? null
        : (path.startsWith('http')
              ? path
              : '$_webBase/${path.replaceFirst(RegExp(r'^/+'), '')}');
    final name = person['name']?.toString() ?? 'Faculty Member';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _card(),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FacultyDetailScreen(faculty: person, webBase: _webBase),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE8ECF3),
                  image: photo == null
                      ? null
                      : DecorationImage(
                          image: CachedNetworkImageProvider(photo),
                          fit: BoxFit.cover,
                        ),
                ),
                child: photo == null
                    ? Center(
                        child: Text(
                          name.substring(0, 1),
                          style: const TextStyle(
                            color: _blue,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      person['role']?.toString() ?? 'Cardiovascular Specialist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      person['institution']?.toString() ?? 'Bangladesh',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF596477),
                size: 29,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _more() {
    final signedIn = _profile != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        Text(
          AppPreferences.text('More', 'আরও'),
          style: TextStyle(
            color: _navy,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          AppPreferences.text('Explore more options', 'আরও সেবা দেখুন'),
          style: TextStyle(color: _muted, fontSize: 17),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: _card(),
          child: Column(
            children: [
              _moreItem(
                signedIn ? Icons.person_outline_rounded : Icons.login_rounded,
                signedIn ? 'My Profile' : 'Member Login',
                signedIn
                    ? 'View and update your profile'
                    : 'Sign in to access member services',
                signedIn ? _showProfile : () => _requireLogin(),
              ),
              _moreItem(
                Icons.bookmark_border_rounded,
                'My Bookmarks',
                'Saved events and important items',
                () async {
                  if (await _requireLogin()) {
                    _showBookmarks();
                  }
                },
              ),
              _moreItem(
                Icons.calendar_today_outlined,
                'My Registrations',
                'View your event registrations',
                () async {
                  if (await _requireLogin()) {
                    _openMemberSection('My Registrations');
                  }
                },
              ),
              _moreItem(
                Icons.card_membership_outlined,
                'Membership & Payments',
                'Renew membership, submit payment and download documents',
                () async {
                  if (await _requireLogin() && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MembershipCenterScreen(),
                      ),
                    );
                  }
                },
              ),
              _moreItem(
                Icons.description_outlined,
                'My Submissions',
                'Track your abstract and case submissions',
                () async {
                  if (await _requireLogin()) {
                    _openMemberSection('My Submissions');
                  }
                },
              ),
              _moreItem(
                Icons.science_outlined,
                'Call for Science',
                'Abstract submission and scientific opportunities',
                () => setState(() => _index = 5),
              ),
              _moreItem(
                Icons.groups_outlined,
                'Faculties',
                'Browse national and international faculty',
                () => setState(() => _index = 6),
              ),
              _moreItem(
                Icons.campaign_outlined,
                AppPreferences.text(
                  'Notice Board & Circulars',
                  'নোটিশ বোর্ড ও সার্কুলার',
                ),
                AppPreferences.text(
                  'Official notices, circulars and guidelines',
                  'অফিসিয়াল নোটিশ ও সার্কুলার দেখুন',
                ),
                _openNotices,
              ),
              _moreItem(
                Icons.notifications_none_rounded,
                'Notifications',
                'Stay updated with latest announcements',
                () async {
                  if (await _requireLogin()) {
                    _openMemberSection('Notifications');
                  }
                },
              ),
              _moreItem(
                Icons.download_outlined,
                'Publications & Downloads',
                'Read and download BSCI publications',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PublicationsScreen()),
                ),
              ),
              _moreItem(
                Icons.monitor_heart_outlined,
                'Clinical Case Forum',
                'Read cases, review media, vote and discuss',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CasesScreen()),
                ),
              ),
              _moreItem(
                Icons.photo_library_outlined,
                'Photo Gallery',
                'BSCI conferences and activities',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GalleryScreen()),
                ),
              ),
              _moreItem(
                Icons.history_rounded,
                'Past Committees',
                'Browse previous committee sessions',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PastCommitteesScreen(),
                  ),
                ),
              ),
              _moreItem(
                Icons.event_available_outlined,
                'Conference Details',
                'Programme, venue and registration information',
                _showConferenceDetails,
              ),
              _moreItem(
                Icons.language_rounded,
                AppPreferences.text('Appearance & Language', 'থিম ও ভাষা'),
                AppPreferences.text(
                  'System/light/dark theme and বাংলা/English',
                  'থিম এবং বাংলা/English নির্বাচন করুন',
                ),
                _showAppPreferences,
              ),
              _moreItem(
                Icons.help_outline_rounded,
                'Help & FAQ',
                'Find help and frequently asked questions',
                () => _showTextPage(
                  'Help & FAQ',
                  'How do I register?\nOpen Events, choose an event and tap Register Now.\n\nHow do I submit research?\nOpen Call for Science and choose Abstract Submission.\n\nWhy can’t I sign in?\nNew memberships require administrator approval.',
                ),
              ),
              _moreItem(
                Icons.headset_mic_outlined,
                'Support',
                'Contact our support team',
                _showSupport,
              ),
              _moreItem(
                Icons.shield_outlined,
                'Privacy Policy',
                'Read our privacy policy',
                () => _showTextPage(
                  'Privacy Policy',
                  'BSCI uses account, professional and submission information only to operate membership, scientific events and research services. Authentication tokens are stored securely on your device. Contact BSCI to request correction or deletion of your information.',
                ),
              ),
              _moreItem(
                Icons.article_outlined,
                'Terms & Conditions',
                'Read terms and conditions',
                () => _showTextPage(
                  'Terms & Conditions',
                  'Use of this app is limited to lawful BSCI membership, education and scientific activities. Submitted content must be accurate and owned or authorized by the submitter. BSCI may review, approve or reject registrations and submissions.',
                ),
              ),
              _moreItem(
                Icons.info_outline_rounded,
                'About BSCI',
                'Learn more about BSCI',
                _showAbout,
              ),
              if (signedIn)
                _moreItem(
                  Icons.logout_rounded,
                  'Logout',
                  'Sign out from your account',
                  _logout,
                  showDivider: false,
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAppPreferences() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppPreferences.text('Appearance & Language', 'থিম ও ভাষা'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {AppPreferences.themeMode.value},
              onSelectionChanged: (value) {
                AppPreferences.setTheme(value.first);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'bn', label: Text('বাংলা')),
              ],
              selected: {AppPreferences.language.value},
              onSelectionChanged: (value) {
                AppPreferences.setLanguage(value.first);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _moreItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool showDivider = true,
  }) => Column(
    children: [
      ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5FA),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _red, size: 27),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: _navy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF5D6982),
        ),
      ),
      if (showDivider) const Divider(height: 1, color: Color(0xFFE8EAF0)),
    ],
  );

  void _showProfile() {
    final user = _profile?['user'] as Map<String, dynamic>?;
    final membership = _profile?['membership'] as Map<String, dynamic>?;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 22),
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFFFFE8EA),
                child: Text(
                  (user?['name']?.toString() ?? 'M').substring(0, 1),
                  style: const TextStyle(
                    color: _red,
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user?['name']?.toString() ?? '',
                style: const TextStyle(
                  color: _navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                membership?['tier_name']?.toString() ?? 'BSCI Member',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 18),
              if (membership?['qr_code_token'] != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: membership!['qr_code_token'].toString(),
                    size: 150,
                  ),
                ),
              const SizedBox(height: 12),
              _profileLine(
                Icons.badge_outlined,
                'BMDC',
                user?['bmdc_number']?.toString() ?? '—',
              ),
              _profileLine(
                Icons.local_hospital_outlined,
                'Institution',
                user?['institution']?.toString() ?? '—',
              ),
              _profileLine(
                Icons.email_outlined,
                'Email',
                user?['email']?.toString() ?? '—',
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: user == null
                      ? null
                      : () async {
                          Navigator.pop(context);
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfileScreen(user: user),
                            ),
                          );
                          if (changed == true) await _load();
                        },
                  style: FilledButton.styleFrom(backgroundColor: _red),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileLine(IconData icon, String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: _red),
    title: Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
    subtitle: Text(
      value,
      style: const TextStyle(color: _navy, fontWeight: FontWeight.w700),
    ),
  );

  void _showSupport() => showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Support',
              style: TextStyle(
                color: _navy,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            _contact(
              Icons.phone_outlined,
              'Phone',
              _settings['contact_phone']?.toString() ?? '+880 2 2222 12345',
            ),
            _contact(
              Icons.email_outlined,
              'Email',
              _settings['contact_email']?.toString() ?? 'info@bscibd.com',
            ),
          ],
        ),
      ),
    ),
  );

  void _showAbout() {
    final mission =
        _about['bsci_mission']?.toString() ??
        'BSCI advances interventional cardiology through education, research, training and collaboration.';
    final vision = _about['bsci_vision']?.toString();
    final president = _about['presidents_message']?.toString();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'About BSCI',
                style: TextStyle(
                  color: _navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(mission, style: const TextStyle(color: _muted, height: 1.6)),
              if (vision != null && vision.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Our Vision',
                  style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  vision,
                  style: const TextStyle(color: _muted, height: 1.5),
                ),
              ],
              if (president != null && president.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Welcome Message',
                  style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  president,
                  style: const TextStyle(color: _muted, height: 1.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showConferenceDetails() {
    final conference = _conference ?? const <String, dynamic>{};
    final title = conference['title']?.toString() ?? 'BSCI Conference';
    final description =
        conference['description']?.toString() ??
        'Programme and registration details will be announced by BSCI.';
    final venue = conference['venue']?.toString();
    final date =
        conference['date']?.toString() ?? conference['start_date']?.toString();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (date != null && date.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  date,
                  style: const TextStyle(
                    color: _red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (venue != null && venue.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(venue, style: const TextStyle(color: _muted)),
              ],
              const SizedBox(height: 18),
              Text(
                description,
                style: const TextStyle(color: _muted, height: 1.6),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _index = 1);
                  },
                  child: const Text('View Events & Register'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFacultyFilters() async {
    final country = TextEditingController(text: _facultyCountry);
    final expertise = TextEditingController(text: _facultyExpertise);
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Faculty',
              style: TextStyle(
                color: _navy,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: country,
              decoration: const InputDecoration(
                labelText: 'Country',
                hintText: 'e.g. Bangladesh, Japan',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: expertise,
              decoration: const InputDecoration(
                labelText: 'Specialty / expertise',
                hintText: 'e.g. CTO, IVUS',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, {'country': '', 'expertise': ''}),
                  child: const Text('Clear'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, {
                    'country': country.text.trim(),
                    'expertise': expertise.text.trim(),
                  }),
                  child: const Text('Apply filters'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    country.dispose();
    expertise.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _facultyCountry = result['country'] ?? '';
      _facultyExpertise = result['expertise'] ?? '';
    });
  }

  Widget _contact(IconData icon, String title, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: _red),
    ),
    title: Text(
      title,
      style: const TextStyle(color: _navy, fontWeight: FontWeight.w700),
    ),
    subtitle: Text(value),
    trailing: const Icon(Icons.chevron_right),
    onTap: () async {
      final uri = title == 'Phone'
          ? Uri(scheme: 'tel', path: value)
          : Uri(scheme: 'mailto', path: value);
      if (!await launchUrl(uri)) _notice('Unable to open $title.');
    },
  );

  Future<void> _openSubmission(bool isCase) async {
    if (!await _requireLogin()) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubmissionScreen(
          caseSubmission: isCase,
          conferenceId: _conference?['id'] as int?,
        ),
      ),
    );
  }

  Future<void> _toggleBookmark(int id) async {
    setState(() {
      if (_bookmarks.contains(id)) {
        _bookmarks.remove(id);
      } else {
        _bookmarks.add(id);
      }
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'event_bookmarks',
      _bookmarks.map((id) => id.toString()).toList(),
    );
  }

  void _showBookmarks() {
    final items = _events
        .where((event) => _bookmarks.contains(event['id']))
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('My Bookmarks')),
          body: items.isEmpty
              ? const Center(child: Text('No saved events yet.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: items.map(_eventCard).toList(),
                ),
        ),
      ),
    );
  }

  void _openMemberSection(String section) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => MemberCenterScreen(section: section)),
  );

  void _openNotices() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const NoticeScreen()),
  );

  Future<void> _openNotifications() async {
    if (await _requireLogin()) _openMemberSection('Notifications');
  }

  void _showTextPage(String title, String content) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _navy,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              content,
              style: const TextStyle(color: _muted, fontSize: 16, height: 1.65),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => SharePlus.instance.share(
                ShareParams(text: '$title\n\n$content'),
              ),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share'),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _title(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: _navy,
          fontSize: 27,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: _muted)),
    ],
  );
  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.all(40),
    child: Center(
      child: Text(text, style: const TextStyle(color: _muted)),
    ),
  );
  BoxDecoration _card() => BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE7E9EF)),
    boxShadow: const [
      BoxShadow(color: Color(0x0A0B1739), blurRadius: 12, offset: Offset(0, 4)),
    ],
  );
  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _SlideVideo extends StatefulWidget {
  final String url;
  final bool isActive;
  final VoidCallback onFinished;

  const _SlideVideo({
    super.key,
    required this.url,
    required this.isActive,
    required this.onFinished,
  });

  @override
  State<_SlideVideo> createState() => _SlideVideoState();
}

class _SlideVideoState extends State<_SlideVideo>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _finishedNotified = false;
  bool _initialising = true;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    try {
      final cached = await DefaultCacheManager().getFileFromCache(widget.url);
      final controller = cached?.file.existsSync() == true
          ? VideoPlayerController.file(cached!.file)
          : VideoPlayerController.networkUrl(
              Uri.parse(widget.url),
              videoPlayerOptions: VideoPlayerOptions(
                mixWithOthers: true,
                allowBackgroundPlayback: false,
              ),
            );
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller..addListener(_listen);
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      if (widget.isActive) await controller.play();
      if (cached == null) {
        // Playback starts from the progressive network stream immediately. The
        // same asset is also persisted for future visits without blocking UI.
        unawaited(_cacheForNextPlayback(widget.url));
      }
    } catch (error) {
      _error = error;
    } finally {
      _initialising = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _cacheForNextPlayback(String url) async {
    try {
      await DefaultCacheManager().downloadFile(url);
    } catch (_) {
      // Streaming remains available even when persistent caching fails.
    }
  }

  void _listen() {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _finishedNotified) {
      return;
    }
    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 250)) {
      _finishedNotified = true;
      widget.onFinished();
    }
  }

  @override
  void didUpdateWidget(covariant _SlideVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      final oldController = _controller;
      oldController?.removeListener(_listen);
      if (oldController != null) unawaited(oldController.dispose());
      _controller = null;
      _finishedNotified = false;
      _initialising = true;
      _error = null;
      _initialise();
      return;
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.isActive && !oldWidget.isActive) {
      _finishedNotified = false;
      // Resume the existing position when returning to this slide. It only
      // restarts after the video naturally completed.
      if (controller.value.position >=
          controller.value.duration - const Duration(milliseconds: 250)) {
        controller.seekTo(Duration.zero);
      }
      controller.play();
    } else if (!widget.isActive && oldWidget.isActive) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    controller?.removeListener(_listen);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = _controller;
    if (_error != null) {
      return const ColoredBox(color: Color(0xFF06265D));
    }
    if (_initialising ||
        controller == null ||
        !controller.value.isInitialized) {
      return const ColoredBox(
        color: Color(0xFF06265D),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}
