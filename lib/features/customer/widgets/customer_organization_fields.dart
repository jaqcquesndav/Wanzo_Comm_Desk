import 'package:flutter/material.dart';

import '../models/customer_contact.dart';
import '../models/customer_type.dart';

/// Champs « personne morale » du formulaire client : nature juridique,
/// NIF / RCCM et personnes de contact. Partagé par les trois formulaires
/// (page mobile, page desktop, modal desktop) pour rester cohérent.
class CustomerOrganizationFields extends StatefulWidget {
  final CustomerType type;
  final ValueChanged<CustomerType> onTypeChanged;
  final TextEditingController taxIdController;
  final List<CustomerContact> contacts;
  final ValueChanged<List<CustomerContact>> onContactsChanged;

  const CustomerOrganizationFields({
    super.key,
    required this.type,
    required this.onTypeChanged,
    required this.taxIdController,
    required this.contacts,
    required this.onContactsChanged,
  });

  @override
  State<CustomerOrganizationFields> createState() => _CustomerOrganizationFieldsState();
}

class _CustomerOrganizationFieldsState extends State<CustomerOrganizationFields> {
  // Clés stables par ligne : la suppression d'un contact ne décale pas les
  // valeurs saisies dans les lignes suivantes.
  late List<_ContactRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.contacts.map((c) => _ContactRow(c)).toList();
  }

  void _emit() => widget.onContactsChanged(
        _rows.map((r) => r.contact).where((c) => !c.isEmpty).toList(),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<CustomerType>(
          value: widget.type,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Nature du client',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          items: [
            for (final t in CustomerType.values)
              DropdownMenuItem(
                value: t,
                child: Row(
                  children: [
                    Icon(t.icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t.label, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) widget.onTypeChanged(v);
          },
        ),
        if (widget.type.isOrganization) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: widget.taxIdController,
            decoration: const InputDecoration(
              labelText: 'NIF / RCCM',
              hintText: 'Identifiant fiscal ou registre de commerce',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.contacts_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Personnes de contact',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _rows.add(_ContactRow(const CustomerContact(name: '')))),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Le gérant, le comptable ou le responsable des achats à joindre pour cette organisation.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          for (var i = 0; i < _rows.length; i++)
            Padding(
              key: _rows[i].key,
              padding: const EdgeInsets.only(top: 8),
              child: _ContactCard(
                contact: _rows[i].contact,
                onChanged: (c) {
                  _rows[i].contact = c;
                  _emit();
                },
                onRemove: () {
                  setState(() => _rows.removeAt(i));
                  _emit();
                },
              ),
            ),
        ],
      ],
    );
  }
}

class _ContactRow {
  final Key key = UniqueKey();
  CustomerContact contact;
  _ContactRow(this.contact);
}

class _ContactCard extends StatelessWidget {
  final CustomerContact contact;
  final ValueChanged<CustomerContact> onChanged;
  final VoidCallback onRemove;

  const _ContactCard({required this.contact, required this.onChanged, required this.onRemove});

  static const _roles = [
    'Gérant', 'Directeur général', 'Comptable', 'Responsable achats', 'Logisticien',
    'Chauffeur', 'Secrétaire', 'Représentant', 'Trésorier', 'Président',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: contact.name,
                    decoration: const InputDecoration(labelText: 'Nom *', isDense: true),
                    onChanged: (v) => onChanged(contact.copyWith(name: v)),
                  ),
                ),
                IconButton(
                  tooltip: 'Retirer',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: contact.role ?? ''),
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                return q.isEmpty ? _roles : _roles.where((r) => r.toLowerCase().contains(q));
              },
              onSelected: (v) => onChanged(contact.copyWith(role: v)),
              fieldViewBuilder: (context, ctrl, focus, _) => TextFormField(
                controller: ctrl,
                focusNode: focus,
                decoration: const InputDecoration(labelText: 'Fonction', isDense: true),
                onChanged: (v) => onChanged(contact.copyWith(role: v)),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: contact.phone ?? '',
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone', isDense: true),
                    onChanged: (v) => onChanged(contact.copyWith(phone: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: contact.email ?? '',
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', isDense: true),
                    onChanged: (v) => onChanged(contact.copyWith(email: v)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
