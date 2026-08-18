import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/colors.dart';
import '../services/subscription_status_service.dart';

/// URL de la page abonnements sur Wanzo Land (customer service).
const String wanzoLandSubscriptionUrl = 'https://wanzzo.com/abonnement';

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
  String? _dismissedSignature;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(_refreshInterval, (_) => _refresh());
  }

  @override
  void dispose() {
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
      _banner = result;
      // Un changement de signature réaffiche la bannière rejetée.
      if (result != null && result.signature != _dismissedSignature) {
        _dismissedSignature = null;
      }
    });
  }

  Future<void> _openSubscriptions() async {
    final uri = Uri.parse(wanzoLandSubscriptionUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    final visible = banner != null && banner.signature != _dismissedSignature;

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
