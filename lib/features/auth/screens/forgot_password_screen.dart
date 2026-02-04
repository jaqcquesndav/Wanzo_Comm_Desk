import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/constants/constants.dart';
import 'package:wanzo/features/auth/repositories/auth_repository.dart'; // Import AuthRepository

class ForgotPasswordScreen extends StatefulWidget {
  static const String routeName = '/forgot-password';
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitForgotPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Utiliser le AuthRepository pour envoyer l'email de réinitialisation
        await context.read<AuthRepository>().sendPasswordResetEmail(_emailController.text.trim());
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Un email de réinitialisation de mot de passe a été envoyé.'),
              backgroundColor: WanzoColors.success, // Utiliser une couleur de succès
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'envoi de l\'email: ${e.toString()}'),
              backgroundColor: WanzoColors.error, // Utiliser une couleur d'erreur
            ),
          );
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mot de passe oublié'),
        backgroundColor: WanzoColors.primary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(WanzoSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: WanzoSpacing.lg),
              Text(
                'Réinitialiser le mot de passe',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: WanzoSpacing.md),
              const Text(
                'Entrez votre adresse e-mail ci-dessous et nous vous enverrons des instructions pour réinitialiser votre mot de passe.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: WanzoTypography.fontSizeSm),
              ),
              const SizedBox(height: WanzoSpacing.xl),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Adresse e-mail',
                  hintText: 'exemple@email.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
                    borderSide: const BorderSide(color: WanzoColors.primary, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez saisir votre adresse e-mail.';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Veuillez saisir une adresse e-mail valide.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: WanzoSpacing.xl),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForgotPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WanzoColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: WanzoSpacing.md),
                  textStyle: const TextStyle(fontSize: WanzoTypography.fontSizeMd, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text('Envoyer les instructions'),
              ),
              const SizedBox(height: WanzoSpacing.md),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Retour à la connexion',
                  style: TextStyle(color: WanzoColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
