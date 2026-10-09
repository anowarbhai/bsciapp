import 'package:flutter/material.dart';

const _red = Color(0xFFD20A17);
const _navy = Color(0xFF062B68);
const _ink = Color(0xFF0B1739);
const _muted = Color(0xFF667085);

class FacultyDetailScreen extends StatelessWidget {
  final Map<String, dynamic> faculty;
  final String webBase;

  const FacultyDetailScreen({
    super.key,
    required this.faculty,
    required this.webBase,
  });

  String? get _photo {
    final path = faculty['photo_path']?.toString();
    if (path == null || path.isEmpty) return null;
    return path.startsWith('http')
        ? path
        : '$webBase/${path.replaceFirst(RegExp(r'^/+'), '')}';
  }

  @override
  Widget build(BuildContext context) {
    final name = faculty['name']?.toString() ?? 'Faculty Member';
    final role = faculty['role']?.toString() ?? 'Interventional Cardiologist';
    final institution = faculty['institution']?.toString() ?? 'Bangladesh';
    final expertise = faculty['expertise'] is List
        ? List<String>.from(faculty['expertise'])
        : <String>[];
    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      '$webBase/assets/slider_conference.jpg',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      errorBuilder: (_, _, _) => const ColoredBox(color: _navy),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xF5062B68),
                            Color(0xE807367E),
                            Color(0xD9062457),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: -34,
                    top: 145,
                    child: Icon(
                      Icons.favorite_border_rounded,
                      size: 210,
                      color: Color(0x183DA3FF),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 14,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 10,
                    right: 14,
                    child: Icon(
                      Icons.share_outlined,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 156,
                          height: 156,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4FB5FF),
                              width: 2,
                            ),
                            color: Colors.white,
                          ),
                          child: ClipOval(
                            child: _photo == null
                                ? const Icon(
                                    Icons.person,
                                    size: 95,
                                    color: Color(0xFF98A2B3),
                                  )
                                : Image.network(
                                    _photo!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.person,
                                      size: 95,
                                      color: Color(0xFF98A2B3),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          faculty['credentials']?.toString().isNotEmpty == true
                              ? '${faculty['credentials']}'
                              : role,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.public, color: Colors.white),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                faculty['country']?.toString().isNotEmpty ==
                                        true
                                    ? '${faculty['country']}'
                                    : institution,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: ListView(
                  children: [
                    _heading('About'),
                    Text(
                      '${faculty['bio'] ?? '$name is a distinguished cardiovascular specialist contributing to clinical practice, education and research.'}',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const Divider(height: 34),
                    _heading('Areas of Expertise'),
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children:
                          (expertise.isNotEmpty
                                  ? expertise
                                  : [
                                      'Coronary Intervention',
                                      'IVUS',
                                      'CTO',
                                      'Structural Heart',
                                      'Physiology',
                                    ])
                              .map(
                                (item) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFC9D8F7),
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      color: Color(0xFF0645AD),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    const Divider(height: 34),
                    _heading('Sessions'),
                    _session(
                      Icons.mic_none_rounded,
                      'Keynote Lecture',
                      'Scientific programme',
                    ),
                    _session(
                      Icons.videocam_outlined,
                      'Live Case Session',
                      'Session details coming soon',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: _navy,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 86,
          height: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_red, _red, Color(0xFF164AA5)]),
          ),
        ),
      ],
    ),
  );
  Widget _session(IconData icon, String title, String subtitle) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE4E7EC)),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: const Color(0xFFEAF2FF),
          child: Icon(icon, color: const Color(0xFF0645AD)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(subtitle, style: const TextStyle(color: _muted)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right),
      ],
    ),
  );
}
