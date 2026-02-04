import 'package:flutter/material.dart';
import '../services/local_security_service.dart';

/// Widget d'indicateur de sécurité locale
class SecurityIndicator extends StatefulWidget {
  final bool showTimeRemaining;

  const SecurityIndicator({
    super.key,
    this.showTimeRemaining = false,
  });

  @override
  State<SecurityIndicator> createState() => _SecurityIndicatorState();
}

class _SecurityIndicatorState extends State<SecurityIndicator> {
  final LocalSecurityService _securityService = LocalSecurityService.instance;
  
  @override
  void initState() {
    super.initState();
    _securityService.pinEnabledNotifier.addListener(_onStateChanged);
    _securityService.lockStateNotifier.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _securityService.pinEnabledNotifier.removeListener(_onStateChanged);
    _securityService.lockStateNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_securityService.isPinEnabled) {
      return const SizedBox.shrink();
    }

    final isLocked = _securityService.isLocked;
    final isNearAutoLock = _securityService.isNearAutoLock;
    final timeRemaining = _securityService.timeUntilLock;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLocked 
            ? Colors.red.withOpacity(0.1)
            : isNearAutoLock 
                ? Colors.orange.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLocked ? Icons.lock : Icons.security,
            size: 16,
            color: isLocked 
                ? Colors.red
                : isNearAutoLock 
                    ? Colors.orange
                    : Colors.green,
          ),
          const SizedBox(width: 4),
          if (widget.showTimeRemaining && timeRemaining != null && !isLocked)
            Text(
              '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: isNearAutoLock ? Colors.orange : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              isLocked ? 'Verrouillé' : 'Sécurisé',
              style: TextStyle(
                fontSize: 12,
                color: isLocked 
                    ? Colors.red
                    : isNearAutoLock 
                        ? Colors.orange
                        : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
