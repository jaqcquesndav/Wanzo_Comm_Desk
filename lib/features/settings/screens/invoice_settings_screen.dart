import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/core/models/currency_settings_model.dart';
import 'package:wanzo/features/settings/presentation/cubit/currency_settings_cubit.dart';
import 'package:wanzo/l10n/app_localizations.dart';

import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart' as old_settings_state;
import '../models/settings.dart';

class InvoiceSettingsScreen extends StatefulWidget {
  final Settings settings; // This is the old settings model, now without direct currency field

  const InvoiceSettingsScreen({super.key, required this.settings});

  @override
  State<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for old settings (invoice part)
  late TextEditingController _invoiceNumberFormatController;
  late TextEditingController _invoicePrefixController;
  late TextEditingController _paymentTermsController;
  late TextEditingController _invoiceNotesController;
  late TextEditingController _taxRateController;
  bool _showTaxes = true;

  // State for new currency settings
  Currency? _tempActiveCurrency;
  late TextEditingController _usdToCdfRateController;
  late TextEditingController _fcfaToCdfRateController;
  
  // To track initial values and detect changes
  Map<String, dynamic>? _initialOldSettingsValues;
  Map<String, dynamic>? _initialCurrencySettingsValues;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers for old settings
    _invoiceNumberFormatController = TextEditingController(text: widget.settings.invoiceNumberFormat);
    _invoicePrefixController = TextEditingController(text: widget.settings.invoicePrefix);
    _paymentTermsController = TextEditingController(text: widget.settings.defaultPaymentTerms);
    _invoiceNotesController = TextEditingController(text: widget.settings.defaultInvoiceNotes);
    _taxRateController = TextEditingController(text: widget.settings.defaultTaxRate.toString());
    _showTaxes = widget.settings.showTaxes;

    _initialOldSettingsValues = {
      'invoiceNumberFormat': widget.settings.invoiceNumberFormat,
      'invoicePrefix': widget.settings.invoicePrefix,
      'defaultPaymentTerms': widget.settings.defaultPaymentTerms,
      'defaultInvoiceNotes': widget.settings.defaultInvoiceNotes,
      'defaultTaxRate': widget.settings.defaultTaxRate,
      'showTaxes': widget.settings.showTaxes,
    };

    // Initialize controllers for new currency settings from Cubit
    final currencySettingsCubit = context.read<CurrencySettingsCubit>();
    final currentCurrencyState = currencySettingsCubit.state;

    _tempActiveCurrency = currentCurrencyState.settings.activeCurrency;
    _usdToCdfRateController = TextEditingController(text: currentCurrencyState.settings.usdToCdfRate.toString());
    _fcfaToCdfRateController = TextEditingController(text: currentCurrencyState.settings.fcfaToCdfRate.toString());
    
    _initialCurrencySettingsValues = {
      'activeCurrency': currentCurrencyState.settings.activeCurrency,
      'usdToCdfRate': currentCurrencyState.settings.usdToCdfRate,
      'fcfaToCdfRate': currentCurrencyState.settings.fcfaToCdfRate,
    };

    // Add listeners to detect changes
    _invoiceNumberFormatController.addListener(_onFieldChanged);
    _invoicePrefixController.addListener(_onFieldChanged);
    _paymentTermsController.addListener(_onFieldChanged);
    _invoiceNotesController.addListener(_onFieldChanged);
    _taxRateController.addListener(_onFieldChanged);
    _usdToCdfRateController.addListener(_onFieldChanged);
    _fcfaToCdfRateController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    bool oldSettingsChanged = false;
    if (_initialOldSettingsValues != null) {
        oldSettingsChanged = 
            _invoiceNumberFormatController.text != _initialOldSettingsValues!['invoiceNumberFormat'] ||
            _invoicePrefixController.text != _initialOldSettingsValues!['invoicePrefix'] ||
            _paymentTermsController.text != _initialOldSettingsValues!['defaultPaymentTerms'] ||
            _invoiceNotesController.text != _initialOldSettingsValues!['defaultInvoiceNotes'] ||
            (double.tryParse(_taxRateController.text) ?? 0.0) != _initialOldSettingsValues!['defaultTaxRate'] ||
            _showTaxes != _initialOldSettingsValues!['showTaxes'];
    }

    bool currencySettingsChanged = false;
    if (_initialCurrencySettingsValues != null) {
      currencySettingsChanged = 
          _tempActiveCurrency != _initialCurrencySettingsValues!['activeCurrency'] ||
          (double.tryParse(_usdToCdfRateController.text) ?? 0.0) != _initialCurrencySettingsValues!['usdToCdfRate'] ||
          (double.tryParse(_fcfaToCdfRateController.text) ?? 0.0) != _initialCurrencySettingsValues!['fcfaToCdfRate'];
    }

    if (mounted) {
      setState(() {
        _hasChanges = oldSettingsChanged || currencySettingsChanged;
      });
    }
  }
  
  void _saveSettings() {
    final l10n = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      // Save old invoice settings (excluding currency)
      final settingsBloc = context.read<SettingsBloc>();
      settingsBloc.add(
        UpdateInvoiceSettings( 
          invoiceNumberFormat: _invoiceNumberFormatController.text,
          invoicePrefix: _invoicePrefixController.text,
          defaultPaymentTerms: _paymentTermsController.text,
          defaultInvoiceNotes: _invoiceNotesController.text,
          showTaxes: _showTaxes,
          defaultTaxRate: double.tryParse(_taxRateController.text) ?? _initialOldSettingsValues!['defaultTaxRate'],
        ),
      );

      // Save new currency settings
      final currencySettingsCubit = context.read<CurrencySettingsCubit>();
      final newCurrencySettings = CurrencySettings(
        activeCurrency: _tempActiveCurrency!,
        usdToCdfRate: double.tryParse(_usdToCdfRateController.text) ?? 0.0,
        fcfaToCdfRate: double.tryParse(_fcfaToCdfRateController.text) ?? 0.0,
      );
      currencySettingsCubit.updateSettings(newCurrencySettings);

      // Update initial values to reflect saved state and reset _hasChanges
      _initialOldSettingsValues = {
        'invoiceNumberFormat': _invoiceNumberFormatController.text,
        'invoicePrefix': _invoicePrefixController.text,
        'defaultPaymentTerms': _paymentTermsController.text,
        'defaultInvoiceNotes': _invoiceNotesController.text,
        'defaultTaxRate': double.tryParse(_taxRateController.text) ?? _initialOldSettingsValues!['defaultTaxRate'],
        'showTaxes': _showTaxes,
      };
      _initialCurrencySettingsValues = {
        'activeCurrency': newCurrencySettings.activeCurrency,
        'usdToCdfRate': newCurrencySettings.usdToCdfRate,
        'fcfaToCdfRate': newCurrencySettings.fcfaToCdfRate,
      };
      
      if (mounted) {
        setState(() {
          _hasChanges = false;
        });
         ScaffoldMessenger.of(context).showSnackBar( // Show generic success message
          SnackBar(content: Text(l10n.settingsSavedSuccess)), // Localized
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // Use actual AppLocalizations

    return MultiBlocListener(
      listeners: [
        BlocListener<SettingsBloc, old_settings_state.SettingsState>(
          listener: (context, state) {
            if (state is old_settings_state.SettingsUpdated) {
              // Message is now shown in _saveSettings after both saves attempt
            } else if (state is old_settings_state.SettingsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message.isNotEmpty ? state.message : l10n.anErrorOccurred), backgroundColor: Colors.red), // Localized
              );
            }
          },
        ),
        BlocListener<CurrencySettingsCubit, CurrencySettingsState>(
          listener: (context, state) {
            if (state.status == CurrencySettingsStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.currencySettingsError(state.errorMessage ?? l10n.errorUnknown)), backgroundColor: Colors.red), // Localized
              );
            } else if (state.status == CurrencySettingsStatus.saved) { 
              // Message is now shown in _saveSettings after both saves attempt
               _tempActiveCurrency = state.settings.activeCurrency;
               _usdToCdfRateController.text = state.settings.usdToCdfRate.toString();
               _fcfaToCdfRateController.text = state.settings.fcfaToCdfRate.toString();
              _initialCurrencySettingsValues = {
                'activeCurrency': state.settings.activeCurrency,
                'usdToCdfRate': state.settings.usdToCdfRate,
                'fcfaToCdfRate': state.settings.fcfaToCdfRate,
              };
              _onFieldChanged(); // Re-evaluate changes
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.invoiceSettingsTitle), // Localized
          actions: [
            if (_hasChanges)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveSettings,
                tooltip: l10n.saveChanges, // Localized
              ),
          ],
        ),
        body: BlocBuilder<CurrencySettingsCubit, CurrencySettingsState>( // Listen to Currency cubit for loading state
            builder: (context, currencyState) {
          // Potentially show loading indicator based on currencyState.status
          if (currencyState.status == CurrencySettingsStatus.loading || currencyState.status == CurrencySettingsStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          // If state changed externally, update controllers (less common for this screen after initState)
          if (_tempActiveCurrency != currencyState.settings.activeCurrency) {
             _tempActiveCurrency = currencyState.settings.activeCurrency;
          }
          // Avoid direct text manipulation if controller is focused by user
          if (!_usdToCdfRateController.selection.isValid && _usdToCdfRateController.text != currencyState.settings.usdToCdfRate.toString()){
            _usdToCdfRateController.text = currencyState.settings.usdToCdfRate.toString();
          }
          if (!_fcfaToCdfRateController.selection.isValid && _fcfaToCdfRateController.text != currencyState.settings.fcfaToCdfRate.toString()){
             _fcfaToCdfRateController.text = currencyState.settings.fcfaToCdfRate.toString();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Currency Settings Section ---
                  Text(l10n.currencySettings, style: Theme.of(context).textTheme.titleLarge), // Localized
                  const SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<Currency>(
                            decoration: InputDecoration(
                              labelText: l10n.activeCurrency, // Localized
                              border: const OutlineInputBorder(),
                            ),
                            value: _tempActiveCurrency,
                            items: Currency.values.map((Currency currency) {
                              return DropdownMenuItem<Currency>(
                                value: currency,
                                child: Text(currency.displayName(context)), 
                              );
                            }).toList(),
                            onChanged: (Currency? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _tempActiveCurrency = newValue;
                                  _onFieldChanged();
                                });
                              }
                            },
                            validator: (value) => value == null ? l10n.errorFieldRequired : null, // Localized
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _usdToCdfRateController,
                            decoration: InputDecoration(
                              labelText: l10n.exchangeRateSpecific('USD', 'CDF'), // Localized
                              border: const OutlineInputBorder(),
                              hintText: l10n.exchangeRateHint('USD', 'CDF'), // Localized
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) return l10n.errorFieldRequired; // Localized
                              if (double.tryParse(value) == null || double.parse(value) <= 0) return l10n.errorInvalidRate; // Localized
                              return null;
                            },
                            onChanged: (_) => _onFieldChanged(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _fcfaToCdfRateController,
                            decoration: InputDecoration(
                              labelText: l10n.exchangeRateSpecific('FCFA', 'CDF'), // Localized
                              border: const OutlineInputBorder(),
                              hintText: l10n.exchangeRateHint('FCFA', 'CDF'), // Localized
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) return l10n.errorFieldRequired; // Localized
                              if (double.tryParse(value) == null || double.parse(value) <= 0) return l10n.errorInvalidRate; // Localized
                              return null;
                            },
                            onChanged: (_) => _onFieldChanged(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Invoice Formatting Section ---
                  Text(l10n.invoiceFormatting, style: Theme.of(context).textTheme.titleLarge), // Localized
                  const SizedBox(height: 4),
                  Text(l10n.invoiceFormatHint('YEAR', 'MONTH', 'SEQ'), style: Theme.of(context).textTheme.bodySmall), // Localized
                  const SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _invoiceNumberFormatController,
                            decoration: InputDecoration(labelText: l10n.invoiceNumberFormat, border: const OutlineInputBorder()), // Localized
                            onChanged: (_) => _onFieldChanged(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _invoicePrefixController,
                            decoration: InputDecoration(labelText: l10n.invoicePrefix, border: const OutlineInputBorder()), // Localized
                            onChanged: (_) => _onFieldChanged(),
                          ),
                        ], 
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Taxes and Conditions Section ---
                  Text(l10n.taxesAndConditions, style: Theme.of(context).textTheme.titleLarge), // Localized
                  const SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: Text(l10n.showTaxesOnInvoices), // Localized
                            value: _showTaxes,
                            onChanged: (value) {
                              setState(() {
                                _showTaxes = value;
                                _onFieldChanged();
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _taxRateController,
                            decoration: InputDecoration(labelText: l10n.defaultTaxRatePercentage, border: const OutlineInputBorder()), // Localized
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            enabled: _showTaxes,
                            validator: (value) {
                              if (_showTaxes) {
                                if (value == null || value.isEmpty) return l10n.errorFieldRequired; // Localized
                                final rate = double.tryParse(value);
                                if (rate == null || rate < 0 || rate > 100) return l10n.errorInvalidTaxRate; // Localized
                              }
                              return null;
                            },
                            onChanged: (_) => _onFieldChanged(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _paymentTermsController,
                            decoration: InputDecoration(labelText: l10n.defaultPaymentTerms, border: const OutlineInputBorder()), // Localized
                            maxLines: 2,
                            onChanged: (_) => _onFieldChanged(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _invoiceNotesController,
                            decoration: InputDecoration(labelText: l10n.defaultInvoiceNotes, border: const OutlineInputBorder()), // Localized
                            maxLines: 3,
                            onChanged: (_) => _onFieldChanged(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Save Button ---
                  if (_hasChanges)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(l10n.saveChanges), // Localized
                      ),
                    ),
                  const SizedBox(height: 20), // For bottom padding
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    _invoiceNumberFormatController.dispose();
    _invoicePrefixController.dispose();
    _paymentTermsController.dispose();
    _invoiceNotesController.dispose();
    _taxRateController.dispose();
    _usdToCdfRateController.dispose();
    _fcfaToCdfRateController.dispose();
    super.dispose();
  }
}
