import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/core/widgets/desktop/responsive_form_container.dart';
import 'package:wanzo/core/platform/platform_service.dart';
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
        child: ResponsiveFormContainer(
          maxWidth: 900,
          child: _buildFormContent(context, l10n),
        ),
      ),
    );
  }

  Widget _buildFormContent(BuildContext context, AppLocalizations l10n) {
    final screenWidth = MediaQuery.of(context).size.width;
    final platform = PlatformService.instance;
    final isDesktop = screenWidth >= platform.desktopMinWidth;
    final isTablet = screenWidth >= platform.tabletMinWidth && !isDesktop;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header responsive
        ResponsiveFormHeader(
          title: l10n.appearanceAndDisplay,
          subtitle: 'Personnalisez l\'apparence de l\'application',
          icon: Icons.palette,
        ),

        // Disposition en grille pour desktop/tablet
        if (isDesktop || isTablet)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colonne Thème
              Expanded(child: _buildThemeSection(l10n)),
              const SizedBox(width: 24),
              // Colonne Langue
              Expanded(child: _buildLanguageSection(l10n)),
            ],
          )
        else ...[
          _buildThemeSection(l10n),
          const SizedBox(height: 24),
          _buildLanguageSection(l10n),
        ],

        const SizedBox(height: 24),

        // Format de date (pleine largeur)
        _buildDateFormatSection(l10n),
        const SizedBox(height: 32),

        // Bouton d'enregistrement
        if (_hasChanges)
          Center(
            child: SizedBox(
              width: isDesktop || isTablet ? 300 : double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: Text(l10n.saveChanges),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildThemeSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.theme,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              RadioListTile<AppThemeMode>(
                title: Text(l10n.themeLight),
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
                title: Text(l10n.themeDark),
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
                title: Text(l10n.themeSystem),
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
      ],
    );
  }

  Widget _buildLanguageSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.language,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              RadioListTile<String>(
                title: Text(l10n.languageFrench),
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
                title: Text(l10n.languageEnglish),
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
                title: Text(l10n.languageSwahili),
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
      ],
    );
  }

  Widget _buildDateFormatSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dateFormat,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              RadioListTile<String>(
                title: Text(l10n.dateFormatDDMMYYYY),
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
                title: Text(l10n.dateFormatMMDDYYYY),
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
                title: Text(l10n.dateFormatYYYYMMDD),
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
                title: Text(l10n.dateFormatDDMMMYYYY),
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
      ],
    );
  }

  /// Obtient un exemple de date formatée
  String _getFormattedDateExample(String format, AppLocalizations l10n) {
    final now = DateTime.now();

    final months = [
      '',
      l10n.monthJan,
      l10n.monthFeb,
      l10n.monthMar,
      l10n.monthApr,
      l10n.monthMay,
      l10n.monthJun,
      l10n.monthJul,
      l10n.monthAug,
      l10n.monthSep,
      l10n.monthOct,
      l10n.monthNov,
      l10n.monthDec,
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
    context.read<SettingsBloc>().add(
      UpdateDisplaySettings(
        themeMode: _themeMode,
        language: _language,
        dateFormat: _dateFormat,
      ),
    );
  }
}
