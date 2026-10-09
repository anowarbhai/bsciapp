import 'package:bsciapp/api/api_service.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MemberCenterScreen extends StatefulWidget {
  final String section;
  const MemberCenterScreen({super.key, required this.section});
  @override
  State<MemberCenterScreen> createState() => _MemberCenterScreenState();
}

class _MemberCenterScreenState extends State<MemberCenterScreen> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = ApiService().getMemberOverview();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.section)),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final result = snapshot.data!;
        if (result['status'] != 'success') {
          return _state(
            result['message']?.toString() ?? 'Unable to load data.',
          );
        }
        final data = result['data'] is Map
            ? (result['data'] as Map).cast<String, dynamic>()
            : result;
        final items = switch (widget.section) {
          'My Registrations' => (data['registrations'] as List? ?? []),
          'Notifications' => (data['notifications'] as List? ?? []),
          _ => [
            ...(data['abstracts'] as List? ?? []),
            ...(data['cases'] as List? ?? []),
          ],
        };
        if (items.isEmpty) return _state('Nothing to show yet.');
        return RefreshIndicator(
          onRefresh: () async =>
              setState(() => _future = ApiService().getMemberOverview()),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = (items[i] as Map).cast<String, dynamic>();
              final event = item['event'] is Map ? item['event'] as Map : null;
              final title = event?['title'] ?? item['title'] ?? 'BSCI update';
              final subtitle =
                  item['message'] ?? event?['date'] ?? item['status'] ?? '';
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFE8EA),
                    child: Icon(
                      Icons.description_outlined,
                      color: Color(0xFFD20A17),
                    ),
                  ),
                  title: Text(
                    title.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(subtitle.toString()),
                  trailing:
                      widget.section == 'My Registrations' &&
                          item['registration_code'] != null
                      ? IconButton(
                          tooltip: 'Show ticket QR',
                          icon: const Icon(Icons.qr_code_2),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Event Ticket'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  QrImageView(
                                    data:
                                        'BSCI-EVENT-TICKET:${item['registration_code']}',
                                    size: 220,
                                  ),
                                  const SizedBox(height: 10),
                                  SelectableText(
                                    item['registration_code'].toString(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        );
      },
    ),
  );

  Widget _state(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
