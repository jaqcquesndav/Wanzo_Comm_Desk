import 'package:flutter/material.dart';
import '../services/local_security_service.dart';
import '../screens/lock_screen.dart';

/// Widget qui gère l'affichage de l'écran de verrouillage
class SecurityWrapper extends StatefulWidget {
  final Widget child;

  const SecurityWrapper({
    super.key,
    required this.child,
  });

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> with WidgetsBindingObserver {
  final LocalSecurityService _securityService = LocalSecurityService.instance;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Écouter les changements d'état de verrouillage
    _securityService.lockStateNotifier.addListener(_onLockStateChanged);
    
    // Initialiser l'état
    _isLocked = _securityService.isLocked;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _securityService.lockStateNotifier.removeListener(_onLockStateChanged);
    super.dispose();
  }

  void _onLockStateChanged() {
    if (mounted) {
      setState(() {
        _isLocked = _securityService.isLocked;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // Application en premier plan - enregistrer l'activité
        _securityService.recordActivity();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Application en arrière-plan - vérifier l'inactivité
        _securityService.checkInactivity();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Application fermée ou cachée
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked && _securityService.isPinEnabled) {
      return LockScreen(
        onUnlocked: () {
          setState(() {
            _isLocked = false;
          });
        },
      );
    }
    
    return GestureDetector(
      onTap: () => _securityService.recordActivity(),
      onPanDown: (_) => _securityService.recordActivity(),
      child: widget.child,
    );
  }
}
