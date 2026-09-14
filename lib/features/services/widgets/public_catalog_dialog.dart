import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/service_api_service.dart';

/// Lien public du catalogue (vitrine) : QR à afficher ou imprimer, lien à
/// copier ou partager. Seuls les produits et services marqués « visible sur le
/// catalogue public » y apparaissent. L'URL signée vient du backend.
Future<void> showPublicCatalogDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _PublicCatalogDialog(),
  );
}

class _PublicCatalogDialog extends StatefulWidget {
  const _PublicCatalogDialog();

  @override
  State<_PublicCatalogDialog> createState() => _PublicCatalogDialogState();
}

class _PublicCatalogDialogState extends State<_PublicCatalogDialog> {
  String? _url;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await ServiceApiService().getPublicCatalogLink();
      if (mounted) setState(() => _url = url);
    } catch (e) {
      if (mounted) setState(() => _error = 'Lien indisponible : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.storefront_outlined),
          SizedBox(width: 8),
          Expanded(child: Text('Catalogue public')),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: _error != null
            ? Text(_error!, style: TextStyle(color: theme.colorScheme.error))
            : _url == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Vos clients scannent ce code ou ouvrent le lien pour voir vos produits et services publics.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(data: _url!, version: QrVersions.auto, size: 220, gapless: false),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        _url!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cochez « Visible sur le catalogue public » sur un produit ou un service pour l\'y faire apparaître.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
      ),
      actions: [
        if (_url != null) ...[
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _url!));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié')));
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copier'),
          ),
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse(_url!), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Ouvrir'),
          ),
          FilledButton.icon(
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: 'Découvrez notre catalogue : $_url', subject: 'Catalogue'),
            ),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Partager'),
          ),
        ] else
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
      ],
    );
  }
}
