// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\auth\widgets\offline_login_toggle.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Widget pour activer/désactiver la connexion hors ligne
class OfflineLoginToggle extends StatefulWidget {
  /// Fonction appelée quand la valeur change
  final Function(bool)? onChanged;

  /// Constructeur
  const OfflineLoginToggle({
    super.key,
    this.onChanged,
  });

  @override
  State<OfflineLoginToggle> createState() => _OfflineLoginToggleState();
}

class _OfflineLoginToggleState extends State<OfflineLoginToggle> {
  bool _isEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Charge les paramètres actuels
  Future<void> _loadSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAvailable = await authProvider.isOfflineLoginAvailable();
    
    if (mounted) {
      setState(() {
        _isEnabled = isAvailable;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connexion hors ligne',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Activez cette option pour vous connecter même sans connexion Internet. Vos identifiants seront stockés de manière sécurisée sur cet appareil.',
              style: TextStyle(
                fontSize: 14.0,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Activer la connexion hors ligne',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                _isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Switch(
                        value: _isEnabled,
                        onChanged: (value) async {
                          setState(() {
                            _isEnabled = value;
                          });
                          
                          if (widget.onChanged != null) {
                            widget.onChanged!(value);
                          }
                        },
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
