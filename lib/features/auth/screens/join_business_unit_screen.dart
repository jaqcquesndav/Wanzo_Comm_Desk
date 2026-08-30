import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/constants/constants.dart';
import 'package:wanzo/core/platform/platform_service.dart';
import 'package:wanzo/core/utils/logout_confirmation.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import '../bloc/auth_bloc.dart';

/// Écran de saisie du code d'unité d'affaires
///
/// Affiché quand un utilisateur non-admin n'a pas encore de BU assignée.
/// L'admin communique le code BU (ex: "BRN-KIN-001") par email/WhatsApp.
class JoinBusinessUnitScreen extends StatefulWidget {
  const JoinBusinessUnitScreen({super.key});

  @override
  State<JoinBusinessUnitScreen> createState() => _JoinBusinessUnitScreenState();
}

class _JoinBusinessUnitScreenState extends State<JoinBusinessUnitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submitCode() {
    if (_formKey.currentState?.validate() ?? false) {
      final code = _codeController.text.trim().toUpperCase();
      context.read<AuthBloc>().add(
        AuthJoinBusinessUnitRequested(businessUnitCode: code),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenSize = MediaQuery.of(context).size;
    final platform = PlatformService.instance;
    final isDesktop = screenSize.width >= platform.desktopMinWidth;
    final theme = Theme.of(context);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthJoinBusinessUnitInProgress) {
          setState(() => _isSubmitting = true);
        } else {
          setState(() => _isSubmitting = false);
        }

        if (state is AuthJoinBusinessUnitFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
              backgroundColor: Colors.red[700],
              duration: const Duration(seconds: 4),
            ),
          );
        }

        if (state is AuthAuthenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unité d\'affaires rejointe avec succès !'),
              backgroundColor: Colors.green[700],
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 500 : double.infinity,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 48 : 24,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Icône
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: WanzoColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.store,
                            size: isDesktop ? 64 : 56,
                            color: WanzoColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 32 : 24),

                      // Titre
                      Text(
                        l10n?.businessUnitConfigureByCode ??
                            'Rejoindre une unité d\'affaires',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: WanzoTypography.fontWeightBold,
                          fontSize: isDesktop ? 28 : 22,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Text(
                        l10n?.businessUnitConfigureByCodeDescription ??
                            'Votre administrateur vous a communiqué un code d\'unité '
                                'd\'affaires (succursale ou point de vente). '
                                'Entrez-le ci-dessous pour accéder à vos fonctionnalités.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                          fontSize: isDesktop ? 16 : 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isDesktop ? 40 : 32),

                      // Formulaire
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _codeController,
                              enabled: !_isSubmitting,
                              textCapitalization: TextCapitalization.characters,
                              style: TextStyle(
                                fontSize: isDesktop ? 18 : 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    l10n?.businessUnitCodeLabel ??
                                    'Code unité d\'affaires',
                                hintText: 'BRN-KIN-001',
                                prefixIcon: const Icon(Icons.qr_code),
                                border: const OutlineInputBorder(),
                                helperText:
                                    l10n?.businessUnitCodeHelper ??
                                    'Code communiqué par votre administrateur',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return l10n?.fieldRequired ??
                                      'Ce champ est requis';
                                }
                                if (value.trim().length < 3) {
                                  return 'Le code doit contenir au moins 3 caractères';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _submitCode(),
                            ),
                            const SizedBox(height: 24),

                            // Bouton de validation
                            SizedBox(
                              width: double.infinity,
                              height: isDesktop ? 52 : 48,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : _submitCode,
                                icon:
                                    _isSubmitting
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(Icons.login),
                                label: Text(
                                  _isSubmitting
                                      ? 'Jonction en cours...'
                                      : 'Rejoindre',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 16 : 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: WanzoColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isDesktop ? 32 : 24),

                      // Info box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n?.businessUnitCodeInfo ??
                                    'Si vous n\'avez pas reçu de code, contactez '
                                        'votre administrateur. Le code est généralement '
                                        'au format "BRN-XXX-NNN" ou "POS-XXX-NNN".',
                                style: TextStyle(
                                  color: Colors.blue[800],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bouton déconnexion
                      Center(
                        child: TextButton.icon(
                          onPressed:
                              _isSubmitting
                                  ? null
                                  : () async {
                                    final confirmed =
                                        await confirmLogout(context);
                                    if (confirmed && context.mounted) {
                                      context.read<AuthBloc>().add(
                                        const AuthLogoutRequested(),
                                      );
                                    }
                                  },
                          icon: Icon(
                            Icons.logout,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                          label: Text(
                            'Se déconnecter',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
