import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:wanzo/core/utils/adaptive_pull_up.dart';

import '../services/service_api_service.dart';

/// Lien public du catalogue (vitrine) : QR à afficher ou imprimer, lien à
/// copier ou partager. Seuls les produits et services marqués « visible sur le
/// catalogue public » y apparaissent. L'URL signée vient du backend.
/// Pull-up sur mobile, boîte de dialogue sur écran large.
Future<void> showPublicCatalogSheet(BuildContext context) {
  return showAdaptivePullUp<void>(
    context,
    title: 'Catalogue public',
    icon: Icons.storefront_outlined,
    maxWidth: 420,
    builder: (_) => const _PublicCatalogBody(),
  );
}

class _PublicCatalogBody extends StatefulWidget {
  const _PublicCatalogBody();

  @override
  State<_PublicCatalogBody> createState() => _PublicCatalogBodyState();
}

class _PublicCatalogBodyState extends State<_PublicCatalogBody> {
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
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
      );
    }
    if (_url == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final url = _url!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
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
            child: QrImageView(data: url, version: QrVersions.auto, size: 220, gapless: false),
          ),
          const SizedBox(height: 12),
          SelectableText(
            url,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            'Cochez « Visible sur le catalogue public » sur un produit ou un service pour l\'y faire apparaître.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié')));
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copier'),
              ),
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ouvrir'),
              ),
              FilledButton.icon(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: 'Découvrez notre catalogue : $url', subject: 'Catalogue'),
                ),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Partager'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
