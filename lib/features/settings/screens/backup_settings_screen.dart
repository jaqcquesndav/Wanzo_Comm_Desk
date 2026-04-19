import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/core/widgets/desktop/responsive_form_container.dart';
import 'package:wanzo/core/platform/platform_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../models/settings.dart';
import 'package:wanzo/services/import/csv_import_service.dart';
import 'package:wanzo/features/inventory/bloc/inventory_bloc.dart';
import 'package:wanzo/features/inventory/bloc/inventory_event.dart';

/// Écran des paramètres de sauvegarde et rapports
class BackupSettingsScreen extends StatefulWidget {
  /// Paramètres actuels
  final Settings settings;

  const BackupSettingsScreen({super.key, required this.settings});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _backupFrequencyController;
  late final TextEditingController _reportEmailController;

  bool _backupEnabled = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();

    // Initialise les contrôleurs avec les valeurs actuelles
    _backupFrequencyController = TextEditingController(
      text: widget.settings.backupFrequency.toString(),
    );
    _reportEmailController = TextEditingController(
      text: widget.settings.reportEmail,
    );

    _backupEnabled = widget.settings.backupEnabled;

    // Écouteurs pour détecter les changements
    _backupFrequencyController.addListener(_onFieldChanged);
    _reportEmailController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _backupFrequencyController.dispose();
    _reportEmailController.dispose();
    super.dispose();
  }

  /// Détecte les changements dans les champs
  void _onFieldChanged() {
    final hasChanges =
        _backupEnabled != widget.settings.backupEnabled ||
        _backupFrequencyController.text !=
            widget.settings.backupFrequency.toString() ||
        _reportEmailController.text != widget.settings.reportEmail;

    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sauvegarde et rapports'),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: 'Enregistrer',
            ),
        ],
      ),
      body: BlocListener<SettingsBloc, SettingsState>(
        listener: (context, state) {
          if (state is SettingsUpdated) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
            setState(() {
              _hasChanges = false;
            });
          } else if (state is SettingsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: _buildFormContent(context),
      ),
    );
  }

  Widget _buildFormContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= PlatformService.instance.desktopMinWidth;
    final isTablet =
        screenWidth >= PlatformService.instance.tabletMinWidth &&
        screenWidth < PlatformService.instance.desktopMinWidth;

    return ResponsiveFormContainer(
      maxWidth: 900,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête principal
            ResponsiveFormHeader(
              title: 'Sauvegarde et rapports',
              subtitle: 'Gérez vos sauvegardes et rapports automatiques',
              icon: Icons.backup,
            ),
            const SizedBox(height: 24),

            // Layout côte à côte sur desktop, empilé sur mobile
            if (isDesktop || isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildBackupSection(context, isDesktop, isTablet),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildReportsSection(context, isDesktop, isTablet),
                  ),
                ],
              )
            else ...[
              _buildBackupSection(context, isDesktop, isTablet),
              const SizedBox(height: 24),
              _buildReportsSection(context, isDesktop, isTablet),
            ],

            const SizedBox(height: 32),

            // Section actions manuelles
            _buildManualActionsSection(context),

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
                    label: const Text('Enregistrer les modifications'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupSection(
    BuildContext context,
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
                  Icons.backup,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Sauvegarde automatique',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Activer la sauvegarde automatique
            SwitchListTile(
              title: const Text('Activer la sauvegarde'),
              subtitle: const Text('Sauvegarde périodique de vos données'),
              value: _backupEnabled,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setState(() {
                  _backupEnabled = value;
                  _hasChanges = true;
                });
              },
            ),
            const SizedBox(height: 16),

            // Fréquence de sauvegarde
            TextFormField(
              controller: _backupFrequencyController,
              decoration: const InputDecoration(
                labelText: 'Fréquence (jours)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
                suffixText: 'jours',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (_backupEnabled) {
                  if (value == null || value.isEmpty) {
                    return 'Ce champ est obligatoire';
                  }
                  try {
                    final days = int.parse(value);
                    if (days < 1) {
                      return 'Minimum 1 jour requis';
                    }
                    if (days > 90) {
                      return 'Maximum 90 jours autorisés';
                    }
                  } catch (_) {
                    return 'Veuillez entrer un nombre valide';
                  }
                }
                return null;
              },
              enabled: _backupEnabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsSection(
    BuildContext context,
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
                Icon(Icons.analytics, color: Colors.teal, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Rapports automatiques',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Email pour les rapports
            TextFormField(
              controller: _reportEmailController,
              decoration: const InputDecoration(
                labelText: 'Email pour les rapports',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
                hintText: 'Laissez vide pour désactiver',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final emailRegex = RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  );
                  if (!emailRegex.hasMatch(value)) {
                    return 'Veuillez entrer un email valide';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.teal.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recevez des rapports périodiques sur l\'état de votre entreprise par email.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.teal.shade900,
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

  Widget _buildManualActionsSection(BuildContext context) {
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
                  Icons.touch_app,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Actions manuelles',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grid d'actions sur desktop
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildActionCard(
                  context,
                  icon: Icons.backup,
                  title: 'Sauvegarder',
                  subtitle: 'Créer une sauvegarde manuelle',
                  onTap: _backupNow,
                  color: Colors.blue,
                ),
                _buildActionCard(
                  context,
                  icon: Icons.restore,
                  title: 'Restaurer',
                  subtitle: 'Restaurer une sauvegarde',
                  onTap: _restoreBackup,
                  color: Colors.orange,
                ),
                _buildActionCard(
                  context,
                  icon: Icons.import_export,
                  title: 'Exporter',
                  subtitle: 'Exporter en CSV/Excel',
                  onTap: _exportData,
                  color: Colors.green,
                ),
                _buildActionCard(
                  context,
                  icon: Icons.file_upload_outlined,
                  title: 'Importer CSV',
                  subtitle: 'Importer des produits',
                  onTap: () => _handleCsvImport(context),
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// Enregistre les modifications
  void _saveSettings() {
    if (_formKey.currentState?.validate() ?? false) {
      int backupFrequency;
      try {
        backupFrequency = int.parse(_backupFrequencyController.text);
      } catch (_) {
        backupFrequency = widget.settings.backupFrequency;
      }

      context.read<SettingsBloc>().add(
        UpdateBackupSettings(
          backupEnabled: _backupEnabled,
          backupFrequency: backupFrequency,
          reportEmail: _reportEmailController.text.trim(),
        ),
      );
    }
  }

  /// Effectue une sauvegarde immédiate
  void _backupNow() {
    // TODO: Implémenter la sauvegarde manuelle
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité à implémenter')),
    );
  }

  /// Restaure une sauvegarde
  void _restoreBackup() {
    // TODO: Implémenter la restauration de sauvegarde
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité à implémenter')),
    );
  }

  /// Exporte les données
  void _exportData() {
    // TODO: Implémenter l'exportation de données
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité à implémenter')),
    );
  }

  /// Gère l'import CSV de produits
  Future<void> _handleCsvImport(BuildContext context) async {
    final result = await CsvImportService.pickAndParseCSV(context);
    if (result == null || !mounted) return;

    if (result.products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.errors.isNotEmpty
                ? result.errors.first
                : 'Aucun produit trouvé dans le fichier',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirmer l\'import'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.successCount} produits prêts à importer sur ${result.totalRows} lignes.',
                ),
                if (result.errors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${result.errors.length} erreur(s):',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ...result.errors
                      .take(5)
                      .map(
                        (e) => Text(e, style: const TextStyle(fontSize: 12)),
                      ),
                  if (result.errors.length > 5)
                    Text(
                      '... et ${result.errors.length - 5} autres',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Importer'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      for (final product in result.products) {
        context.read<InventoryBloc>().add(AddProduct(product));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.products.length} produits importés avec succès',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
