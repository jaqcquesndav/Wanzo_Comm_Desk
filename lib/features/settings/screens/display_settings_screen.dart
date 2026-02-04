import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../models/settings.dart';

/// Écran des paramètres d'affichage
class DisplaySettingsScreen extends StatefulWidget {
  /// Paramètres actuels
  final Settings settings;

  const DisplaySettingsScreen({super.key, required this.settings});

  @override
  State<DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

class _DisplaySettingsScreenState extends State<DisplaySettingsScreen> {
  AppThemeMode _themeMode = AppThemeMode.system;
  String _language = 'fr';
  String _dateFormat = 'DD/MM/YYYY';
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    
    // Initialise les valeurs avec les paramètres actuels
    _themeMode = widget.settings.themeMode;
    _language = widget.settings.language;
    _dateFormat = widget.settings.dateFormat;
  }
  
  /// Vérifie si des changements ont été effectués
  void _checkChanges() {
    final hasChanges = 
        _themeMode != widget.settings.themeMode ||
        _language != widget.settings.language ||
        _dateFormat != widget.settings.dateFormat;
    
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appearanceAndDisplay), // Localized
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: l10n.saveChanges, // Corrected to saveChanges
            ),
        ],
      ),
      body: BlocListener<SettingsBloc, SettingsState>(
        listener: (context, state) {
          if (state is SettingsUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.changesSaved)), // Localized
            );
            setState(() {
              _hasChanges = false;
            });
          } else if (state is SettingsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.errorSavingChanges), // Localized
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.theme, // Localized
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Sélection du thème
              Card(
                child: Column(
                  children: [
                    RadioListTile<AppThemeMode>(
                      title: Text(l10n.themeLight), // Localized
                      value: AppThemeMode.light,
                      groupValue: _themeMode,
                      onChanged: (value) {
                        setState(() {
                          _themeMode = AppThemeMode.light;
                          _checkChanges();
                        });
                      },
                      secondary: const Icon(Icons.light_mode),
                    ),
                    RadioListTile<AppThemeMode>(
                      title: Text(l10n.themeDark), // Localized
                      value: AppThemeMode.dark,
                      groupValue: _themeMode,
                      onChanged: (value) {
                        setState(() {
                          _themeMode = AppThemeMode.dark;
                          _checkChanges();
                        });
                      },
                      secondary: const Icon(Icons.dark_mode),
                    ),
                    RadioListTile<AppThemeMode>(
                      title: Text(l10n.themeSystem), // Localized
                      value: AppThemeMode.system,
                      groupValue: _themeMode,
                      onChanged: (value) {
                        setState(() {
                          _themeMode = AppThemeMode.system;
                          _checkChanges();
                        });
                      },
                      secondary: const Icon(Icons.brightness_auto),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                l10n.language, // Localized
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Sélection de la langue
              Card(
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Text(l10n.languageFrench), // Localized
                      value: 'fr',
                      groupValue: _language,
                      onChanged: (value) {
                        setState(() {
                          _language = 'fr';
                          _checkChanges();
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text(l10n.languageEnglish), // Localized
                      value: 'en',
                      groupValue: _language,
                      onChanged: (value) {
                        setState(() {
                          _language = 'en';
                          _checkChanges();
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text(l10n.languageSwahili), // Localized
                      value: 'sw',
                      groupValue: _language,
                      onChanged: (value) {
                        setState(() {
                          _language = 'sw';
                          _checkChanges();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                l10n.dateFormat, // Localized
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Sélection du format de date
              Card(
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Text(l10n.dateFormatDDMMYYYY), // Localized
                      subtitle: Text(_getFormattedDateExample('DD/MM/YYYY', l10n)),
                      value: 'DD/MM/YYYY',
                      groupValue: _dateFormat,
                      onChanged: (value) {
                        setState(() {
                          _dateFormat = 'DD/MM/YYYY';
                          _checkChanges();
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text(l10n.dateFormatMMDDYYYY), // Localized
                      subtitle: Text(_getFormattedDateExample('MM/DD/YYYY', l10n)),
                      value: 'MM/DD/YYYY',
                      groupValue: _dateFormat,
                      onChanged: (value) {
                        setState(() {
                          _dateFormat = 'MM/DD/YYYY';
                          _checkChanges();
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text(l10n.dateFormatYYYYMMDD), // Localized
                      subtitle: Text(_getFormattedDateExample('YYYY-MM-DD', l10n)),
                      value: 'YYYY-MM-DD',
                      groupValue: _dateFormat,
                      onChanged: (value) {
                        setState(() {
                          _dateFormat = 'YYYY-MM-DD';
                          _checkChanges();
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text(l10n.dateFormatDDMMMYYYY), // Localized
                      subtitle: Text(_getFormattedDateExample('DD MMM YYYY', l10n)),
                      value: 'DD MMM YYYY',
                      groupValue: _dateFormat,
                      onChanged: (value) {
                        setState(() {
                          _dateFormat = 'DD MMM YYYY';
                          _checkChanges();
                        });
                      },
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
                    child: Text(l10n.saveChanges), // Localized
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Obtient un exemple de date formatée
  String _getFormattedDateExample(String format, AppLocalizations l10n) {
    final now = DateTime.now();
    
    final months = [
      '', 
      l10n.monthJan, l10n.monthFeb, l10n.monthMar, l10n.monthApr, 
      l10n.monthMay, l10n.monthJun, l10n.monthJul, l10n.monthAug, 
      l10n.monthSep, l10n.monthOct, l10n.monthNov, l10n.monthDec
    ];

    switch (format) {
      case 'DD/MM/YYYY':
        return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      case 'MM/DD/YYYY':
        return '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';
      case 'YYYY-MM-DD':
        return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      case 'DD MMM YYYY':
        return '${now.day.toString().padLeft(2, '0')} ${months[now.month]} ${now.year}';
      default:
        return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    }
  }

  /// Enregistre les modifications
  void _saveSettings() {
    context.read<SettingsBloc>().add(UpdateDisplaySettings(
      themeMode: _themeMode,
      language: _language,
      dateFormat: _dateFormat,
    ));
  }
}
