import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/l10n/app_localizations.dart'; // Import AppLocalizations
import 'package:wanzo/core/widgets/desktop/responsive_form_container.dart';
import 'package:wanzo/core/platform/platform_service.dart';
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
  State<InventorySettingsScreen> createState() =>
      _InventorySettingsScreenState();
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
    _defaultCategoryController = TextEditingController(
      text: widget.settings.defaultProductCategory,
    );
    _lowStockDaysController = TextEditingController(
      text: widget.settings.lowStockAlertDays.toString(),
    );

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
        _defaultCategoryController.text !=
            widget.settings.defaultProductCategory ||
        _lowStockDaysController.text !=
            widget.settings.lowStockAlertDays.toString();

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
              tooltip:
                  l10n.saveChanges, // Corrected: Localized string for "Save Changes"
            ),
        ],
      ),
      body: BlocListener<SettingsBloc, SettingsState>(
        listener: (context, state) {
          if (state is SettingsUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.settingsUpdatedSuccessfully),
              ), // Localized success message
            );
            if (mounted) {
              // Add mounted check
              setState(() {
                _hasChanges = false;
              });
            }
          } else if (state is SettingsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n.errorUpdatingSettings,
                ), // Localized error message
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: _buildFormContent(context, l10n),
      ),
    );
  }

  Widget _buildFormContent(BuildContext context, AppLocalizations l10n) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= PlatformService.instance.desktopMinWidth;
    final isTablet =
        screenWidth >= PlatformService.instance.tabletMinWidth &&
        screenWidth < PlatformService.instance.desktopMinWidth;

    return ResponsiveFormContainer(
      maxWidth: 800,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête principal
            ResponsiveFormHeader(
              title: l10n.inventorySettings,
              subtitle: l10n.generalSettings,
              icon: Icons.inventory_2,
            ),
            const SizedBox(height: 24),

            // Section paramètres généraux
            _buildGeneralSettingsSection(context, l10n, isDesktop, isTablet),

            const SizedBox(height: 32),

            // Section alertes de stock
            _buildStockAlertsSection(context, l10n, isDesktop, isTablet),

            const SizedBox(height: 32),

            // Bouton d'enregistrement
            if (_hasChanges)
              Center(
                child: SizedBox(
                  width: isDesktop ? 300 : (isTablet ? 250 : double.infinity),
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: Text(l10n.saveChanges),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettingsSection(
    BuildContext context,
    AppLocalizations l10n,
    bool isDesktop,
    bool isTablet,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.category,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.generalSettings,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Catégorie par défaut
            SizedBox(
              width: isDesktop || isTablet ? 400 : double.infinity,
              child: TextFormField(
                controller: _defaultCategoryController,
                decoration: InputDecoration(
                  labelText: l10n.defaultProductCategory,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.defaultCategoryRequired;
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockAlertsSection(
    BuildContext context,
    AppLocalizations l10n,
    bool isDesktop,
    bool isTablet,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Text(
                  l10n.stockAlerts,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Jours pour alerte de stock bas
            SizedBox(
              width: isDesktop || isTablet ? 300 : double.infinity,
              child: TextFormField(
                controller: _lowStockDaysController,
                decoration: InputDecoration(
                  labelText: l10n.lowStockAlertDays,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.timer),
                  hintText: l10n.lowStockAlertHint,
                  suffixText: l10n.days,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.fieldRequired;
                  }
                  try {
                    final days = int.parse(value);
                    if (days < 1) {
                      return l10n.minValue(1);
                    }
                    if (days > 90) {
                      return l10n.maxValue(90);
                    }
                  } catch (_) {
                    return l10n.enterValidNumber;
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.lowStockAlertDescription,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

      context.read<SettingsBloc>().add(
        UpdateInventorySettings(
          defaultProductCategory: _defaultCategoryController.text.trim(),
          lowStockAlertDays: lowStockDays,
        ),
      );
    }
  }
}
