import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/constants/constants.dart';
import 'package:wanzo/l10n/app_localizations.dart'; // Import AppLocalizations
import '../models/business_sector.dart';
import '../repositories/registration_repository.dart';
import '../models/registration_request.dart';
import '../../auth/bloc/auth_bloc.dart';

/// Écran d'inscription pour un nouveau compte entreprise
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Contrôleurs pour les champs de texte
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _rccmController = TextEditingController();
  final _locationController = TextEditingController();
  
  // Secteur sélectionné
  BusinessSector? _selectedSector;
  List<BusinessSector> _businessSectors = [];

  // État du formulaire
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isRegistering = false;
  
  // Stepper
  int _currentStep = 0;
  static const int _totalSteps = 3;
  
  @override
  void dispose() {
    _ownerNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _companyNameController.dispose();
    _rccmController.dispose();
    _locationController.dispose();
    super.dispose();
  }
  
  @override
  void initState() {
    super.initState();
    // Initialize _selectedSector and _businessSectors after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // It's safer to initialize _businessSectors here as context is available.
        _businessSectors = getAfricanBusinessSectors(context);
        if (_businessSectors.isNotEmpty) {
          setState(() {
            _selectedSector = _businessSectors.first;
          });
        }
      }
    });
  }
  
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Informations personnelles
        final String email = _emailController.text.trim(); // Trim email once
        if (_ownerNameController.text.trim().isEmpty) return false;
        // Use the trimmed email for both isEmpty and regex checks
        if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) return false;
        if (_phoneController.text.trim().isEmpty) return false;
        if (_passwordController.text.isEmpty || _passwordController.text.length < 8) return false;
        if (_passwordController.text != _confirmPasswordController.text) return false;
        return true;
      case 1: // Informations de l'entreprise
        if (_companyNameController.text.trim().isEmpty) return false;
        if (_rccmController.text.trim().isEmpty) return false;
        if (_locationController.text.trim().isEmpty) return false;
        return true;
      case 2: // Confirmation
        return _agreeToTerms;
      default:
        return false;
    }
  }
  
  void _nextStep() {
    if (_validateCurrentStep()) {
      setState(() {
        if (_currentStep < _totalSteps - 1) {
          _currentStep++;
        } else {
          _register();
        }
      });
    } else {
      // Afficher une validation d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.signupErrorFillFields),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
  
  void _previousStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }
  
  void _register() async {
    final l10n = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) {
      return; // Don't proceed if form is not valid
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.signupErrorAgreeToTerms),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (_selectedSector == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.signupActivitySectorLabel), // Consider a more specific error key like "pleaseSelectABusinessSector"
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isRegistering = true;
    });
    
    final request = RegistrationRequest(
      ownerName: _ownerNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phoneNumber: _phoneController.text.trim(),
      companyName: _companyNameController.text.trim(),
      rccmNumber: _rccmController.text.trim(),
      location: _locationController.text.trim(),
      sector: _selectedSector!, // Null assertion is safe due to the check above
    );
    
    try {
      final repository = RegistrationRepository();
      final success = await repository.register(request);
      
      if (success && mounted) {
        // Effectuer la connexion avec les identifiants fournis
        context.read<AuthBloc>().add(
          AuthLoginRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
        );
        
        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.signupSuccessMessage),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        
        // Rediriger vers le tableau de bord
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.signupErrorRegistration(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // Get AppLocalizations instance

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.signupScreenTitle),
        automaticallyImplyLeading: true,
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: _nextStep,
          onStepCancel: _previousStep,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: WanzoSpacing.lg),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: details.onStepCancel,
                        child: Text(l10n.signupButtonPrevious),
                      ),
                    ),
                  if (_currentStep > 0)
                    const SizedBox(width: WanzoSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isRegistering ? null : details.onStepContinue,
                      child: _isRegistering
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_currentStep == _totalSteps - 1 ? l10n.signupButtonRegister : l10n.signupButtonNext),
                    ),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: Text(l10n.signupStepIdentity),
              content: _buildOwnerInfoStep(),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: Text(l10n.signupStepCompany),
              content: _buildCompanyInfoStep(),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: Text(l10n.signupStepConfirmation),
              content: _buildConfirmationStep(),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(WanzoSpacing.md),
        child: TextButton(
          onPressed: () => context.go('/login'),
          child: Text(l10n.signupAlreadyHaveAccount),
        ),
      ),
    );
  }
  
  /// Étape 1: Informations sur le propriétaire
  Widget _buildOwnerInfoStep() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.signupPersonalInfoTitle,
          style: TextStyle(
            fontSize: WanzoTypography.fontSizeLg,
            fontWeight: WanzoTypography.fontWeightBold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: WanzoSpacing.md),
        
        // Nom du propriétaire
        TextFormField(
          controller: _ownerNameController,
          decoration: InputDecoration(
            labelText: l10n.signupOwnerNameLabel,
            hintText: l10n.signupOwnerNameHint,
            prefixIcon: const Icon(Icons.person_outline),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.signupOwnerNameValidation;
            }
            return null;
          },
        ),
        const SizedBox(height: WanzoSpacing.md),
        
        // Email
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.signupEmailLabel,
            hintText: l10n.signupEmailHint,
            prefixIcon: const Icon(Icons.email_outlined),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.signupEmailValidationRequired;
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return l10n.signupEmailValidationInvalid;
            }
            return null;
          },
        ),
        const SizedBox(height: WanzoSpacing.md),
        
        // Téléphone
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: l10n.signupPhoneLabel,
            hintText: l10n.signupPhoneHint,
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.signupPhoneValidation;
            }
            return null;
          },
        ),
        const SizedBox(height: WanzoSpacing.md),
        
        // Mot de passe
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: l10n.signupPasswordLabel,
            hintText: l10n.signupPasswordHint,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.signupPasswordValidationRequired;
            }
            if (value.length < 8) {
              return l10n.signupPasswordValidationLength;
            }
            return null;
          },
        ),
        const SizedBox(height: WanzoSpacing.md),
        
        // Confirmation du mot de passe
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: l10n.signupConfirmPasswordLabel,
            hintText: l10n.signupConfirmPasswordHint,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.signupConfirmPasswordValidationRequired;
            }
            if (value != _passwordController.text) {
              return l10n.signupConfirmPasswordValidationMatch;
            }
            return null;
          },
        ),
        const SizedBox(height: WanzoSpacing.sm),
        
        Text(
          l10n.signupRequiredFields,
          style: const TextStyle(
            fontSize: WanzoTypography.fontSizeXs,
            color: WanzoColors.textSecondaryLight,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
  
  /// Étape 2: Informations sur l'entreprise
  Widget _buildCompanyInfoStep() {
    final l10n = AppLocalizations.of(context)!;
    if (_businessSectors.isEmpty && _selectedSector == null) {
      // This case might occur if build is called before the post frame callback in initState completes.
      // Or if getAfricanBusinessSectors returns an empty list and _selectedSector hasn't been set.
      // Return a loading indicator or an empty container.
      // It might be better to initialize _businessSectors and _selectedSector directly in initState
      // if getAfricanBusinessSectors doesn't depend on a fully built context for l10n.
      // However, since l10n is used, postFrameCallback is safer.
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.signupCompanyInfoTitle,
          style: TextStyle(
            fontSize: WanzoTypography.fontSizeLg,
            fontWeight: WanzoTypography.fontWeightBold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: WanzoSpacing.md),
        
        // Nom de l'entreprise
        TextFormField(
          controller: _companyNameController,
          decoration: InputDecoration(
            labelText: l10n.signupCompanyNameLabel,
            hintText: l10n.signupCompanyNameHint,
            prefixIcon: const Icon(Icons.business_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.signupCompanyNameValidation;
            }
            return null;
          },
        ),
        const SizedBox(height: WanzoSpacing.md),
        
        // Numéro RCCM
        TextFormField(
          controller: _rccmController,
          decoration: InputDecoration(
            labelText: l10n.signupRccmLabel,
            hintText: l10n.signupRccmHint,
            prefixIcon: const Icon(Icons.numbers_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.signupRccmValidation;
            }
            return null;
          },
        ),
        const SizedBox(height: WanzoSpacing.md),
        
        // Adresse / Lieu
        TextFormField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText: l10n.signupAddressLabel,
            hintText: l10n.signupAddressHint,
            prefixIcon: const Icon(Icons.location_on_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.signupAddressValidation;
            }
            return null;
          },
        ),
        const SizedBox(height: WanzoSpacing.md),
        
        // Secteur d'activité
        DropdownButtonFormField<BusinessSector>(
          value: _selectedSector,
          decoration: InputDecoration(
            labelText: l10n.signupActivitySectorLabel,
            prefixIcon: const Icon(Icons.category_outlined),
          ),
          items: _businessSectors.map((sector) {
            return DropdownMenuItem<BusinessSector>(
              value: sector,
              child: Text(sector.name), // sector.name is now localized via getAfricanBusinessSectors
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedSector = value;
              });
            }
          },
          // Removed validator as per previous discussion, relying on _register() check
          // validator: (value) { 
          //   if (value == null) {
          //     return l10n.signupActivitySectorLabel; 
          //   }
          //   return null;
          // },
        ),
        const SizedBox(height: WanzoSpacing.sm),
        
        Text(
          l10n.signupRequiredFields,          style: const TextStyle(
            fontSize: WanzoTypography.fontSizeXs,
            color: WanzoColors.textSecondaryLight,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
  
  /// Étape 3: Confirmation
  Widget _buildConfirmationStep() {
    final l10n = AppLocalizations.of(context)!;
    final sectorName = _selectedSector?.name ?? l10n.sectorOtherName; // Default if null

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.signupTermsAndConditionsTitle,
          style: TextStyle(
            fontSize: WanzoTypography.fontSizeLg,
            fontWeight: WanzoTypography.fontWeightBold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: WanzoSpacing.md),
        
        // Résumé des informations
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(WanzoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.signupInfoSummaryPersonal,
                  style: const TextStyle(
                    fontSize: WanzoTypography.fontSizeMd,
                    fontWeight: WanzoTypography.fontWeightBold,
                  ),
                ),
                const Divider(),
                _buildInfoRow(l10n.signupInfoSummaryName, _ownerNameController.text),
                _buildInfoRow(l10n.signupInfoSummaryEmail, _emailController.text),
                _buildInfoRow(l10n.signupInfoSummaryPhone, _phoneController.text),
                
                const SizedBox(height: WanzoSpacing.md),
                Text(
                  l10n.signupInfoSummaryCompany,
                  style: const TextStyle(
                    fontSize: WanzoTypography.fontSizeMd,
                    fontWeight: WanzoTypography.fontWeightBold,
                  ),
                ),
                const Divider(),
                _buildInfoRow(l10n.signupInfoSummaryCompanyName, _companyNameController.text),
                _buildInfoRow(l10n.signupInfoSummaryRccm, _rccmController.text),
                _buildInfoRow(l10n.signupInfoSummaryAddress, _locationController.text),
                _buildInfoRow(l10n.signupInfoSummaryActivitySector, sectorName),
              ],
            ),
          ),
        ),
        const SizedBox(height: WanzoSpacing.md),
        
        // Acceptation des conditions
        Row(
          children: [
            Checkbox(
              value: _agreeToTerms,
              onChanged: (value) {
                setState(() {
                  _agreeToTerms = value ?? false;
                });
              },
              activeColor: Theme.of(context).colorScheme.primary,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _agreeToTerms = !_agreeToTerms;
                  });
                },
                child: RichText(
                  text: TextSpan(
                    text: '${l10n.signupAgreeToTerms} ', // Add space
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    children: [
                      TextSpan(
                        text: l10n.signupTermsOfUse,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      TextSpan(text: ' ${l10n.andConnector} '), // Use template literal for clarity
                      TextSpan(
                        text: l10n.signupPrivacyPolicy,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: WanzoSpacing.sm),
        Text(
          l10n.signupAgreeToTermsConfirmation,
          style: TextStyle(
            fontSize: WanzoTypography.fontSizeSm,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
