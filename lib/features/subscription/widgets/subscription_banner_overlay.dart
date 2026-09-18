import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/colors.dart';
import '../services/subscription_status_service.dart';
import '../../../core/services/account_block_notifier.dart';

/// URL de la page abonnements sur Wanzo Land (customer service).
const String wanzoLandSubscriptionUrl = 'https://wanzzo.com/abonnement';

/// Dossier du client sur Wanzo Land : le seul endroit qui lui reste ouvert
/// quand son compte est suspendu.
const String wanzoLandProfileUrl = 'https://wanzzo.com/company';

/// Adresse du support utilisee tant que le serveur n'en a pas fourni une :
/// un ecran de compte ferme sans aucune issue serait pire qu'une adresse
/// legerement datee.
const String wanzoSupportEmailFallback = 'ikiota@ikiotahub.com';

/// Enveloppe l'application d'une bannière globale, subtile et non bloquante,
/// informant de l'état de l'abonnement (expiré, période de grâce,
/// rétrogradation, proche de la limite) et redirigeant vers Wanzo Land.
///
/// Montée dans le `builder` de MaterialApp.router pour couvrir tous les écrans.
/// Purement informative : n'empêche jamais l'utilisation de l'app.
class SubscriptionBannerOverlay extends StatefulWidget {
  const SubscriptionBannerOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<SubscriptionBannerOverlay> createState() => _SubscriptionBannerOverlayState();
}

class _SubscriptionBannerOverlayState extends State<SubscriptionBannerOverlay>
    with WidgetsBindingObserver {
  static const Duration _refreshInterval = Duration(minutes: 15);

  final SubscriptionStatusService _service = SubscriptionStatusService();
  SubscriptionBannerState? _banner;
  AccountAccessBlock? _accessBlock;
  String? _dismissedSignature;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(_refreshInterval, (_) => _refresh());
    // Le portail refuse deja les requetes d'un compte ferme : ce signal arrive
    // des le premier appel, bien avant le prochain sondage.
    AccountBlockNotifier.instance.addListener(_surRefusDuPortail);
  }

  /// Un refus du portail vaut verdict : l'ecran de compte ferme prend la main.
  void _surRefusDuPortail() {
    final refus = AccountBlockNotifier.instance.value;
    if (refus == null || !mounted) return;
    setState(() {
      _accessBlock = AccountAccessBlock(
        message: refus.message,
        reason: refus.reason,
        supportEmail: refus.supportEmail,
        supportPhone: refus.supportPhone,
        supportWhatsapp: refus.supportWhatsapp,
      );
    });
  }

  @override
  void dispose() {
    AccountBlockNotifier.instance.removeListener(_surRefusDuPortail);
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final result = await _service.evaluate();
    if (!mounted) return;
    setState(() {
      _accessBlock = result.accessBlock;
      _banner = result.banner;
      // Un changement de signature réaffiche la bannière rejetée.
      final banner = result.banner;
      if (banner != null && banner.signature != _dismissedSignature) {
        _dismissedSignature = null;
      }
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openSubscriptions() => _openUrl(wanzoLandSubscriptionUrl);

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    final visible = banner != null && banner.signature != _dismissedSignature;
    final block = _accessBlock;

    // Compte suspendu : l'application n'est plus utilisable. On remplace tout,
    // plutôt que de superposer un message par-dessus des écrans encore
    // manipulables.
    if (block != null) {
      return Directionality(
        textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        child: _AccountBlockedScreen(
          block: block,
          onOpenProfile: () => _openUrl(wanzoLandProfileUrl),
          onRetry: _refresh,
        ),
      );
    }

    return Directionality(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (visible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _BannerBar(
                state: banner,
                onManage: _openSubscriptions,
                onDismiss: () => setState(() => _dismissedSignature = banner.signature),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerBar extends StatelessWidget {
  const _BannerBar({
    required this.state,
    required this.onManage,
    required this.onDismiss,
  });

  final SubscriptionBannerState state;
  final VoidCallback onManage;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final background = state.severity == SubscriptionBannerSeverity.danger
        ? WanzoColors.danger
        : WanzoColors.warning;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Container(
          color: background,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.message,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onManage,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Gérer',
                  style: TextStyle(fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                ),
              ),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Écran plein présenté quand le compte est suspendu.
///
/// Il dit ce qui se passe, pourquoi si le motif est connu, et où aller :
/// le dossier sur Wanzo Land, ou le support. Pas d'autre issue, c'est le
/// propre d'un compte fermé.
class _AccountBlockedScreen extends StatelessWidget {
  const _AccountBlockedScreen({
    required this.block,
    required this.onOpenProfile,
    required this.onRetry,
  });

  final AccountAccessBlock block;
  final VoidCallback onOpenProfile;
  final VoidCallback onRetry;

  /// Une seule ligne de contact, sobre : l'adresse, et le WhatsApp s'il existe.
  String _supportLine() {
    final email = block.supportEmail ?? wanzoSupportEmailFallback;
    final phone = block.supportWhatsapp ?? block.supportPhone;
    return phone == null ? 'Support : $email' : 'Support : $email  -  $phone';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 56, color: WanzoColors.danger),
                  const SizedBox(height: 16),
                  const Text(
                    'Compte suspendu',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    block.message,
                    style: const TextStyle(fontSize: 14.5, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "L'accès aux applications Wanzo est fermé le temps que la "
                    'situation soit régularisée. Vos données sont conservées.',
                    style: TextStyle(fontSize: 13.5, height: 1.5, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onOpenProfile,
                      child: const Text('Ouvrir mon dossier'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _supportLine(),
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Vérifier à nouveau'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
