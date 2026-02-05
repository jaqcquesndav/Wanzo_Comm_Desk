import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/constants/constants.dart';
import 'package:wanzo/l10n/app_localizations.dart'; // Import AppLocalizations
import 'package:url_launcher/url_launcher.dart';
import '../bloc/auth_bloc.dart';
import '../../../features/connectivity/widgets/subtle_offline_indicator.dart';

/// Écran de connexion permettant à l'utilisateur de se connecter
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Soumission du formulaire de connexion
  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Dispatch demo login event if demo credentials are used
      if (email == 'demo@wanzo.app' && password == 'wanzo_password123') {
        context.read<AuthBloc>().add(const AuthLoginWithDemoAccountRequested());
      } else {
        // Sur desktop, on passe email/password pour l'authentification directe
        // Sur mobile/macOS, email/password sont ignorés et le flux OAuth est utilisé
        context.read<AuthBloc>().add(
          AuthLoginWithAuth0Requested(email: email, password: password),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // Get AppLocalizations instance

    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // Redirection vers le dashboard avec GoRouter
            context.go('/dashboard');
          } else if (state is AuthFailure) {
            // Affichage d'une erreur
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n.authFailureMessage(state.message),
                ), // Use localized string
                backgroundColor: WanzoColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              // Contenu principal
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(WanzoSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Petit indicateur de mode hors ligne
                          const Align(
                            alignment: Alignment.topRight,
                            child: SubtleOfflineIndicator(),
                          ),
                          const SizedBox(height: WanzoSpacing.sm),
                          // Logo et titre
                          Image.asset(
                            'assets/images/logo.png',
                            height: 80,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.storefront,
                                size: 72,
                                color: WanzoColors.primary,
                              );
                            },
                          ),
                          const SizedBox(height: WanzoSpacing.md),
                          Text(
                            'WANZO', // This could be a brand name, typically not localized
                            style: TextStyle(
                              color: WanzoColors.primary,
                              fontSize: WanzoTypography.fontSizeXl,
                              fontWeight: WanzoTypography.fontWeightBold,
                              letterSpacing: 2.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: WanzoSpacing.sm),
                          Text(
                            l10n.loginToYourAccount, // Use localized string
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: WanzoTypography.fontSizeMd,
                              fontWeight: WanzoTypography.fontWeightMedium,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: WanzoSpacing.xxl),

                          // Formulaire de connexion
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Champ email
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText:
                                        l10n.emailLabel, // Use localized string
                                    hintText:
                                        l10n.emailHint, // Use localized string
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WanzoBorderRadius.md,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WanzoBorderRadius.md,
                                      ),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WanzoBorderRadius.md,
                                      ),
                                      borderSide: const BorderSide(
                                        color: WanzoColors.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return l10n
                                          .emailValidationErrorRequired; // Use localized string
                                    }
                                    if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                    ).hasMatch(value)) {
                                      return l10n
                                          .emailValidationErrorInvalid; // Use localized string
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: WanzoSpacing.md),

                                // Champ mot de passe
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText:
                                        l10n.passwordLabel, // Use localized string
                                    hintText:
                                        l10n.passwordHint, // Use localized string
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WanzoBorderRadius.md,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WanzoBorderRadius.md,
                                      ),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WanzoBorderRadius.md,
                                      ),
                                      borderSide: const BorderSide(
                                        color: WanzoColors.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return l10n
                                          .passwordValidationErrorRequired; // Use localized string
                                    }
                                    return null;
                                  },
                                ),

                                // Option se souvenir de moi et mot de passe oublié
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      // Wrap with Expanded
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: _rememberMe,
                                            onChanged: (value) {
                                              setState(() {
                                                _rememberMe = value!;
                                              });
                                            },
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          Flexible(
                                            // Use Flexible for text to allow wrapping if needed
                                            child: Text(
                                              l10n.rememberMeLabel, // Use localized string
                                              style: TextStyle(
                                                fontSize:
                                                    WanzoTypography.fontSizeSm,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      // Wrap with Expanded
                                      child: TextButton(
                                        onPressed: () async {
                                          // Open Auth0 password reset page
                                          // Auth0 handles password reset via Universal Login
                                          const auth0Domain =
                                              'wanzo.eu.auth0.com';
                                          const clientId =
                                              'ZopP6LhblBpTZMVJPPMbxBqLxmT7lVDo';
                                          final resetUrl = Uri.parse(
                                            'https://$auth0Domain/authorize?client_id=$clientId&response_type=code&redirect_uri=com.wanzo.app://callback&screen_hint=reset_password',
                                          );
                                          if (await canLaunchUrl(resetUrl)) {
                                            await launchUrl(
                                              resetUrl,
                                              mode:
                                                  LaunchMode
                                                      .externalApplication,
                                            );
                                          } else {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    l10n.forgotPasswordButton,
                                                  ),
                                                  backgroundColor:
                                                      WanzoColors.info,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: Text(
                                          l10n.forgotPasswordButton, // Use localized string
                                          textAlign:
                                              TextAlign
                                                  .end, // Align text to the end
                                          style: TextStyle(
                                            fontSize:
                                                WanzoTypography.fontSizeSm,
                                            color: WanzoColors.primary,
                                            fontWeight:
                                                WanzoTypography
                                                    .fontWeightMedium,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: WanzoSpacing.lg),

                                // Bouton de connexion
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed:
                                        state is AuthLoading
                                            ? null
                                            : _submitForm,
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          WanzoBorderRadius.md,
                                        ),
                                      ),
                                    ),
                                    child:
                                        state is AuthLoading
                                            ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 3,
                                              ),
                                            )
                                            : Text(
                                              l10n.loginButton, // Use localized string
                                              style: TextStyle(
                                                fontSize:
                                                    WanzoTypography.fontSizeMd,
                                                fontWeight:
                                                    WanzoTypography
                                                        .fontWeightSemiBold,
                                              ),
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ), // Fin du Form
                          // Lien vers la création de compte
                          const SizedBox(height: WanzoSpacing.xl),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n.noAccountPrompt,
                              ), // Use localized string
                              TextButton(
                                onPressed: () {
                                  context.go('/signup');
                                },
                                child: Text(
                                  l10n.createAccountButton, // Use localized string
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),

                          // Mode démo pour test rapide
                          const SizedBox(height: WanzoSpacing.lg),
                          OutlinedButton(
                            onPressed:
                                state is AuthLoading
                                    ? null
                                    : () {
                                      // Update credentials to the specific demo ones
                                      _emailController.text = 'demo@wanzo.app';
                                      _passwordController.text =
                                          'wanzo_password123';
                                      _submitForm(); // This will now correctly dispatch AuthLoginWithDemoAccountRequested
                                    },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  WanzoBorderRadius.md,
                                ),
                              ),
                            ),
                            child: Text(
                              l10n.demoModeButton,
                            ), // Use localized string
                          ),
                        ], // Fin des enfants de la colonne principale
                      ), // Fin de la colonne principale
                    ), // Fin du padding
                  ), // Fin du SingleChildScrollView
                ), // Fin du Center
              ), // Fin du SafeArea
            ], // Fin des enfants du Stack
          ); // Fin du Stack
        },
      ),
    );
  }
}
