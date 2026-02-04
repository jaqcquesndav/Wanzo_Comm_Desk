import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/l10n/app_localizations.dart'; // Import AppLocalizations
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../models/settings.dart';

/// Écran des paramètres d'inventaire
class InventorySettingsScreen extends StatefulWidget {
  /// Paramètres actuels
  final Settings settings;

  const InventorySettingsScreen({super.key, required this.settings});

  @override
  State<InventorySettingsScreen> createState() => _InventorySettingsScreenState();
}

class _InventorySettingsScreenState extends State<InventorySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _defaultCategoryController;
  late final TextEditingController _lowStockDaysController;
  
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    
    // Initialise les contrôleurs avec les valeurs actuelles
    _defaultCategoryController = TextEditingController(text: widget.settings.defaultProductCategory);
    _lowStockDaysController = TextEditingController(text: widget.settings.lowStockAlertDays.toString());
    
    // Écouteurs pour détecter les changements
    _defaultCategoryController.addListener(_onFieldChanged);
    _lowStockDaysController.addListener(_onFieldChanged);
  }
  
  @override
  void dispose() {
    _defaultCategoryController.dispose();
    _lowStockDaysController.dispose();
    super.dispose();
  }
  
  /// Détecte les changements dans les champs
  void _onFieldChanged() {
    final hasChanges = 
        _defaultCategoryController.text != widget.settings.defaultProductCategory ||
        _lowStockDaysController.text != widget.settings.lowStockAlertDays.toString();
    
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // Get AppLocalizations instance

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inventorySettings), // Localized string
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: l10n.saveChanges, // Corrected: Localized string for "Save Changes"
            ),
        ],
      ),
      body: BlocListener<SettingsBloc, SettingsState>(
        listener: (context, state) {
          if (state is SettingsUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.settingsUpdatedSuccessfully)), // Localized success message
            );
            if (mounted) { // Add mounted check
              setState(() {
                _hasChanges = false;
              });
            }
          } else if (state is SettingsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.errorUpdatingSettings), // Localized error message
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.generalSettings, // Localized string
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Catégorie par défaut
                TextFormField(
                  controller: _defaultCategoryController,
                  decoration: InputDecoration(
                    labelText: l10n.defaultProductCategory, // Localized string
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.defaultCategoryRequired; // Localized string
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                const Divider(),
                const SizedBox(height: 16),
                
                Text(
                  l10n.stockAlerts, // Localized string
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Jours pour alerte de stock bas
                TextFormField(
                  controller: _lowStockDaysController,
                  decoration: InputDecoration(
                    labelText: l10n.lowStockAlertDays, // Localized string
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.warning),
                    hintText: l10n.lowStockAlertHint, // Localized string
                    suffixText: l10n.days, // Localized string
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.fieldRequired; // Localized string
                    }
                    try {
                      final days = int.parse(value);
                      if (days < 1) {
                        return l10n.minValue(1); // Localized string
                      }
                      if (days > 90) {
                        return l10n.maxValue(90); // Localized string
                      }
                    } catch (_) {
                      return l10n.enterValidNumber; // Localized string
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    l10n.lowStockAlertDescription, // Localized string
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Bouton d'enregistrement
                if (_hasChanges)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      child: Text(l10n.saveChanges), // Localized string
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Enregistre les modifications
  void _saveSettings() {
    if (_formKey.currentState?.validate() ?? false) {
      int lowStockDays;
      try {
        lowStockDays = int.parse(_lowStockDaysController.text);
      } catch (_) {
        lowStockDays = widget.settings.lowStockAlertDays; 
      }
      
      context.read<SettingsBloc>().add(UpdateInventorySettings(
        defaultProductCategory: _defaultCategoryController.text.trim(),
        lowStockAlertDays: lowStockDays,
      ));
    }
  }
}
