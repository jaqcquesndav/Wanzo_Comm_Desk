import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:wanzo/features/settings/repositories/settings_repository.dart';

import '../services/restaurant_api_service.dart';

/// Partage PUBLIC de la CARTE (menu) par lien.
///
/// Le lien public de la carte est SIGNÉ HMAC côté serveur (companyId + tableId)
/// et n'existe qu'attaché à une table (page publique menu + commande en ligne).
/// On RÉUTILISE donc le lien signé de la première table plutôt que de fabriquer
/// une signature côté client. Sans aucune table, le serveur ne peut pas produire
/// de lien signé : on invite alors l'utilisateur à créer une table.
///
/// Le partage réutilise le même mécanisme que les pièces commerciales :
/// WhatsApp via un lien profond `wa.me` (comme `messaging_launcher`), partage
/// système via `share_plus`, et copie du lien dans le presse-papiers.
Future<void> shareRestaurantMenu(
  BuildContext context,
  RestaurantApiService api,
) async {
  final messenger = ScaffoldMessenger.of(context);

  // 1) Trouver une table pour réutiliser son lien public signé.
  List<RestaurantTable> tables;
  try {
    tables = await api.getTables();
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Lien indisponible. Vérifiez votre connexion.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  if (tables.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Créez d\'abord une table : le lien public de la carte est '
          'généré par le serveur pour une table.',
        ),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // 2) Récupérer le lien signé (URL publique) de cette table.
  String url;
  try {
    final link = await api.getTableLink(tables.first.id);
    url = link.url;
  } catch (_) {
    url = '';
  }
  if (url.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Lien indisponible. Vérifiez votre connexion.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // 3) Nom du restaurant (best-effort) pour un message plus clair.
  String name = '';
  try {
    name = (await SettingsRepository().getSettings()).companyName;
  } catch (_) {
    // Réglages indisponibles : message générique sans nom.
  }
  if (!context.mounted) return;

  final message = name.isNotEmpty
      ? 'Découvrez la carte de $name et commandez en ligne : $url'
      : 'Découvrez notre carte et commandez en ligne : $url';

  await _showShareSheet(context, url: url, message: message);
}

/// Feuille d'options de partage de la carte (WhatsApp / partage systeme / copie).
Future<void> _showShareSheet(
  BuildContext context, {
  required String url,
  required String message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (bc) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.restaurant_menu),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Partager la carte',
                    style: Theme.of(bc)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chat, color: Colors.green),
            title: const Text('Envoyer par WhatsApp'),
            subtitle: const Text('Ouvre WhatsApp avec le lien de la carte'),
            onTap: () async {
              Navigator.pop(bc);
              await _launchWhatsApp(context, message);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.orange),
            title: const Text('Partager le lien'),
            onTap: () {
              Navigator.pop(bc);
              SharePlus.instance.share(
                ShareParams(text: message, subject: 'Notre carte'),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copier le lien'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(bc);
              await Clipboard.setData(ClipboardData(text: url));
              messenger.showSnackBar(
                const SnackBar(content: Text('Lien copié')),
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// Ouvre WhatsApp avec un message pre-rempli (meme motif que `messaging_launcher`
/// : lien profond `wa.me/?text=...`), avec un retour visuel en cas d'echec.
Future<void> _launchWhatsApp(BuildContext context, String message) async {
  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
  bool ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossible d\'ouvrir WhatsApp sur cet appareil.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
