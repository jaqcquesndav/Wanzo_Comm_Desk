import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import '../../../core/platform/image_picker/image_picker_service_factory.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../models/settings.dart';

/// Écran de paramètres pour les informations de l'entreprise avec gestion Business Unit
class CompanySettingsScreen extends StatefulWidget {
  /// Paramètres actuels
  final Settings settings;

  const CompanySettingsScreen({super.key, required this.settings});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _formKeyCompany = GlobalKey<FormState>();
  late final TextEditingController _companyNameController;
  late final TextEditingController _companyAddressController;
  late final TextEditingController _companyPhoneController;
  late final TextEditingController _companyEmailController;
  late final TextEditingController _taxNumberController;
  late final TextEditingController _rccmNumberController;
  late final TextEditingController _idNatNumberController;
  late final TextEditingController _businessUnitCodeController;

  String? _companyLogo;
  late BusinessUnitType _businessUnitType;
  String? _businessUnitId;
  String? _businessUnitName;
  bool _hasChanges = false;
  bool _showCodeConfigSection = false;

  @override
  void initState() {
    super.initState();

    // Initialise les contrôleurs avec les valeurs actuelles
    _companyNameController = TextEditingController(
      text: widget.settings.companyName,
    );
    _companyAddressController = TextEditingController(
      text: widget.settings.companyAddress,
    );
    _companyPhoneController = TextEditingController(
      text: widget.settings.companyPhone,
    );
    _companyEmailController = TextEditingController(
      text: widget.settings.companyEmail,
    );
    _taxNumberController = TextEditingController(
      text: widget.settings.taxIdentificationNumber,
    );
    _rccmNumberController = TextEditingController(
      text: widget.settings.rccmNumber,
    );
    _idNatNumberController = TextEditingController(
      text: widget.settings.idNatNumber,
    );
    _businessUnitCodeController = TextEditingController(
      text: widget.settings.businessUnitCode ?? '',
    );

    _companyLogo = widget.settings.companyLogo;
    _businessUnitType = widget.settings.businessUnitType;
    _businessUnitId = widget.settings.businessUnitId;
    _businessUnitName = widget.settings.businessUnitName;

    // Écouteurs pour détecter les changements
    _companyNameController.addListener(_onFieldChanged);
    _companyAddressController.addListener(_onFieldChanged);
    _companyPhoneController.addListener(_onFieldChanged);
    _companyEmailController.addListener(_onFieldChanged);
    _taxNumberController.addListener(_onFieldChanged);
    _rccmNumberController.addListener(_onFieldChanged);
    _idNatNumberController.addListener(_onFieldChanged);
    _businessUnitCodeController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _taxNumberController.dispose();
    _rccmNumberController.dispose();
    _idNatNumberController.dispose();
    _businessUnitCodeController.dispose();
    super.dispose();
  }

  /// Détecte les changements dans les champs
  void _onFieldChanged() {
    final hasChanges =
        _companyNameController.text != widget.settings.companyName ||
        _companyAddressController.text != widget.settings.companyAddress ||
        _companyPhoneController.text != widget.settings.companyPhone ||
        _companyEmailController.text != widget.settings.companyEmail ||
        _taxNumberController.text != widget.settings.taxIdentificationNumber ||
        _rccmNumberController.text != widget.settings.rccmNumber ||
        _idNatNumberController.text != widget.settings.idNatNumber ||
        _companyLogo != widget.settings.companyLogo ||
        _businessUnitType != widget.settings.businessUnitType ||
        _businessUnitCodeController.text !=
            (widget.settings.businessUnitCode ?? '');

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
        title: Text(l10n.companyInformation),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: l10n.saveChanges,
            ),
        ],
      ),
      body: BlocListener<SettingsBloc, SettingsState>(
        listener: (context, state) {
          if (state is SettingsUpdated) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.changesSaved)));
            setState(() {
              _hasChanges = false;
            });
          } else if (state is SettingsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.errorSavingChanges),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKeyCompany,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicateur Business Unit actuelle
                _buildCurrentBusinessUnitIndicator(context, l10n),
                const SizedBox(height: 16),

                // Logo de l'entreprise
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                          image:
                              _companyLogo != null && _companyLogo!.isNotEmpty
                                  ? DecorationImage(
                                    image: _getImageProvider(_companyLogo!),
                                    fit: BoxFit.cover,
                                  )
                                  : null,
                        ),
                        child:
                            _companyLogo == null || _companyLogo!.isEmpty
                                ? Icon(
                                  _getIconForUnitType(_businessUnitType),
                                  size: 60,
                                  color: Colors.grey,
                                )
                                : null,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _selectLogo(l10n),
                        icon: const Icon(Icons.add_photo_alternate),
                        label: Text(l10n.changeLogo),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Nom de l'entreprise
                TextFormField(
                  controller: _companyNameController,
                  decoration: InputDecoration(
                    labelText: '${l10n.companyName} *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.business),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.companyNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Adresse
                TextFormField(
                  controller: _companyAddressController,
                  decoration: InputDecoration(
                    labelText: l10n.address,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Téléphone
                TextFormField(
                  controller: _companyPhoneController,
                  decoration: InputDecoration(
                    labelText: l10n.phoneNumber,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _companyEmailController,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final emailRegex = RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      );
                      if (!emailRegex.hasMatch(value)) {
                        return l10n.invalidEmail;
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Numéro d'identification fiscale
                TextFormField(
                  controller: _taxNumberController,
                  decoration: InputDecoration(
                    labelText: l10n.taxIdentificationNumber,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.receipt),
                  ),
                ),
                const SizedBox(height: 16),

                // Numéro RCCM
                TextFormField(
                  controller: _rccmNumberController,
                  decoration: InputDecoration(
                    labelText: l10n.rccmNumber,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.book),
                    helperText: l10n.rccmHelperText,
                  ),
                ),
                const SizedBox(height: 16),

                // Numéro ID NAT
                TextFormField(
                  controller: _idNatNumberController,
                  decoration: InputDecoration(
                    labelText: l10n.idNatNumber,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.assignment_ind),
                    helperText: l10n.idNatHelperText,
                  ),
                ),
                const SizedBox(height: 24),

                // Section Business Unit
                _buildBusinessUnitSection(context, l10n),
                const SizedBox(height: 24),

                // Bouton d'enregistrement
                if (_hasChanges)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      child: Text(l10n.saveChanges),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construit l'indicateur de l'unité d'affaires actuelle
  Widget _buildCurrentBusinessUnitIndicator(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final isConfigured = _businessUnitId != null && _businessUnitId!.isNotEmpty;
    final unitTypeLabel = _businessUnitType.displayName(context);

    return Card(
      color:
          isConfigured
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              _getIconForUnitType(_businessUnitType),
              color:
                  isConfigured ? Theme.of(context).primaryColor : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConfigured
                        ? (_businessUnitName ?? unitTypeLabel)
                        : l10n.businessUnitDefaultCompany,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isConfigured
                        ? '${l10n.businessUnitCode}: ${widget.settings.businessUnitCode ?? "-"}'
                        : l10n.businessUnitDefaultDescription,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getColorForUnitType(_businessUnitType),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unitTypeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit la section de configuration Business Unit
  Widget _buildBusinessUnitSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.businessUnitConfiguration,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.businessUnitConfigurationDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Affichage du type actuel (lecture seule si configuré)
            if (_businessUnitId != null && _businessUnitId!.isNotEmpty) ...[
              _buildReadOnlyUnitInfo(context, l10n),
            ] else ...[
              // Mode entreprise par défaut
              _buildDefaultCompanyMode(context, l10n),

              // Option pour configurer via code
              const SizedBox(height: 16),
              _buildCodeConfigurationOption(context, l10n),
            ],
          ],
        ),
      ),
    );
  }

  /// Affiche les informations de l'unité en lecture seule
  Widget _buildReadOnlyUnitInfo(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.businessUnitConfigured,
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.qr_code,
            l10n.businessUnitCode,
            widget.settings.businessUnitCode ?? '-',
          ),
          _buildInfoRow(
            Icons.category,
            l10n.businessUnitType,
            _businessUnitType.displayName(context),
          ),
          _buildInfoRow(
            Icons.badge,
            l10n.businessUnitName,
            _businessUnitName ?? '-',
          ),
          const SizedBox(height: 12),
          Text(
            l10n.businessUnitChangeInfo,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Mode entreprise par défaut
  Widget _buildDefaultCompanyMode(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          Icon(Icons.business_center, color: Colors.blue[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.businessUnitDefaultCompany,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.businessUnitDefaultCompanyDescription,
                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.businessUnitLevelDefault,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Option pour configurer via code
  Widget _buildCodeConfigurationOption(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _showCodeConfigSection = !_showCodeConfigSection;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.businessUnitConfigureByCode,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.businessUnitConfigureByCodeDescription,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showCodeConfigSection
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.orange[700],
                ),
              ],
            ),
          ),
        ),

        if (_showCodeConfigSection) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _businessUnitCodeController,
            decoration: InputDecoration(
              labelText: l10n.businessUnitCodeLabel,
              hintText: l10n.businessUnitCodeHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.qr_code),
              helperText: l10n.businessUnitCodeHelper,
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.businessUnitCodeInfo,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  /// Retourne l'icône appropriée pour le type d'unité
  IconData _getIconForUnitType(BusinessUnitType type) {
    switch (type) {
      case BusinessUnitType.company:
        return Icons.business_center;
      case BusinessUnitType.branch:
        return Icons.account_balance;
      case BusinessUnitType.pos:
        return Icons.storefront;
    }
  }

  /// Retourne la couleur appropriée pour le type d'unité
  Color _getColorForUnitType(BusinessUnitType type) {
    switch (type) {
      case BusinessUnitType.company:
        return Colors.blue[700]!;
      case BusinessUnitType.branch:
        return Colors.green[700]!;
      case BusinessUnitType.pos:
        return Colors.orange[700]!;
    }
  }

  /// Retourne le provider d'image approprié selon le chemin
  ImageProvider _getImageProvider(String imagePath) {
    if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    } else {
      return FileImage(File(imagePath));
    }
  }

  /// Sélectionne un logo depuis la galerie ou la caméra
  Future<void> _selectLogo(AppLocalizations l10n) async {
    final imagePickerService = ImagePickerServiceFactory.getInstance();

    try {
      final String? choice = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(l10n.selectImageSource),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: Text(l10n.gallery),
                    onTap: () {
                      Navigator.of(context).pop('gallery');
                    },
                  ),
                  if (imagePickerService.isCameraAvailable)
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: Text(l10n.camera),
                      onTap: () {
                        Navigator.of(context).pop('camera');
                      },
                    ),
                  if (_companyLogo != null && _companyLogo!.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: Text(l10n.deleteCurrentLogo),
                      onTap: () {
                        Navigator.of(context).pop('delete');
                      },
                    ),
                ],
              ),
            ),
          );
        },
      );

      if (!mounted) return;

      if (choice == 'delete') {
        setState(() {
          _companyLogo = '';
          _hasChanges = true;
        });
        _onFieldChanged();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.logoDeleted)));
        return;
      }

      if (choice == null) return;

      File? pickedFile;
      if (choice == 'gallery') {
        pickedFile = await imagePickerService.pickFromGallery(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 90,
        );
      } else if (choice == 'camera') {
        pickedFile = await imagePickerService.pickFromCamera(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 90,
        );
      }

      if (pickedFile == null) return;
      if (!mounted) return;

      final appDir = await getApplicationDocumentsDirectory();
      final companyLogosDir = Directory(
        path.join(appDir.path, 'company_logos'),
      );

      if (!await companyLogosDir.exists()) {
        await companyLogosDir.create(recursive: true);
      }

      final fileName =
          'company_logo_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedImagePath = path.join(companyLogosDir.path, fileName);

      await pickedFile.copy(savedImagePath);

      setState(() {
        _companyLogo = savedImagePath;
        _hasChanges = true;
      });
      _onFieldChanged();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.logoUpdatedSuccessfully)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorSelectingLogo(e.toString()))),
      );
    }
  }

  /// Enregistre les modifications
  void _saveSettings() {
    if (_formKeyCompany.currentState?.validate() ?? false) {
      final businessUnitCode = _businessUnitCodeController.text.trim();

      context.read<SettingsBloc>().add(
        UpdateCompanyInfo(
          companyName: _companyNameController.text.trim(),
          companyAddress: _companyAddressController.text.trim(),
          companyPhone: _companyPhoneController.text.trim(),
          companyEmail: _companyEmailController.text.trim(),
          companyLogo: _companyLogo,
          taxIdentificationNumber: _taxNumberController.text.trim(),
          rccmNumber: _rccmNumberController.text.trim(),
          idNatNumber: _idNatNumberController.text.trim(),
          businessUnitId: _businessUnitId,
          businessUnitCode:
              businessUnitCode.isNotEmpty ? businessUnitCode : null,
          businessUnitType: _businessUnitType,
          businessUnitName: _businessUnitName,
        ),
      );
    }
  }
}
