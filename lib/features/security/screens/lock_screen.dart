import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wanzo/constants/constants.dart';
import '../services/local_security_service.dart';

/// Écran de verrouillage avec saisie du code PIN
class LockScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;
  final bool showBackButton;

  const LockScreen({
    super.key,
    this.onUnlocked,
    this.showBackButton = false,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with TickerProviderStateMixin {
  final List<String> _enteredPin = [];
  bool _isVerifying = false;
  String _errorMessage = '';
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animation de tremblement pour les erreurs
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    
    // Animation de fondu
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: PopScope(
        canPop: widget.showBackButton,
        child: Scaffold(
        backgroundColor: WanzoColors.primary,
        appBar: widget.showBackButton 
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
            )
          : null,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(WanzoSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // Logo et titre
                  _buildHeader(),
                  
                  const SizedBox(height: WanzoSpacing.xxl),
                  
                  // Indicateurs de PIN
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: _buildPinIndicators(),
                      );
                    },
                  ),
                  
                  const SizedBox(height: WanzoSpacing.lg),
                  
                  // Message d'erreur
                  if (_errorMessage.isNotEmpty)
                    _buildErrorMessage(),
                  
                  const SizedBox(height: WanzoSpacing.xl),
                  
                  // Clavier numérique
                  _buildNumericKeyboard(),
                  
                  const Spacer(),
                  
                  // Informations supplémentaires
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(40),
          ),
          child: const Icon(
            Icons.lock_outline,
            size: 40,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: WanzoSpacing.lg),
        
        // Titre
        const Text(
          'Application verrouillée',
          style: TextStyle(
            fontSize: WanzoTypography.fontSizeXl,
            fontWeight: WanzoTypography.fontWeightBold,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: WanzoSpacing.sm),
        
        // Sous-titre
        Text(
          'Saisissez votre code PIN',
          style: TextStyle(
            fontSize: WanzoTypography.fontSizeMd,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildPinIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final bool isFilled = index < _enteredPin.length;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: WanzoSpacing.sm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? Colors.white : Colors.transparent,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: WanzoSpacing.md,
        vertical: WanzoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(WanzoBorderRadius.sm),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Text(
        _errorMessage,
        style: const TextStyle(
          color: Colors.white,
          fontSize: WanzoTypography.fontSizeSm,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildNumericKeyboard() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 1.2,
      mainAxisSpacing: WanzoSpacing.md,
      crossAxisSpacing: WanzoSpacing.md,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Touches 1-9
        ...List.generate(9, (index) {
          final number = index + 1;
          return _buildKeyboardButton(
            text: number.toString(),
            onPressed: () => _onNumberPressed(number.toString()),
          );
        }),
        
        // Touche vide
        const SizedBox(),
        
        // Touche 0
        _buildKeyboardButton(
          text: '0',
          onPressed: () => _onNumberPressed('0'),
        ),
        
        // Touche effacer
        _buildKeyboardButton(
          icon: Icons.backspace_outlined,
          onPressed: _onDeletePressed,
        ),
      ],
    );
  }

  Widget _buildKeyboardButton({
    String? text,
    IconData? icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(WanzoBorderRadius.lg),
      child: InkWell(
        onTap: _isVerifying ? null : onPressed,
        borderRadius: BorderRadius.circular(WanzoBorderRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WanzoBorderRadius.lg),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: icon != null
              ? Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                )
              : Text(
                  text ?? '',
                  style: const TextStyle(
                    fontSize: WanzoTypography.fontSizeXl,
                    fontWeight: WanzoTypography.fontWeightMedium,
                    color: Colors.white,
                  ),
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        if (_isVerifying)
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: WanzoSpacing.sm),
              Text(
                'Vérification...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: WanzoTypography.fontSizeSm,
                ),
              ),
            ],
          ),
        
        const SizedBox(height: WanzoSpacing.lg),
        
        Text(
          'PIN par défaut : 1234',
          style: TextStyle(
            fontSize: WanzoTypography.fontSizeXs,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  void _onNumberPressed(String number) {
    if (_enteredPin.length < 4 && !_isVerifying) {
      setState(() {
        _enteredPin.add(number);
        _errorMessage = '';
      });
      
      // Feedback haptique
      HapticFeedback.lightImpact();
      
      // Vérifier le PIN quand 4 chiffres sont entrés
      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty && !_isVerifying) {
      setState(() {
        _enteredPin.removeLast();
        _errorMessage = '';
      });
      
      // Feedback haptique
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _verifyPin() async {
    setState(() {
      _isVerifying = true;
    });
    
    try {
      final pin = _enteredPin.join();
      final isValid = await LocalSecurityService.instance.verifyPin(pin);
      
      if (isValid) {
        // Feedback de succès
        HapticFeedback.heavyImpact();
        
        // Callback de déverrouillage
        widget.onUnlocked?.call();
        
        // Fermer l'écran si c'est un overlay
        if (mounted && widget.showBackButton) {
          Navigator.of(context).pop();
        }
      } else {
        // PIN incorrect
        setState(() {
          _errorMessage = 'Code PIN incorrect';
          _enteredPin.clear();
        });
        
        // Animation de tremblement
        _shakeController.forward().then((_) {
          _shakeController.reset();
        });
        
        // Feedback d'erreur
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de vérification';
        _enteredPin.clear();
      });
      
      debugPrint('LockScreen: Error verifying PIN: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }
}
