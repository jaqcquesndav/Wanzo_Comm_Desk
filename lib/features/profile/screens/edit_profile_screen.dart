import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../auth/models/user.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../../core/services/file_storage_service.dart';

/// Écran d'édition du profil utilisateur
///
/// Champs modifiables selon l'API (PUT /users/me ou PATCH /settings-user-profile/profile/me):
/// - firstName (prénom)
/// - lastName (nom)
/// - phoneNumber (téléphone)
/// - profilePictureUrl (photo de profil)
class EditProfileScreen extends StatefulWidget {
  final User user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Contrôleurs pour les champs modifiables uniquement
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;

  File? _profileImageFile;
  final ImagePicker _picker = ImagePicker();
  final FileStorageService _storageService = FileStorageService();
  bool _isSaving = false;

  // Clé du formulaire pour la validation
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Séparer le nom complet en prénom et nom
    final nameParts = _splitName(widget.user.name);
    _firstNameController = TextEditingController(text: nameParts['firstName']);
    _lastNameController = TextEditingController(text: nameParts['lastName']);
    _phoneController = TextEditingController(text: widget.user.phone);
  }

  /// Sépare un nom complet en prénom et nom
  Map<String, String> _splitName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return {'firstName': parts.first, 'lastName': parts.sublist(1).join(' ')};
    }
    return {'firstName': fullName, 'lastName': ''};
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      if (!mounted) return;
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Rogner l\'image',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Rogner l\'image',
            minimumAspectRatio: 1.0,
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
          ),
        ],
      );
      if (croppedFile != null) {
        setState(() {
          _profileImageFile = File(croppedFile.path);
        });
      }
    }
  }

  void _showImagePickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galerie'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickAndCropImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Appareil photo'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickAndCropImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveProfile() async {
    // Valider le formulaire
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    String? newImageUrl;
    if (_profileImageFile != null) {
      newImageUrl = await _storageService.uploadProfileImage(
        _profileImageFile!,
        widget.user.id,
      );
      if (newImageUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Échec du téléchargement de l\'image. Veuillez réessayer.',
              ),
            ),
          );
          setState(() {
            _isSaving = false;
          });
          return;
        }
      }
    }

    // Construire le nom complet à partir du prénom et nom
    final fullName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();

    // Créer l'utilisateur mis à jour avec uniquement les champs modifiables
    User updatedUser = widget.user.copyWith(
      name: fullName,
      phone: _phoneController.text.trim(),
      picture: newImageUrl ?? widget.user.picture,
    );

    if (mounted) {
      context.read<AuthBloc>().add(
        AuthUserProfileUpdated(
          updatedUser,
          profileImageFile: _profileImageFile,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le Profil')),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthProfileUpdateSuccess) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profil mis à jour avec succès!')),
              );
              Navigator.of(context).pop(state.user);
            }
          } else if (state is AuthProfileUpdateFailure) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Échec de la mise à jour du profil: ${state.error}',
                  ),
                ),
              );
              setState(() {
                _isSaving = false;
              });
            }
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Photo de profil
                _buildProfilePhoto(),
                const SizedBox(height: 24),

                // Informations personnelles modifiables
                _buildSectionTitle('Informations personnelles'),
                const SizedBox(height: 12),
                _buildFirstNameField(),
                const SizedBox(height: 12),
                _buildLastNameField(),
                const SizedBox(height: 12),
                _buildPhoneField(),
                const SizedBox(height: 16),

                // Email en lecture seule
                _buildReadOnlyField(
                  label: 'Adresse e-mail',
                  value: widget.user.email,
                  icon: Icons.email_outlined,
                  helperText: 'L\'adresse e-mail ne peut pas être modifiée',
                ),
                const SizedBox(height: 32),

                // Bouton de sauvegarde
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildProfilePhoto() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Theme.of(
              context,
            ).primaryColor.withAlpha((255 * 0.1).round()),
            backgroundImage:
                _profileImageFile != null
                    ? FileImage(_profileImageFile!)
                    : (widget.user.picture != null &&
                                widget.user.picture!.isNotEmpty
                            ? NetworkImage(widget.user.picture!)
                            : null)
                        as ImageProvider?,
            child:
                (_profileImageFile == null &&
                        (widget.user.picture == null ||
                            widget.user.picture!.isEmpty))
                    ? Text(
                      widget.user.name.isNotEmpty
                          ? widget.user.name[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontSize: 50,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    : null,
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              onPressed: () => _showImagePickerOptions(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstNameField() {
    return TextFormField(
      controller: _firstNameController,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Prénom',
        prefixIcon: const Icon(Icons.person_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Le prénom est requis';
        }
        return null;
      },
    );
  }

  Widget _buildLastNameField() {
    return TextFormField(
      controller: _lastNameController,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Nom',
        prefixIcon: const Icon(Icons.person_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Le nom est requis';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Numéro de téléphone',
        prefixIcon: const Icon(Icons.phone_outlined),
        hintText: '+243999123456',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          // Validation simple du format téléphone
          final phoneRegex = RegExp(r'^\+?[0-9]{9,15}$');
          if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
            return 'Format de téléphone invalide';
          }
        }
        return null;
      },
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    String? helperText,
  }) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        helperText: helperText,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _saveProfile,
      icon:
          _isSaving
              ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
              )
              : const Icon(Icons.save_outlined),
      label: Text(
        _isSaving ? 'Enregistrement...' : 'Enregistrer les modifications',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
