import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../bloc/financial_account_bloc.dart';
import '../bloc/financial_account_event.dart';
import '../models/financial_account.dart';
import '../../financing/models/financing_request.dart';

/// Écran d'ajout/modification de compte financier
class AddFinancialAccountScreen extends StatefulWidget {
  /// Compte à modifier (null pour un nouveau compte)
  final FinancialAccount? account;

  const AddFinancialAccountScreen({super.key, this.account});

  @override
  State<AddFinancialAccountScreen> createState() =>
      _AddFinancialAccountScreenState();
}

class _AddFinancialAccountScreenState extends State<AddFinancialAccountScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TabController _tabController;

  // Contrôleurs communs
  late TextEditingController _accountNameController;
  bool _isDefault = false;

  // Contrôleurs pour compte bancaire
  late TextEditingController _bankAccountNumberController;
  late TextEditingController _swiftCodeController;

  // Contrôleurs pour Mobile Money
  late TextEditingController _phoneNumberController;
  late TextEditingController _accountHolderNameController;
  late TextEditingController _pinController;
  MobileMoneyProvider _selectedProvider = MobileMoneyProvider.airtelMoney;

  // Variables d'état
  FinancialAccountType _selectedAccountType = FinancialAccountType.bankAccount;
  FinancialInstitution _selectedInstitution = FinancialInstitution.equitybcdc;
  bool _isEditing = false;
  bool _showPin = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.account != null;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex:
          _isEditing
              ? (widget.account!.type == FinancialAccountType.bankAccount
                  ? 0
                  : 1)
              : 0,
    );

    _initializeControllers();
    _initializeFormData();
  }

  void _initializeControllers() {
    _accountNameController = TextEditingController();
    _bankAccountNumberController = TextEditingController();
    _swiftCodeController = TextEditingController();
    _phoneNumberController = TextEditingController();
    _accountHolderNameController = TextEditingController();
    _pinController = TextEditingController();
  }

  void _initializeFormData() {
    if (_isEditing && widget.account != null) {
      final account = widget.account!;
      _accountNameController.text = account.accountName;
      _isDefault = account.isDefault;
      _selectedAccountType = account.type;

      if (account.type == FinancialAccountType.bankAccount) {
        _selectedInstitution =
            account.bankInstitution ?? FinancialInstitution.equitybcdc;
        _bankAccountNumberController.text = account.bankAccountNumber ?? '';
        _swiftCodeController.text = account.swiftCode ?? '';
      } else {
        _selectedProvider =
            account.mobileMoneyProvider ?? MobileMoneyProvider.airtelMoney;
        _phoneNumberController.text = account.phoneNumber ?? '';
        _accountHolderNameController.text = account.accountHolderName ?? '';
        // Ne pas pré-remplir le PIN pour des raisons de sécurité
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _accountNameController.dispose();
    _bankAccountNumberController.dispose();
    _swiftCodeController.dispose();
    _phoneNumberController.dispose();
    _accountHolderNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le compte' : 'Ajouter un compte'),
        actions: [
          TextButton(
            onPressed: _saveAccount,
            child: Text(
              'Sauvegarder',
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child:
            _isEditing
                ? _buildEditForm()
                : Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.grey,
                      onTap: (index) {
                        setState(() {
                          _selectedAccountType =
                              index == 0
                                  ? FinancialAccountType.bankAccount
                                  : FinancialAccountType.mobileMoney;
                        });
                      },
                      tabs: const [
                        Tab(text: 'Compte Bancaire'),
                        Tab(text: 'Mobile Money'),
                      ],
                    ),
                    Expanded(child: _buildTabView()),
                  ],
                ),
      ),
    );
  }

  Widget _buildTabView() {
    return TabBarView(
      controller: _tabController,
      children: [_buildBankAccountForm(), _buildMobileMoneyForm()],
    );
  }

  Widget _buildEditForm() {
    return _selectedAccountType == FinancialAccountType.bankAccount
        ? _buildBankAccountForm()
        : _buildMobileMoneyForm();
  }

  Widget _buildBankAccountForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Informations générales'),
          const SizedBox(height: 16),
          _buildAccountNameField(),
          const SizedBox(height: 16),
          _buildDefaultAccountSwitch(),
          const SizedBox(height: 32),

          _buildSectionTitle('Informations bancaires'),
          const SizedBox(height: 16),
          _buildBankInstitutionField(),
          const SizedBox(height: 16),
          _buildAccountNumberField(),
          const SizedBox(height: 16),
          _buildSwiftCodeField(),
          const SizedBox(height: 32),

          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildMobileMoneyForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Informations Mobile Money'),
          const SizedBox(height: 16),
          _buildAccountNameField(),
          const SizedBox(height: 16),
          _buildProviderSelector(),
          const SizedBox(height: 16),
          _buildPhoneNumberField(),
          const SizedBox(height: 16),
          _buildAccountHolderField(),
          const SizedBox(height: 16),
          _buildPinField(),
          const SizedBox(height: 16),
          _buildDefaultAccountSwitch(),
          const SizedBox(height: 32),

          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildAccountNameField() {
    return TextFormField(
      controller: _accountNameController,
      decoration: const InputDecoration(
        labelText: 'Nom du compte *',
        hintText: 'Ex: Compte principal, Compte épargne...',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.account_circle),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Le nom du compte est requis';
        }
        return null;
      },
    );
  }

  Widget _buildDefaultAccountSwitch() {
    return SwitchListTile(
      title: const Text('Compte par défaut'),
      subtitle: const Text(
        'Ce compte sera utilisé par défaut pour les transactions',
      ),
      value: _isDefault,
      onChanged: (value) {
        setState(() {
          _isDefault = value;
        });
      },
    );
  }

  Widget _buildBankInstitutionField() {
    return DropdownButtonFormField<FinancialInstitution>(
      value: _selectedInstitution,
      decoration: const InputDecoration(
        labelText: 'Institution financière *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.business),
      ),
      items:
          FinancialInstitution.values.map((institution) {
            return DropdownMenuItem(
              value: institution,
              child: Text(institution.displayName),
            );
          }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedInstitution = value!;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'L\'institution financière est requise';
        }
        return null;
      },
    );
  }

  Widget _buildAccountNumberField() {
    return TextFormField(
      controller: _bankAccountNumberController,
      decoration: const InputDecoration(
        labelText: 'Numéro de compte *',
        hintText: 'Entrez le numéro de compte bancaire',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.numbers),
      ),
      keyboardType: TextInputType.text,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Le numéro de compte est requis';
        }
        if (value.length < 8) {
          return 'Le numéro de compte doit contenir au moins 8 caractères';
        }
        return null;
      },
    );
  }

  Widget _buildSwiftCodeField() {
    return TextFormField(
      controller: _swiftCodeController,
      decoration: const InputDecoration(
        labelText: 'Code SWIFT *',
        hintText: 'Ex: EQBLKENA, KCBLKENX...',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.code),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
        LengthLimitingTextInputFormatter(11),
        UpperCaseTextFormatter(),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Le code SWIFT est requis';
        }
        if (value.length < 8 || value.length > 11) {
          return 'Le code SWIFT doit contenir entre 8 et 11 caractères';
        }
        return null;
      },
    );
  }

  Widget _buildProviderSelector() {
    return DropdownButtonFormField<MobileMoneyProvider>(
      value: _selectedProvider,
      decoration: const InputDecoration(
        labelText: 'Fournisseur *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.business_center),
      ),
      items:
          MobileMoneyProvider.values.map((provider) {
            return DropdownMenuItem(
              value: provider,
              child: Row(
                children: [
                  Icon(_getProviderIcon(provider)),
                  const SizedBox(width: 8),
                  Text(_getProviderName(provider)),
                ],
              ),
            );
          }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedProvider = value!;
        });
      },
    );
  }

  Widget _buildPhoneNumberField() {
    return TextFormField(
      controller: _phoneNumberController,
      decoration: const InputDecoration(
        labelText: 'Numéro de téléphone *',
        hintText: 'Ex: +243981234567',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.phone),
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[+0-9]'))],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Le numéro de téléphone est requis';
        }
        final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
        if (!phoneRegex.hasMatch(value)) {
          return 'Numéro de téléphone invalide';
        }
        return null;
      },
    );
  }

  Widget _buildAccountHolderField() {
    return TextFormField(
      controller: _accountHolderNameController,
      decoration: const InputDecoration(
        labelText: 'Nom du titulaire *',
        hintText: 'Nom complet du titulaire du compte',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person),
      ),
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Le nom du titulaire est requis';
        }
        if (value.trim().length < 2) {
          return 'Le nom doit contenir au moins 2 caractères';
        }
        return null;
      },
    );
  }

  Widget _buildPinField() {
    return TextFormField(
      controller: _pinController,
      decoration: InputDecoration(
        labelText: 'Code PIN',
        hintText: 'Code PIN du compte (optionnel)',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          onPressed: () {
            setState(() {
              _showPin = !_showPin;
            });
          },
          icon: Icon(_showPin ? Icons.visibility_off : Icons.visibility),
        ),
      ),
      obscureText: !_showPin,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          if (value.length < 4) {
            return 'Le PIN doit contenir au moins 4 chiffres';
          }
        }
        return null;
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveAccount,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          _isEditing ? 'Mettre à jour' : 'Sauvegarder',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  void _saveAccount() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final now = DateTime.now();
    FinancialAccount account;

    if (_selectedAccountType == FinancialAccountType.bankAccount) {
      account = FinancialAccount.bankAccount(
        id: _isEditing ? widget.account!.id : _uuid.v4(),
        accountName: _accountNameController.text.trim(),
        bankInstitution: _selectedInstitution,
        bankAccountNumber: _bankAccountNumberController.text.trim(),
        swiftCode: _swiftCodeController.text.trim(),
        isDefault: _isDefault,
        createdAt: _isEditing ? widget.account!.createdAt : now,
        updatedAt: now,
      );
    } else {
      account = FinancialAccount.mobileMoney(
        id: _isEditing ? widget.account!.id : _uuid.v4(),
        accountName: _accountNameController.text.trim(),
        provider: _selectedProvider,
        phoneNumber: _phoneNumberController.text.trim(),
        accountHolderName: _accountHolderNameController.text.trim(),
        encryptedPin:
            _pinController.text.isNotEmpty
                ? _encryptPin(_pinController.text)
                : null,
        isDefault: _isDefault,
        createdAt: _isEditing ? widget.account!.createdAt : now,
        updatedAt: now,
      );
    }

    if (_isEditing) {
      context.read<FinancialAccountBloc>().add(UpdateFinancialAccount(account));
    } else {
      context.read<FinancialAccountBloc>().add(AddFinancialAccount(account));
    }

    Navigator.pop(context);
  }

  String _getProviderName(MobileMoneyProvider provider) {
    switch (provider) {
      case MobileMoneyProvider.airtelMoney:
        return 'Airtel Money';
      case MobileMoneyProvider.orangeMoney:
        return 'Orange Money';
      case MobileMoneyProvider.mpesa:
        return 'M-PESA';
    }
  }

  IconData _getProviderIcon(MobileMoneyProvider provider) {
    switch (provider) {
      case MobileMoneyProvider.airtelMoney:
        return Icons.signal_cellular_alt;
      case MobileMoneyProvider.orangeMoney:
        return Icons.signal_cellular_4_bar;
      case MobileMoneyProvider.mpesa:
        return Icons.signal_wifi_4_bar;
    }
  }

  String _encryptPin(String pin) {
    // TODO: Implémenter un chiffrement sécurisé
    // Pour l'instant, on utilise un encodage simple (à remplacer par un vrai chiffrement)
    return 'encrypted_$pin';
  }
}

/// Formatter pour convertir en majuscules
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
