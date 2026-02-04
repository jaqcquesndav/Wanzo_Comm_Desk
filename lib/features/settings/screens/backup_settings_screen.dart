import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../models/settings.dart';

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
    _reportEmailController = TextEditingController(text: widget.settings.reportEmail);
    
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
        _backupFrequencyController.text != widget.settings.backupFrequency.toString() ||
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paramètres de sauvegarde automatique',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Activer la sauvegarde automatique
                SwitchListTile(
                  title: const Text('Activer la sauvegarde automatique'),
                  subtitle: const Text('Sauvegarde périodique de vos données'),
                  value: _backupEnabled,
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
                    labelText: 'Fréquence de sauvegarde (jours)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timer),
                    suffixText: 'jours',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
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
                const SizedBox(height: 16),
                
                const Divider(),
                const SizedBox(height: 16),
                
                const Text(
                  'Rapports automatiques',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Email pour les rapports
                TextFormField(
                  controller: _reportEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email pour les rapports (optionnel)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                    hintText: 'Laissez vide pour désactiver',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value)) {
                        return 'Veuillez entrer un email valide';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Si vous spécifiez une adresse email, des rapports périodiques sur l\'état de votre entreprise vous seront envoyés.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Actions de sauvegarde manuelle
                const Text(
                  'Actions manuelles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.backup, size: 36),
                        title: const Text('Sauvegarder maintenant'),
                        subtitle: const Text('Créer une sauvegarde manuelle de vos données'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: _backupNow,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.restore, size: 36),
                        title: const Text('Restaurer une sauvegarde'),
                        subtitle: const Text('Restaurer vos données à partir d\'une sauvegarde'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: _restoreBackup,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.import_export, size: 36),
                        title: const Text('Exporter les données'),
                        subtitle: const Text('Exporter en format CSV ou Excel'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: _exportData,
                      ),
                    ],
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
                      child: const Text('Enregistrer les modifications'),
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
      int backupFrequency;
      try {
        backupFrequency = int.parse(_backupFrequencyController.text);
      } catch (_) {
        backupFrequency = widget.settings.backupFrequency;
      }
      
      context.read<SettingsBloc>().add(UpdateBackupSettings(
        backupEnabled: _backupEnabled,
        backupFrequency: backupFrequency,
        reportEmail: _reportEmailController.text.trim(),
      ));
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
}
