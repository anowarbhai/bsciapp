import 'package:bsciapp/api/api_service.dart';
import 'package:flutter/material.dart';

class PastCommitteesScreen extends StatelessWidget {
  const PastCommitteesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Past Committees')),
    body: FutureBuilder<List<dynamic>>(
      future: ApiService().getPastCommittees(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = snapshot.data!;
        if (sessions.isEmpty) {
          return const Center(
            child: Text('No past committee sessions published yet.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (_, index) {
            final session = (sessions[index] as Map).cast<String, dynamic>();
            final members = (session['members'] as List?) ?? const [];
            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: ExpansionTile(
                initiallyExpanded: index == 0,
                title: Text(
                  'BSCI Executive Committee (${session['name'] ?? ''})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${members.length} members'),
                children: members.map((raw) {
                  final member = (raw as Map).cast<String, dynamic>();
                  final photo = member['photo_url']?.toString();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: photo != null
                          ? NetworkImage(photo)
                          : null,
                      child: photo == null
                          ? const Icon(Icons.person_outline)
                          : null,
                    ),
                    title: Text(member['name']?.toString() ?? ''),
                    subtitle: Text(member['role']?.toString() ?? ''),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    ),
  );
}
