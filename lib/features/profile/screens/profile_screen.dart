import 'package:wanzo/core/utils/desktop_modal.dart';
import 'dart:io'; // Import for File type

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../utils/profile_image_crop.dart';
import '../../../core/platform/image_picker/image_picker_service_factory.dart';
import '../../../core/platform/image_picker/image_picker_service_interface.dart';
import '../../../core/services/entity_vocabulary_service.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/models/user.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../settings/bloc/settings_event.dart';
import '../../settings/bloc/settings_state.dart';
import 'edit_profile_screen.dart'; // Import EditProfileScreen

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImageFile;
  late final ImagePickerServiceInterface _imagePickerService;
  bool _settingsEnriched = false;

  @override
  void initState() {
    super.initState();
    _imagePickerService = ImagePickerServiceFactory.getInstance();
  }

  Future<void> _applyPickedImage(File? pickedFile) async {
    if (pickedFile == null || !mounted) return;
    final croppedFile = await cropProfileImage(
      pickedFile.path,
      toolbarColor: Theme.of(context).primaryColor,
    );
    if (croppedFile != null && mounted) {
      setState(() {
        _profileImageFile = croppedFile;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo de profil mise à jour localement.'),
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    final pickedFile = await _imagePickerService.pickFromGallery();
    await _applyPickedImage(pickedFile);
  }

  Future<void> _pickImageFromCamera() async {
    if (!_imagePickerService.isCameraAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La caméra n\'est pas disponible sur cette plateforme.',
            ),
          ),
        );
      }
      return;
    }
    final pickedFile = await _imagePickerService.pickFromCamera();
    await _applyPickedImage(pickedFile);
  }

  void _showImagePickerOptions(BuildContext context) {
    showDesktopModal(
        context,
        title: 'Choisir une photo',
        builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galerie'),
                onTap: () {
                  _pickImageFromGallery();
                  Navigator.of(context).pop();
                },
              ),
              if (_imagePickerService.isCameraAvailable)
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Appareil photo'),
                  onTap: () {
                    _pickImageFromCamera();
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
      );
  }

  /// Enrichit les Settings avec les données du User (une seule fois)
  void _enrichSettingsFromUser(BuildContext context, User user) {
    if (_settingsEnriched) return;
    _settingsEnriched = true;

    final settingsBloc = context.read<SettingsBloc>();
    final currentState = settingsBloc.state;

    // Si les settings n'ont pas de companyName mais le user en a un, enrichir
    if (currentState is SettingsLoaded) {
      final settings = currentState.settings;
      if ((settings.companyName.isEmpty) &&
          (user.companyName != null && user.companyName!.isNotEmpty)) {
        debugPrint('📋 [ProfileScreen] Enriching settings from user data');
        settingsBloc.add(
          UpdateCompanyInfo(
            companyName: user.companyName,
            companyLogo: user.businessLogoUrl,
            rccmNumber: user.rccmNumber,
            businessUnitId: user.businessUnitId,
            businessUnitCode: user.businessUnitCode,
            businessUnitType: user.businessUnitType,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WanzoScaffold(
      currentIndex: -1,
      title: 'Mon Profil',
      onBackPressed: () =>
          context.canPop() ? context.pop() : context.go('/dashboard'),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            final User user = state.user;
            return _buildProfileDetails(context, user);
          } else if (state is AuthLoading) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return const Center(
              child: Text('Impossible de charger les informations du profil.'),
            );
          }
        },
      ),
    );
  }

  Widget _buildProfileDetails(BuildContext context, User user) {
    // Enrichir les Settings avec les données du User si nécessaire
    _enrichSettingsFromUser(context, user);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        // Avatar avec photo
        _buildAvatarSection(context, user),
        const SizedBox(height: 24),

        // Section informations personnelles
        _buildPersonalInfoCard(context, user),

        // Section entreprise (si données disponibles)
        if (_hasCompanyInfo(user)) ...[
          const SizedBox(height: 16),
          _buildBusinessInfoCard(context, user),
        ],

        // Section rôle et statut
        const SizedBox(height: 16),
        _buildRoleStatusCard(context, user),

        const SizedBox(height: 24),
        _buildEditButton(context),
      ],
    );
  }

  Widget _buildAvatarSection(BuildContext context, User user) {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            backgroundImage:
                _profileImageFile != null
                    ? FileImage(_profileImageFile!)
                    : (user.picture != null && user.picture!.isNotEmpty
                            ? NetworkImage(user.picture!)
                            : null)
                        as ImageProvider?,
            child:
                (_profileImageFile == null &&
                        (user.picture == null || user.picture!.isEmpty))
                    ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 50,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    : null,
          ),
          IconButton(
            icon: Icon(Icons.camera_alt, color: Theme.of(context).primaryColor),
            onPressed: () => _showImagePickerOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard(BuildContext context, User user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSectionHeader(
              context,
              Icons.person,
              'Informations personnelles',
            ),
            const SizedBox(height: 12),
            _buildProfileInfoRow(context, 'Nom complet', user.name),
            _buildProfileInfoRow(context, 'Adresse e-mail', user.email),
            if (user.phone.isNotEmpty)
              _buildProfileInfoRow(context, 'Téléphone', user.phone),
          ],
        ),
      ),
    );
  }

  bool _hasCompanyInfo(User user) {
    return (user.companyName != null && user.companyName!.isNotEmpty) ||
        (user.companyId != null && user.companyId!.isNotEmpty);
  }

  Widget _buildBusinessInfoCard(BuildContext context, User user) {
    final vocab = EntityVocabularyService.current();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSectionHeader(context, Icons.business, vocab.entityCapitalized),
            const SizedBox(height: 12),
            if (user.companyName != null && user.companyName!.isNotEmpty)
              _buildProfileInfoRow(context, vocab.entityCapitalized, user.companyName!),
            if (user.rccmNumber != null && user.rccmNumber!.isNotEmpty)
              _buildProfileInfoRow(context, 'RCCM', user.rccmNumber!),
            if (user.businessUnitType != null)
              _buildProfileInfoRow(
                context,
                'Type',
                _getBusinessUnitTypeLabel(user.businessUnitType!),
              ),
            if (user.businessUnitCode != null &&
                user.businessUnitCode!.isNotEmpty)
              _buildProfileInfoRow(
                context,
                'Code unité',
                user.businessUnitCode!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleStatusCard(BuildContext context, User user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSectionHeader(context, Icons.security, 'Rôle et statut'),
            const SizedBox(height: 12),
            _buildProfileInfoRow(context, 'Rôle', _getRoleLabel(user.role)),
            _buildStatusRow(context, 'Compte actif', user.isActive),
            _buildStatusRow(context, 'Email vérifié', user.emailVerified),
          ],
        ),
      ),
    );
  }

  Widget _buildEditButton(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.edit),
      label: const Text('Modifier le profil'),
      onPressed: () {
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditProfileScreen(user: authState.user),
            ),
          ).then((result) {
            if (result is User) {
              setState(() {});
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Données utilisateur non disponibles.'),
            ),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        textStyle: const TextStyle(fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    IconData icon,
    String title,
  ) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildProfileInfoRow(
    BuildContext context,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, String label, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  isActive ? 'Oui' : 'Non',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        isActive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrateur';
      case 'owner':
        return 'Propriétaire';
      case 'manager':
        return 'Gestionnaire';
      case 'employee':
      case 'staff':
        return 'Employé';
      default:
        return role;
    }
  }

  String _getBusinessUnitTypeLabel(dynamic type) {
    final typeStr = type.toString().toLowerCase();
    final vocab = EntityVocabularyService.current();
    if (typeStr.contains('company')) return vocab.entityCapitalized;
    if (typeStr.contains('branch')) return vocab.branchCapitalized;
    if (typeStr.contains('pos')) return 'Point de vente';
    return typeStr;
  }
}
