import 'dart:typed_data';

import 'package:bsciapp/api/api_service.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class MembershipCenterScreen extends StatefulWidget {
  const MembershipCenterScreen({super.key});

  @override
  State<MembershipCenterScreen> createState() => _MembershipCenterScreenState();
}

class _MembershipCenterScreenState extends State<MembershipCenterScreen> {
  final _api = ApiService();
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _api.getMemberOverview();
  }

  void _reload() => setState(() => _future = _api.getMemberOverview());
  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _renew() async {
    setState(() => _busy = true);
    final result = await _api.requestMembershipRenewal();
    if (!mounted) return;
    setState(() => _busy = false);
    _notice(result['message']?.toString() ?? 'Renewal request submitted.');
    if (result['status'] == 'success') _reload();
  }

  Future<void> _payment() async {
    String provider = 'bkash';
    final reference = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Renewal Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: provider,
                items: const [
                  DropdownMenuItem(value: 'bkash', child: Text('bKash')),
                  DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                  DropdownMenuItem(value: 'manual', child: Text('Other')),
                ],
                onChanged: (value) => update(() => provider = value ?? 'bkash'),
                decoration: const InputDecoration(labelText: 'Payment method'),
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, reference.text.trim().isNotEmpty),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      reference.dispose();
      return;
    }
    setState(() => _busy = true);
    final result = await _api.submitMembershipPaymentReference(
      provider: provider,
      reference: reference.text.trim(),
    );
    reference.dispose();
    if (!mounted) return;
    setState(() => _busy = false);
    _notice(result['message']?.toString() ?? 'Payment submitted.');
    if (result['status'] == 'success') _reload();
  }

  Future<void> _document(String path, String name) async {
    setState(() => _busy = true);
    final result = await _api.downloadMembershipDocument(path);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result['status'] != 'success') {
      _notice(result['message']?.toString() ?? 'Document unavailable.');
      return;
    }
    final file = XFile.fromData(
      result['bytes'] as Uint8List,
      mimeType: 'application/pdf',
      name: name,
    );
    await SharePlus.instance.share(ShareParams(files: [file]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Membership & Payments')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final result = snapshot.data ?? const <String, dynamic>{};
        if (result['status'] != 'success') {
          return Center(
            child: FilledButton(onPressed: _reload, child: const Text('Retry')),
          );
        }
        final membership =
            (result['membership'] as Map?)?.cast<String, dynamic>() ?? {};
        final payments = result['membership_payments'] as List? ?? const [];
        final lifetime =
            (membership['tier_duration_months'] as num? ?? 0) >= 600;
        final requested = membership['renewal_requested_at'] != null;
        final certificate =
            membership['status'] == 'active' &&
            membership['payment_status'] == 'verified';
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        membership['tier']?.toString() ?? 'BSCI Membership',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 14),
                      _row('Membership status', membership['status']),
                      _row('Payment status', membership['payment_status']),
                      _row(
                        'Valid until',
                        lifetime ? 'Lifetime' : membership['expires_at'],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (!lifetime && !requested)
                            FilledButton.icon(
                              onPressed: _busy ? null : _renew,
                              icon: const Icon(Icons.autorenew),
                              label: const Text('Request Renewal'),
                            ),
                          if (requested &&
                              membership['payment_status'] == 'pending')
                            FilledButton.icon(
                              onPressed: _busy ? null : _payment,
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Submit Payment'),
                            ),
                          if (certificate)
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _document(
                                      '/member/membership/certificate',
                                      'BSCI-membership-certificate.pdf',
                                    ),
                              icon: const Icon(Icons.workspace_premium),
                              label: const Text('Certificate'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Payment History',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (payments.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No membership payments recorded yet.'),
                  ),
                )
              else
                ...payments.map((raw) {
                  final payment = (raw as Map).cast<String, dynamic>();
                  final verified = payment['status'] == 'verified';
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        verified ? Icons.verified : Icons.schedule,
                        color: verified ? Colors.green : Colors.orange,
                      ),
                      title: Text(
                        '${payment['purpose']} • BDT ${payment['amount']}',
                      ),
                      subtitle: Text(
                        '${payment['provider']} • ${payment['provider_reference']}\nStatus: ${payment['status']}',
                      ),
                      isThreeLine: true,
                      trailing: verified
                          ? IconButton(
                              tooltip: 'Download receipt',
                              icon: const Icon(Icons.receipt_long),
                              onPressed: _busy
                                  ? null
                                  : () => _document(
                                      '/member/membership/payments/${payment['id']}/receipt',
                                      'BSCI-membership-receipt-${payment['id']}.pdf',
                                    ),
                            )
                          : null,
                    ),
                  );
                }),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        );
      },
    ),
  );

  Widget _row(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value?.toString() ?? '—',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
