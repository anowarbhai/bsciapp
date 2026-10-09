import 'package:flutter/material.dart';

const _red = Color(0xFFD20A17);
const _navy = Color(0xFF0B1739);
const _muted = Color(0xFF667085);

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    required this.memberLoggedIn,
    required this.initiallyRegistered,
    required this.onRegister,
    required this.onGuestRegister,
    required this.onPayment,
  });
  final Map<String, dynamic> event;
  final bool memberLoggedIn;
  final bool initiallyRegistered;
  final Future<Map<String, dynamic>> Function(String? discountCode) onRegister;
  final Future<Map<String, dynamic>> Function(Map<String, String>)
  onGuestRegister;
  final Future<Map<String, dynamic>> Function(Map<String, String>) onPayment;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late bool _registered = widget.initiallyRegistered;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isFull = event['is_full'] == true;
    final completed = event['status'] == 'completed';
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: const Text('Event Details')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_navy, Color(0xFF18346C)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260B1739),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event['type'] ?? 'Event'}'.toUpperCase(),
                  style: const TextStyle(
                    color: _red,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  event['title']?.toString() ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                _info(Icons.calendar_month, event['date']),
                _info(Icons.schedule, event['time']),
                _info(Icons.location_on_outlined, event['location']),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _heroBadge('${event['cme_points'] ?? 0} CME points'),
                    _heroBadge(
                      event['is_paid'] == true
                          ? 'Paid event'
                          : 'Free registration',
                    ),
                    _heroBadge(
                      '${event['remaining_spots'] ?? 'Open'} seats left',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            'About this event',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (event['description']?.toString().trim().isNotEmpty ?? false)
                      ? event['description'].toString()
                      : 'Join leading interventional cardiologists for an evidence-led scientific programme combining expert discussion, practical insight and case-based learning.',
                  style: const TextStyle(color: _navy, fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Percutaneous Coronary Intervention (PCI) has evolved rapidly into high-precision endovascular care. This masterclass bridges diagnostic ambiguity with cutting-edge tools including Intravascular Ultrasound (IVUS), Optical Coherence Tomography (OCT), and Fractional Flow Reserve (FFR/iFR) to maximize vessel patency and patient safety.',
                  style: TextStyle(color: _muted, height: 1.6),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Through didactic lectures, live transmission reviews, and hands-on complication drill breakouts, attendees will gain actionable knowledge directly applicable in the catheterization laboratory.',
                  style: TextStyle(color: _muted, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            'Programme highlights',
            const Column(
              children: [
                _FeatureRow(
                  icon: Icons.medical_services_outlined,
                  title: 'Expert-led learning',
                  description:
                      'Focused sessions facilitated by veteran national & international cardiovascular specialists.',
                ),
                _FeatureRow(
                  icon: Icons.biotech_outlined,
                  title: 'Imaging & Physiology Focus',
                  description:
                      'Hands-on algorithms for MLD MAX, IVUS/OCT interpretation, and hyperemic FFR evaluation.',
                ),
                _FeatureRow(
                  icon: Icons.forum_outlined,
                  title: 'Case-based discussion',
                  description:
                      'Interactive complication reviews, DK-Crush bifurcation stenting, and audience Q&A.',
                ),
                _FeatureRow(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Accredited CME education',
                  description:
                      'BM&DC recognized Category-1 Continuing Medical Education with verifiable digital certificates.',
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            'Key Clinical Competencies',
            const Column(
              children: [
                _CheckPoint(
                  'High-resolution IVUS & OCT plaque morphology & calcification assessment.',
                ),
                _CheckPoint(
                  'Physiological adjudication of intermediate stenosis via FFR, iFR, and RFR.',
                ),
                _CheckPoint(
                  'Precision stent sizing, preventing edge dissections & under-expansion.',
                ),
                _CheckPoint(
                  'Complex bifurcation techniques: DK-Crush, Culotte, and POT optimization.',
                ),
                _CheckPoint(
                  'Algorithmic bailout protocols for coronary perforation & no-reflow.',
                ),
                _CheckPoint(
                  'ALARA radiation safety protocols & contrast reduction in high-risk PCI.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            'Scientific Agenda & Schedule',
            const Column(
              children: [
                _AgendaRow(
                  time: '08:30 – 09:00',
                  title: 'Fellowship Breakfast & Registration',
                  subtitle: 'Delegate kit distribution and morning check-in',
                ),
                _AgendaRow(
                  time: '09:00 – 09:30',
                  title: 'Inaugural Address & Presidential Remarks',
                  subtitle: 'Opening remarks by BSCI leadership & course directors',
                ),
                _AgendaRow(
                  time: '09:30 – 11:00',
                  title: 'Session 1: Intracoronary Imaging (IVUS vs OCT)',
                  subtitle: 'Plaque characterization, MLD MAX criteria & lumen profiling',
                ),
                _AgendaRow(
                  time: '11:00 – 11:30',
                  title: 'Scientific Coffee & Technical Exhibition',
                  subtitle: 'Device showcase and peer networking in gallery',
                ),
                _AgendaRow(
                  time: '11:30 – 01:00',
                  title: 'Session 2: Coronary Physiology & Microvascular CAD',
                  subtitle: 'FFR/iFR adjudication and deferral criteria in multi-vessel CAD',
                ),
                _AgendaRow(
                  time: '01:00 – 02:00',
                  title: 'Fellowship Luncheon & Networking',
                  subtitle: 'Executive fellowship networking lunch',
                ),
                _AgendaRow(
                  time: '02:00 – 03:30',
                  title: 'Session 3: Live Case Reviews & Bifurcations',
                  subtitle: 'DK-Crush step-by-step review and complication bailout',
                ),
                _AgendaRow(
                  time: '03:30 – 04:30',
                  title: 'Hands-on Cath Lab Simulators & Stations',
                  subtitle: 'Small-group interactive drills with expert proctors',
                ),
                _AgendaRow(
                  time: '04:30 – 05:00',
                  title: 'Interactive Case Forum & Valedictory',
                  subtitle: 'Fellows clinical case review, Q&A, and CME certification',
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            'Distinguished Faculty',
            Column(
              children: [
                _FeatureRow(
                  icon: Icons.person_outline,
                  title: 'Prof. Dr. M. G. Azam',
                  description: 'President, BSCI · Professor of Cardiology, NICVD Dhaka',
                ),
                _FeatureRow(
                  icon: Icons.person_outline,
                  title: 'Prof. Dr. A. K. M. Monwarul Islam',
                  description: 'Secretary General, BSCI · Senior Interventional Cardiologist',
                ),
                _FeatureRow(
                  icon: Icons.person_outline,
                  title: 'Prof. Dr. Afzalur Rahman',
                  description: 'Course Director · Chief Cardiologist, Imperial Hospital',
                ),
                _FeatureRow(
                  icon: Icons.person_outline,
                  title: 'Dr. Mashhudul Hasan',
                  description: 'Associate Professor, Interventional Cardiology, BSMMU',
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            'Registration',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event['registrations_count'] ?? 0} registered · ${event['remaining_spots'] ?? 'Open'} seats left',
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${event['cme_points'] ?? 0} CME points',
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _registered || isFull || completed || _submitting
                        ? null
                        : _register,
                    style: FilledButton.styleFrom(
                      backgroundColor: _red,
                      padding: const EdgeInsets.all(15),
                    ),
                    child: Text(
                      _submitting
                          ? 'Registering...'
                          : _registered
                          ? 'Already Registered'
                          : completed
                          ? 'Event Completed'
                          : isFull
                          ? 'Event Full'
                          : widget.memberLoggedIn
                          ? 'Register for Event'
                          : 'Member Login & Register',
                    ),
                  ),
                ),
                if (!widget.memberLoggedIn &&
                    !_registered &&
                    !isFull &&
                    !completed) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'OR',
                            style: TextStyle(color: _muted, fontSize: 11),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _guestForm,
                      child: const Text('Continue as Non-member'),
                    ),
                  ),
                ],
                if (widget.memberLoggedIn &&
                    _registered &&
                    event['is_paid'] == true) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _paymentForm,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Submit Payment Reference'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, color: Colors.white70, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value?.toString() ?? 'TBA',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  Widget _heroBadge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: .14)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _card(String title, Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Future<void> _register() async {
    String? discountCode;
    if (widget.event['is_paid'] == true) {
      final controller = TextEditingController();
      discountCode = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Paid Event Registration'),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Discount code (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (discountCode == null) return;
    }
    setState(() => _submitting = true);
    final result = await widget.onRegister(discountCode);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (result['status'] == 'success') _registered = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ??
              'Registration could not be completed.',
        ),
      ),
    );
  }

  Future<void> _guestForm() async {
    final key = GlobalKey<FormState>();
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final institution = TextEditingController();
    final discount = TextEditingController();
    final fields = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Event Registration'),
        content: SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(name, 'Full name', required: true),
                _field(
                  email,
                  'Email address',
                  required: true,
                  keyboard: TextInputType.emailAddress,
                ),
                _field(
                  phone,
                  'Phone number',
                  required: true,
                  keyboard: TextInputType.phone,
                ),
                _field(institution, 'Institution / organization'),
                if (widget.event['is_paid'] == true)
                  _field(discount, 'Discount code (optional)'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(dialogContext, {
                  'name': name.text.trim(),
                  'email': email.text.trim(),
                  'phone': phone.text.trim(),
                  'institution': institution.text.trim(),
                  'discount_code': discount.text.trim(),
                });
              }
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
    name.dispose();
    email.dispose();
    phone.dispose();
    institution.dispose();
    discount.dispose();
    if (fields == null || !mounted) return;
    setState(() => _submitting = true);
    final result = await widget.onGuestRegister(fields);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (result['status'] == 'success') _registered = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ??
              'Registration could not be completed.',
        ),
      ),
    );
  }

  Future<void> _paymentForm() async {
    final reference = TextEditingController();
    String provider = 'bkash';
    final fields = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Payment Reference'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: provider,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(value: 'bkash', child: Text('bKash')),
                  DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                  DropdownMenuItem(
                    value: 'sslcommerz',
                    child: Text('SSLCommerz'),
                  ),
                  DropdownMenuItem(
                    value: 'manual',
                    child: Text('Other/manual'),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => provider = value ?? provider),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reference,
                decoration: const InputDecoration(
                  labelText: 'Transaction reference',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (reference.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, {
                    'provider': provider,
                    'provider_reference': reference.text.trim(),
                  });
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    reference.dispose();
    if (fields == null || !mounted) return;
    final result = await widget.onPayment(fields);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ?? 'Payment could not be submitted.',
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ''}',
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? '$label is required.'
                : null
          : null,
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool last;
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFECEE),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _red, size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: _muted,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CheckPoint extends StatelessWidget {
  final String text;
  const _CheckPoint(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle, size: 18, color: Color(0xFF16A34A)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _muted, height: 1.45),
          ),
        ),
      ],
    ),
  );
}

class _AgendaRow extends StatelessWidget {
  final String time;
  final String title;
  final String subtitle;
  final bool last;
  const _AgendaRow({
    required this.time,
    required this.title,
    required this.subtitle,
    this.last = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: last ? 0 : 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            time,
            style: const TextStyle(color: _red, fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
