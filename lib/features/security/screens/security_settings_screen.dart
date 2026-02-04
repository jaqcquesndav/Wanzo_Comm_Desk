import 'package:flutter/material.dart';
import 'package:wanzo/constants/constants.dart';
import '../services/local_security_service.dart';

/// Écran de configuration de la sécurité locale
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final LocalSecurityService _securityService = LocalSecurityService.instance;

  bool _isPinEnabled = false;
  bool _isLoading = true;

  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _obscureCurrentPin = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isPinEnabled = _securityService.isPinEnabled;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sécurité locale'),
        backgroundColor: WanzoColors.primary,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(WanzoSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPinToggleSection(),

                    if (_isPinEnabled) ...[
                      const SizedBox(height: WanzoSpacing.xl),
                      _buildChangePinSection(),
                    ],

                    const SizedBox(height: WanzoSpacing.xl),
                    _buildInfoSection(),
                  ],
                ),
              ),
    );
  }

  Widget _buildPinToggleSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(WanzoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: WanzoColors.primary, size: 24),
                const SizedBox(width: WanzoSpacing.sm),
                const Expanded(
                  child: Text(
                    'Verrouillage par code PIN',
                    style: TextStyle(
                      fontSize: WanzoTypography.fontSizeLg,
                      fontWeight: WanzoTypography.fontWeightMedium,
                    ),
                  ),
                ),
                Switch(
                  value: _isPinEnabled,
                  onChanged: _onPinToggleChanged,
                  activeColor: WanzoColors.primary,
                ),
              ],
            ),

            const SizedBox(height: WanzoSpacing.sm),

            Text(
              _isPinEnabled
                  ? 'Le verrouillage par code PIN est activé. L\'application se verrouillera automatiquement après 5 minutes d\'inactivité.'
                  : 'Activez le verrouillage par code PIN pour sécuriser l\'accès à l\'application en local.',
              style: TextStyle(
                fontSize: WanzoTypography.fontSizeSm,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePinSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(WanzoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_outlined, color: WanzoColors.primary, size: 24),
                const SizedBox(width: WanzoSpacing.sm),
                const Text(
                  'Modifier le code PIN',
                  style: TextStyle(
                    fontSize: WanzoTypography.fontSizeLg,
                    fontWeight: WanzoTypography.fontWeightMedium,
                  ),
                ),
              ],
            ),

            const SizedBox(height: WanzoSpacing.lg),

            // Code PIN actuel
            TextFormField(
              controller: _currentPinController,
              obscureText: _obscureCurrentPin,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'Code PIN actuel',
                hintText: 'Entrez votre code PIN actuel',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrentPin
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureCurrentPin = !_obscureCurrentPin;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
                ),
                counterText: '',
              ),
            ),

            const SizedBox(height: WanzoSpacing.md),

            // Nouveau code PIN
            TextFormField(
              controller: _newPinController,
              obscureText: _obscureNewPin,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'Nouveau code PIN',
                hintText: 'Entrez un nouveau code PIN (4 chiffres)',
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPin ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNewPin = !_obscureNewPin;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
                ),
                counterText: '',
              ),
            ),

            const SizedBox(height: WanzoSpacing.md),

            // Confirmation du nouveau code PIN
            TextFormField(
              controller: _confirmPinController,
              obscureText: _obscureConfirmPin,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'Confirmer le nouveau code PIN',
                hintText: 'Confirmez votre nouveau code PIN',
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPin
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPin = !_obscureConfirmPin;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
                ),
                counterText: '',
              ),
            ),

            const SizedBox(height: WanzoSpacing.lg),

            // Bouton de modification
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _changePin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WanzoColors.primary,
                  padding: const EdgeInsets.symmetric(
                    vertical: WanzoSpacing.md,
                  ),
                ),
                child: const Text(
                  'Modifier le code PIN',
                  style: TextStyle(
                    fontSize: WanzoTypography.fontSizeMd,
                    fontWeight: WanzoTypography.fontWeightMedium,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(WanzoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: WanzoColors.info, size: 24),
                const SizedBox(width: WanzoSpacing.sm),
                const Text(
                  'Informations importantes',
                  style: TextStyle(
                    fontSize: WanzoTypography.fontSizeLg,
                    fontWeight: WanzoTypography.fontWeightMedium,
                  ),
                ),
              ],
            ),

            const SizedBox(height: WanzoSpacing.md),

            _buildInfoItem(
              icon: Icons.timer,
              title: 'Verrouillage automatique',
              description:
                  'L\'application se verrouille après 5 minutes d\'inactivité.',
            ),

            const SizedBox(height: WanzoSpacing.sm),

            _buildInfoItem(
              icon: Icons.offline_bolt,
              title: 'Sécurité locale',
              description:
                  'Le code PIN fonctionne même sans connexion Internet.',
            ),

            const SizedBox(height: WanzoSpacing.sm),

            _buildInfoItem(
              icon: Icons.vpn_key,
              title: 'Code par défaut',
              description:
                  'Le code PIN par défaut est "1234". Modifiez-le pour plus de sécurité.',
            ),

            const SizedBox(height: WanzoSpacing.sm),

            _buildInfoItem(
              icon: Icons.security,
              title: 'Chiffrement',
              description:
                  'Votre code PIN est stocké de manière sécurisée et chiffrée sur l\'appareil.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: WanzoSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: WanzoTypography.fontSizeSm,
                  fontWeight: WanzoTypography.fontWeightMedium,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: WanzoTypography.fontSizeXs,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onPinToggleChanged(bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (enabled) {
        // Activer le PIN avec le code par défaut
        await _securityService.setPinEnabled(true);

        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Sécurité par code PIN activée avec le code par défaut "1234"',
            ),
            backgroundColor: WanzoColors.success,
          ),
        );
      } else {
        // Désactiver le PIN
        await _securityService.setPinEnabled(false);

        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Sécurité par code PIN désactivée'),
            backgroundColor: WanzoColors.info,
          ),
        );
      }

      setState(() {
        _isPinEnabled = enabled;
      });

      // Vider les champs
      _currentPinController.clear();
      _newPinController.clear();
      _confirmPinController.clear();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: WanzoColors.error,
        ),
      );
    }
  }

  Future<void> _changePin() async {
    // Validation des champs
    if (_currentPinController.text.length != 4) {
      _showError('Le code PIN actuel doit contenir 4 chiffres');
      return;
    }

    if (_newPinController.text.length != 4) {
      _showError('Le nouveau code PIN doit contenir 4 chiffres');
      return;
    }

    if (_newPinController.text != _confirmPinController.text) {
      _showError('La confirmation du code PIN ne correspond pas');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final success = await _securityService.changePin(
        _currentPinController.text,
        _newPinController.text,
      );

      if (success) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Code PIN modifié avec succès'),
            backgroundColor: WanzoColors.success,
          ),
        );

        // Vider les champs
        _currentPinController.clear();
        _newPinController.clear();
        _confirmPinController.clear();
      } else {
        _showError('Code PIN actuel incorrect');
      }
    } catch (e) {
      _showError('Erreur lors de la modification du code PIN : $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: WanzoColors.error),
    );
  }
}
