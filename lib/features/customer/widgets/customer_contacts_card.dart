import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';

/// Carte « Personnes de contact » du détail d'un client personne morale.
/// Ne s'affiche que si le client a des contacts.
class CustomerContactsCard extends StatelessWidget {
  final Customer customer;

  const CustomerContactsCard({super.key, required this.customer});

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _mail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (customer.contacts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(customer.type.icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Personnes de contact',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            for (final c in customer.contacts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [
                    if ((c.role ?? '').isNotEmpty) c.role!,
                    if ((c.phone ?? '').isNotEmpty) c.phone!,
                    if ((c.email ?? '').isNotEmpty) c.email!,
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((c.phone ?? '').isNotEmpty)
                      IconButton(
                        tooltip: 'Appeler',
                        icon: const Icon(Icons.phone, size: 20),
                        onPressed: () => _call(c.phone!),
                      ),
                    if ((c.email ?? '').isNotEmpty)
                      IconButton(
                        tooltip: 'Écrire',
                        icon: const Icon(Icons.email_outlined, size: 20),
                        onPressed: () => _mail(c.email!),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
