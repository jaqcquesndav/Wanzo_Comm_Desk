import 'dart:io'; // Import for File
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/platform/image_picker/image_picker_service_factory.dart';
import '../../../core/platform/image_picker/image_picker_service_interface.dart';
import '../../../core/widgets/desktop/responsive_form_container.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/constants.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../settings/bloc/settings_state.dart';
import '../bloc/financing_bloc.dart';
import '../models/financing_request.dart';
import '../models/institution_metadata.dart';
import '../services/institution_metadata_service.dart';
import '../../../core/enums/currency_enum.dart';

class AddFinancingRequestScreen extends StatefulWidget {
  const AddFinancingRequestScreen({super.key});

  @override
  State<AddFinancingRequestScreen> createState() =>
      _AddFinancingRequestScreenState();
}

class _AddFinancingRequestScreenState extends State<AddFinancingRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _durationController = TextEditingController();

  FinancingType _selectedFinancingType = FinancingType.cashCredit;
  FinancialInstitution _selectedInstitution = FinancialInstitution.bonneMoisson;
  String? _attachmentPath;
  int? _creditScore; // Score chargé depuis l'API
  bool _isLoadingCreditScore = false;
  String? _creditScoreError;
  late final ImagePickerServiceInterface _imagePickerService;
  DateTime? _proposedStartDate;

  // Métadonnées dynamiques
  InstitutionMetadata? _currentInstitutionMetadata;
  List<FinancialProductInfo> _availableProducts = [];
  FinancialProductInfo? _selectedProduct;
  bool _isLoadingProducts = false;
  final InstitutionMetadataService _metadataService =
      InstitutionMetadataService();

  @override
  void initState() {
    super.initState();
    _imagePickerService = ImagePickerServiceFactory.getInstance();
    _initializeMetadataService();
    _loadInstitutionData();
    _loadCreditScore();
    // Initialiser la date de début proposée à 7 jours à partir d'aujourd'hui
    _proposedStartDate = DateTime.now().add(const Duration(days: 7));
  }

  Future<void> _initializeMetadataService() async {
    await _metadataService.init();
  }

  Future<void> _loadCreditScore() async {
    setState(() {
      _isLoadingCreditScore = true;
      _creditScoreError = null;
    });

    try {
      final financingApiService =
          context.read<FinancingBloc>().financingRepository.apiService;
      final response = await financingApiService.getCreditScore();

      if (response.success && response.data != null) {
        setState(() {
          _creditScore = response.data!['creditScore'] as int?;
          _isLoadingCreditScore = false;
        });
      } else {
        setState(() {
          _creditScoreError = 'Impossible de charger le score';
          _isLoadingCreditScore = false;
        });
      }
    } catch (e) {
      setState(() {
        _creditScoreError = 'Erreur: $e';
        _isLoadingCreditScore = false;
      });
    }
  }

  Future<void> _loadInstitutionData() async {
    setState(() {
      _isLoadingProducts = true;
    });

    try {
      final metadata = await _metadataService
          .getInstitutionMetadataWithFallback(_selectedInstitution);
      final products = await _metadataService.getProductsForInstitution(
        _selectedInstitution,
      );

      setState(() {
        _currentInstitutionMetadata = metadata;
        _availableProducts = products;
        _selectedProduct = products.isNotEmpty ? products.first : null;
        _isLoadingProducts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingProducts = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des produits: $e')),
        );
      }
    }
  }

  Future<void> _onInstitutionChanged(
    FinancialInstitution? newInstitution,
  ) async {
    if (newInstitution != null && newInstitution != _selectedInstitution) {
      setState(() {
        _selectedInstitution = newInstitution;
        _selectedProduct = null;
        _availableProducts = [];
      });
      await _loadInstitutionData();
    }
  }

  void _showCreditScoreInfo() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Votre Cote de Crédit'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Votre cote actuelle: ${_creditScore ?? 'N/A'} / 100\n'),
                  const Text(
                    'Avantages par intervalle:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: WanzoSpacing.sm),
                  const Text('0-30: Accès limité, taux élevés.'),
                  const Text('31-50: Accès modéré, conditions standards.'),
                  const Text('51-70: Bon accès, conditions favorables.'),
                  const Text(
                    '71-85: Très bon accès, conditions très avantageuses.',
                  ),
                  const Text(
                    '86-100: Excellent accès, meilleures conditions du marché.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
    );
  }

  void _submitRequest(Currency currency) {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez entrer un montant valide.')),
        );
        return;
      }

      // Validation avec les limites du produit sélectionné
      if (_selectedProduct != null) {
        if (!_selectedProduct!.isAmountValid(amount)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Le montant doit être entre ${_selectedProduct!.minAmount.toStringAsFixed(0)} et ${_selectedProduct!.maxAmount.toStringAsFixed(0)} ${currency.code}',
              ),
            ),
          );
          return;
        }

        final duration = int.tryParse(_durationController.text);
        if (duration != null && !_selectedProduct!.isDurationValid(duration)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'La durée doit être entre ${_selectedProduct!.minDurationMonths} et ${_selectedProduct!.maxDurationMonths} mois',
              ),
            ),
          );
          return;
        }
      }

      // Vérifier si la pièce jointe existe et est accessible
      if (_attachmentPath != null) {
        final file = File(_attachmentPath!);
        if (!file.existsSync()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La pièce jointe sélectionnée n\'est pas accessible.',
              ),
            ),
          );
        }
      }

      final newRequest = FinancingRequest(
        id: const Uuid().v4(),
        amount: amount,
        currency: currency.code,
        reason: _reasonController.text,
        type: _selectedFinancingType,
        institution: _selectedInstitution,
        requestDate: DateTime.now(),
        attachmentPaths: _attachmentPath != null ? [_attachmentPath!] : null,
        // Nouvelles propriétés basées sur les métadonnées
        portfolioId: _currentInstitutionMetadata?.portfolioId,
        productType: _selectedProduct?.productType,
        duration: int.tryParse(_durationController.text),
        durationUnit: 'months',
        proposedStartDate:
            _proposedStartDate ?? DateTime.now().add(const Duration(days: 7)),
        // Données financières structurées pour le backend
        financialData: {
          'creditScore': _creditScore,
          'selectedProduct': _selectedProduct?.toJson(),
          'institutionMetadata': _currentInstitutionMetadata?.toJson(),
          'requestTimestamp': DateTime.now().toIso8601String(),
        },
        // Les autres champs seront remplis par le backend selon le cycle de vie
      );

      context.read<FinancingBloc>().add(AddFinancingRequest(newRequest));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        Currency currentCurrency =
            Currency.USD; // Changed CurrencyType to Currency and default value
        String currencySymbol = currentCurrency.symbol; // Used .symbol getter

        if (settingsState is SettingsLoaded) {
          currentCurrency =
              settingsState
                  .settings
                  .activeCurrency; // Changed to activeCurrency
          currencySymbol = currentCurrency.symbol; // Used .symbol getter
        } else if (settingsState is SettingsUpdated) {
          currentCurrency =
              settingsState
                  .settings
                  .activeCurrency; // Changed to activeCurrency
          currencySymbol = currentCurrency.symbol; // Used .symbol getter
        }

        return WanzoScaffold(
          title: 'Nouvelle Demande de Financement',
          currentIndex: 0,
          body: BlocListener<FinancingBloc, FinancingState>(
            listener: (context, financingBlocState) {
              if (financingBlocState is FinancingOperationSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(financingBlocState.message)),
                );
                if (context.canPop()) {
                  context.pop();
                }
              } else if (financingBlocState is FinancingError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${financingBlocState.message}'),
                  ),
                );
              }
            },
            child: ResponsiveFormWrapper(
              child: Padding(
                padding: const EdgeInsets.all(WanzoSpacing.md),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: <Widget>[
                      // Carte du score de crédit avec style Wanzo
                      Card(
                        elevation: 2,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(WanzoRadius.md),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(20),
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(10),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(WanzoRadius.md),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(
                              WanzoSpacing.md,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(WanzoSpacing.sm),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(
                                  WanzoRadius.sm,
                                ),
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              _isLoadingCreditScore
                                  ? 'Chargement du score...'
                                  : _creditScoreError != null
                                  ? 'Score indisponible'
                                  : 'Votre Cote de Crédit: ${_creditScore ?? 'N/A'} / 100',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            subtitle: Text(
                              'Excellent profil de crédit',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(180),
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: _showCreditScoreInfo,
                              tooltip: 'Plus d\'informations sur votre cote',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: WanzoSpacing.lg),

                      // Date de début proposée
                      Card(
                        elevation: 1,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(WanzoRadius.sm),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withAlpha(100),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(WanzoRadius.sm),
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  _proposedStartDate ??
                                  DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null &&
                                picked != _proposedStartDate) {
                              setState(() {
                                _proposedStartDate = picked;
                              });
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(WanzoSpacing.md),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: WanzoSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Date de début souhaitée',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelMedium?.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: WanzoSpacing.xs),
                                      Text(
                                        _proposedStartDate != null
                                            ? "${_proposedStartDate!.day}/${_proposedStartDate!.month}/${_proposedStartDate!.year}"
                                            : "Sélectionner une date",
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                      ),
                                      Text(
                                        'Quand souhaitez-vous commencer le financement ?',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: WanzoSpacing.md),

                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Montant demandé',
                          prefixText: '$currencySymbol ',
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(120),
                          ),
                          helperText:
                              _selectedProduct != null
                                  ? 'Entre ${_selectedProduct!.minAmount.toStringAsFixed(0)} et ${_selectedProduct!.maxAmount.toStringAsFixed(0)}'
                                  : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(WanzoRadius.sm),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(WanzoRadius.sm),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un montant.';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Veuillez entrer un montant valide.';
                          }
                          // Validation avec les limites du produit si disponible
                          if (_selectedProduct != null &&
                              !_selectedProduct!.isAmountValid(amount)) {
                            return 'Montant hors limites autorisées';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: WanzoSpacing.md),

                      // Durée en mois
                      TextFormField(
                        controller: _durationController,
                        decoration: InputDecoration(
                          labelText: 'Durée souhaitée (mois)',
                          prefixIcon: Icon(
                            Icons.schedule,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(120),
                          ),
                          helperText:
                              _selectedProduct != null
                                  ? 'Entre ${_selectedProduct!.minDurationMonths} et ${_selectedProduct!.maxDurationMonths} mois'
                                  : 'Entre 1 et 60 mois',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(WanzoRadius.sm),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(WanzoRadius.sm),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer une durée.';
                          }
                          final duration = int.tryParse(value);
                          if (duration == null || duration <= 0) {
                            return 'Veuillez entrer une durée valide.';
                          }
                          // Validation avec les limites du produit si disponible
                          if (_selectedProduct != null &&
                              !_selectedProduct!.isDurationValid(duration)) {
                            return 'Durée hors limites autorisées';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: WanzoSpacing.md),

                      TextFormField(
                        controller: _reasonController,
                        decoration: InputDecoration(
                          labelText: 'Objet/Motif de la demande',
                          helperText:
                              'Décrivez précisément l\'utilisation des fonds',
                          prefixIcon: Icon(
                            Icons.description_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(120),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(WanzoRadius.sm),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(WanzoRadius.sm),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer le motif.';
                          }
                          if (value.length < 10) {
                            return 'Veuillez fournir plus de détails (minimum 10 caractères).';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: WanzoSpacing.md),

                      // Sélection de l'institution financière
                      DropdownButtonFormField<FinancialInstitution>(
                        value: _selectedInstitution,
                        decoration: InputDecoration(
                          labelText: 'Institution Financière',
                          prefixIcon: Icon(
                            Icons.account_balance,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(120),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(WanzoRadius.sm),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(WanzoRadius.sm),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        items:
                            FinancialInstitution.values.map((
                              FinancialInstitution institution,
                            ) {
                              return DropdownMenuItem<FinancialInstitution>(
                                value: institution,
                                child: Text(institution.displayName),
                              );
                            }).toList(),
                        onChanged: _onInstitutionChanged,
                      ),
                      const SizedBox(height: WanzoSpacing.md),

                      // Sélection du produit financier (dynamique)
                      if (_isLoadingProducts)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(WanzoSpacing.md),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_availableProducts.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<FinancialProductInfo>(
                              value: _selectedProduct,
                              decoration: const InputDecoration(
                                labelText: 'Produit Financier',
                              ),
                              items:
                                  _availableProducts.map((product) {
                                    return DropdownMenuItem<
                                      FinancialProductInfo
                                    >(
                                      value: product,
                                      child: Text(product.productName),
                                    );
                                  }).toList(),
                              onChanged: (FinancialProductInfo? newProduct) {
                                setState(() {
                                  _selectedProduct = newProduct;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Veuillez sélectionner un produit.';
                                }
                                return null;
                              },
                            ),
                            if (_selectedProduct != null) ...[
                              const SizedBox(height: WanzoSpacing.sm),
                              Card(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withAlpha((255 * 0.5).round()),
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    WanzoSpacing.sm,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedProduct!.description,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: WanzoSpacing.xs),
                                      Text(
                                        'Taux indicatif: ${_selectedProduct!.baseInterestRate}% par an',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (_selectedProduct!
                                          .requiredDocuments
                                          .isNotEmpty) ...[
                                        const SizedBox(height: WanzoSpacing.xs),
                                        Text(
                                          'Documents requis: ${_selectedProduct!.requiredDocuments.join(', ')}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      else
                        Card(
                          color: Colors.orange.shade50,
                          child: const Padding(
                            padding: EdgeInsets.all(WanzoSpacing.md),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange),
                                SizedBox(width: WanzoSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Aucun produit disponible pour cette institution. Vous pouvez tout de même soumettre votre demande.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: WanzoSpacing.md),

                      // Type de financement (pour compatibilité avec l'ancien système)
                      DropdownButtonFormField<FinancingType>(
                        value: _selectedFinancingType,
                        decoration: InputDecoration(
                          labelText: 'Catégorie de financement',
                          helperText:
                              'Classification générale (pour référence interne)',
                          prefixIcon: Icon(
                            Icons.category_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(120),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(WanzoRadius.sm),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(WanzoRadius.sm),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        items:
                            FinancingType.values.map((FinancingType type) {
                              return DropdownMenuItem<FinancingType>(
                                value: type,
                                child: Text(type.displayName),
                              );
                            }).toList(),
                        onChanged: (FinancingType? newValue) {
                          setState(() {
                            _selectedFinancingType = newValue!;
                          });
                        },
                      ),
                      const SizedBox(height: WanzoSpacing.md),
                      // Section pièce jointe avec style amélioré
                      Card(
                        elevation: 1,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(WanzoRadius.sm),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(WanzoSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.attach_file,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: WanzoSpacing.sm),
                                  Text(
                                    'Pièce jointe (Optionnel)',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: WanzoSpacing.sm),
                              if (_attachmentPath == null)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter un fichier'),
                                  onPressed: _pickAttachment,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    side: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withAlpha(100),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        WanzoRadius.sm,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(
                                    WanzoSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withAlpha(20),
                                    borderRadius: BorderRadius.circular(
                                      WanzoRadius.sm,
                                    ),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withAlpha(100),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.insert_drive_file,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: WanzoSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _attachmentPath!.split('/').last,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              'Fichier sélectionné',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.copyWith(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            _attachmentPath = null;
                                          });
                                        },
                                        tooltip: 'Supprimer la pièce jointe',
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                    ],
                                  ),
                                ),
                              if (_attachmentPath != null ||
                                  _attachmentPath == null) ...[
                                const SizedBox(height: WanzoSpacing.sm),
                                Text(
                                  "Formats acceptés: facture, devis, lettre d'intention, projet, etc.",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: WanzoSpacing.xl),

                      // Bouton de soumission avec style Wanzo
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => _submitRequest(currentCurrency),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                WanzoRadius.sm,
                              ),
                            ),
                          ),
                          child: BlocBuilder<FinancingBloc, FinancingState>(
                            builder: (context, financingBlocState) {
                              if (financingBlocState is FinancingLoading) {
                                return const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                );
                              }
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send, size: 20),
                                  const SizedBox(width: WanzoSpacing.sm),
                                  Text(
                                    'Soumettre la Demande',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              );
                            },
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

  Future<void> _pickAttachment() async {
    try {
      final File? pickedFile = await _imagePickerService.pickFromGallery(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      // Check if the widget is still mounted before using setState
      if (!mounted) return;

      if (pickedFile != null) {
        setState(() {
          _attachmentPath = pickedFile.path;
        });
      }
    } catch (e) {
      // Check if the widget is still mounted before using context
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection du fichier: $e')),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}
