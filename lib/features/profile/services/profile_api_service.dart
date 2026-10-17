import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/services/image_upload_service.dart';
import 'package:wanzo/features/auth/models/user.dart';
import 'package:wanzo/features/settings/models/settings.dart';
import 'package:wanzo/features/auth/models/business_sector.dart';

class ProfileApiService {
  final ApiClient _apiClient;
  final ImageUploadService _imageUploadService;

  ProfileApiService(this._apiClient, {ImageUploadService? imageUploadService})
    : _imageUploadService = imageUploadService ?? ImageUploadService();

  Future<User> getCurrentUserProfile() async {
    final response = await _apiClient.get(
      'settings-user-profile/profile/me',
      requiresAuth: true,
    );
    return User.fromJson(response);
  }

  Future<User> updateUserProfile({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? jobTitle,
    String? physicalAddress,
    File? pictureFile,
    String? idCardNumber,
  }) async {
    // Si un fichier est fourni, utiliser multipart
    if (pictureFile != null) {
      return _updateUserProfileWithFile(
        userId: userId,
        name: name,
        email: email,
        phone: phone,
        jobTitle: jobTitle,
        physicalAddress: physicalAddress,
        pictureFile: pictureFile,
        idCardNumber: idCardNumber,
      );
    }

    // Sinon, utiliser JSON standard
    final Map<String, dynamic> body = {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone_number': phone,
      if (jobTitle != null) 'job_title': jobTitle,
      if (physicalAddress != null) 'physical_address': physicalAddress,
      if (idCardNumber != null) 'id_card': idCardNumber,
    };

    final response = await _apiClient.patch(
      'settings-user-profile/profile/me',
      body: body,
      requiresAuth: true,
    );

    return User.fromJson(response as Map<String, dynamic>);
  }

  Future<User> _updateUserProfileWithFile({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? jobTitle,
    String? physicalAddress,
    required File pictureFile,
    String? idCardNumber,
  }) async {
    // Upload image to Cloudinary first
    String? pictureUrl;
    try {
      pictureUrl = await _imageUploadService.uploadImage(
        pictureFile,
        publicId: 'profile_$userId',
      );
      debugPrint('ProfileApiService: Profile picture uploaded to Cloudinary: $pictureUrl');
    } catch (e) {
      debugPrint('ProfileApiService: Failed to upload profile picture to Cloudinary: $e');
      throw Exception('Failed to upload profile picture: $e');
    }

    final Map<String, dynamic> body = {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone_number': phone,
      if (jobTitle != null) 'job_title': jobTitle,
      if (physicalAddress != null) 'physical_address': physicalAddress,
      if (idCardNumber != null) 'id_card': idCardNumber,
      if (pictureUrl != null) 'profilePictureUrl': pictureUrl,
    };

    final response = await _apiClient.patch(
      'settings-user-profile/profile/me',
      body: body,
      requiresAuth: true,
    );

    return User.fromJson(response as Map<String, dynamic>);
  }

  Future<User> updateUserBusinessProfile({
    required String userId,
    String? companyName,
    String? rccmNumber,
    String? companyLocation,
    String? businessSectorId,
    String? businessAddress,
    File? businessLogoFile,
  }) async {
    // Si un fichier est fourni, utiliser multipart
    if (businessLogoFile != null) {
      return _updateUserBusinessProfileWithFile(
        userId: userId,
        companyName: companyName,
        rccmNumber: rccmNumber,
        companyLocation: companyLocation,
        businessSectorId: businessSectorId,
        businessAddress: businessAddress,
        businessLogoFile: businessLogoFile,
      );
    }

    // Sinon, utiliser JSON standard
    final Map<String, dynamic> body = {
      if (companyName != null) 'company_name': companyName,
      if (rccmNumber != null) 'rccm_number': rccmNumber,
      if (companyLocation != null) 'company_location': companyLocation,
      if (businessSectorId != null) 'business_sector_id': businessSectorId,
      if (businessAddress != null) 'business_address': businessAddress,
    };

    final response = await _apiClient.patch(
      'settings-user-profile/profile/me',
      body: body,
      requiresAuth: true,
    );

    return User.fromJson(response as Map<String, dynamic>);
  }

  Future<User> _updateUserBusinessProfileWithFile({
    required String userId,
    String? companyName,
    String? rccmNumber,
    String? companyLocation,
    String? businessSectorId,
    String? businessAddress,
    required File businessLogoFile,
  }) async {
    // Upload logo to Cloudinary first
    String? businessLogoUrl;
    try {
      businessLogoUrl = await _imageUploadService.uploadImage(
        businessLogoFile,
        publicId: 'business_logo_$userId',
      );
      debugPrint('ProfileApiService: Business logo uploaded to Cloudinary: $businessLogoUrl');
    } catch (e) {
      debugPrint('ProfileApiService: Failed to upload business logo to Cloudinary: $e');
      throw Exception('Failed to upload business logo: $e');
    }

    final Map<String, dynamic> body = {
      if (companyName != null) 'company_name': companyName,
      if (rccmNumber != null) 'rccm_number': rccmNumber,
      if (companyLocation != null) 'company_location': companyLocation,
      if (businessSectorId != null) 'business_sector_id': businessSectorId,
      if (businessAddress != null) 'business_address': businessAddress,
      if (businessLogoUrl != null) 'businessLogoUrl': businessLogoUrl,
    };

    final response = await _apiClient.patch(
      'settings-user-profile/profile/me',
      body: body,
      requiresAuth: true,
    );

    return User.fromJson(response as Map<String, dynamic>);
  }

  Future<Settings> getSettings() async {
    final response = await _apiClient.get(
      'settings-user-profile/application-settings',
      requiresAuth: true,
    );
    return Settings.fromJson(response);
  }

  Future<Settings> updateSettings(
    Settings settings, {
    File? companyLogoFile,
  }) async {
    // Si un fichier est fourni, utiliser multipart
    if (companyLogoFile != null) {
      return _updateSettingsWithFile(settings, companyLogoFile);
    }

    // Sinon, utiliser JSON standard
    final Map<String, dynamic> body = {};
    settings.toJson().forEach((key, value) {
      if (value != null && key != 'company_logo') {
        body[key] = value;
      }
    });

    final response = await _apiClient.patch(
      'settings-user-profile/application-settings',
      body: body,
      requiresAuth: true,
    );

    return Settings.fromJson(response as Map<String, dynamic>);
  }

  Future<Settings> _updateSettingsWithFile(
    Settings settings,
    File companyLogoFile,
  ) async {
    // Upload logo to Cloudinary first
    String? companyLogoUrl;
    try {
      companyLogoUrl = await _imageUploadService.uploadImage(
        companyLogoFile,
        publicId: 'company_logo_${DateTime.now().millisecondsSinceEpoch}',
      );
      debugPrint('ProfileApiService: Company logo uploaded to Cloudinary: $companyLogoUrl');
    } catch (e) {
      debugPrint('ProfileApiService: Failed to upload company logo to Cloudinary: $e');
      throw Exception('Failed to upload company logo: $e');
    }

    final Map<String, dynamic> body = {};
    settings.toJson().forEach((key, value) {
      if (value != null && key != 'company_logo' && key != 'companyLogoUrl') {
        body[key] = value;
      }
    });
    if (companyLogoUrl != null) {
      body['companyLogoUrl'] = companyLogoUrl;
    }

    final response = await _apiClient.patch(
      'settings-user-profile/application-settings',
      body: body,
      requiresAuth: true,
    );

    return Settings.fromJson(response as Map<String, dynamic>);
  }

  Future<List<BusinessSector>> getBusinessSectors() async {
    final response = await _apiClient.get(
      'settings-user-profile/business-sectors',
      requiresAuth: true,
    );
    // Gérer les deux formats de réponse: liste directe ou objet avec 'data'
    final List<dynamic> data;
    if (response is List) {
      data = response;
    } else if (response is Map && response['data'] != null) {
      data = response['data'] as List<dynamic>;
    } else {
      data = [];
    }
    return data
        .map((json) => BusinessSector.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
