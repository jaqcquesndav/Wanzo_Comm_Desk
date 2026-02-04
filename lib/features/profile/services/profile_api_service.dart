import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/features/auth/models/user.dart';
import 'package:wanzo/features/settings/models/settings.dart';
import 'package:wanzo/features/auth/models/business_sector.dart';

class ProfileApiService {
  final ApiClient _apiClient;

  ProfileApiService(this._apiClient);

  Future<User> getCurrentUserProfile() async {
    final response = await _apiClient.get('settings-user-profile/profile/me');
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
    var request = http.MultipartRequest(
      'PATCH',
      Uri.parse(_apiClient.getFullUrl('settings-user-profile/profile/me')),
    );
    request.headers.addAll(await _apiClient.getHeaders(requiresAuth: true));

    if (name != null) request.fields['name'] = name;
    if (email != null) request.fields['email'] = email;
    if (phone != null) request.fields['phone_number'] = phone;
    if (jobTitle != null) request.fields['job_title'] = jobTitle;
    if (physicalAddress != null) {
      request.fields['physical_address'] = physicalAddress;
    }
    if (idCardNumber != null) request.fields['id_card'] = idCardNumber;

    request.files.add(
      await http.MultipartFile.fromPath('picture', pictureFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final dynamic decodedResponse = _apiClient.handleResponse(response);
    return User.fromJson(decodedResponse as Map<String, dynamic>);
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
    var request = http.MultipartRequest(
      'PATCH',
      Uri.parse(_apiClient.getFullUrl('settings-user-profile/profile/me')),
    );
    request.headers.addAll(await _apiClient.getHeaders(requiresAuth: true));

    if (companyName != null) request.fields['company_name'] = companyName;
    if (rccmNumber != null) request.fields['rccm_number'] = rccmNumber;
    if (companyLocation != null) {
      request.fields['company_location'] = companyLocation;
    }
    if (businessSectorId != null) {
      request.fields['business_sector_id'] = businessSectorId;
    }
    if (businessAddress != null) {
      request.fields['business_address'] = businessAddress;
    }

    request.files.add(
      await http.MultipartFile.fromPath('business_logo', businessLogoFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final dynamic decodedResponse = _apiClient.handleResponse(response);
    return User.fromJson(decodedResponse as Map<String, dynamic>);
  }

  Future<Settings> getSettings() async {
    final response = await _apiClient.get(
      'settings-user-profile/application-settings',
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
    var request = http.MultipartRequest(
      'PATCH',
      Uri.parse(
        _apiClient.getFullUrl('settings-user-profile/application-settings'),
      ),
    );
    request.headers.addAll(await _apiClient.getHeaders(requiresAuth: true));

    settings.toJson().forEach((key, value) {
      if (value != null && key != 'company_logo') {
        request.fields[key] = value.toString();
      }
    });

    request.files.add(
      await http.MultipartFile.fromPath('company_logo', companyLogoFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final dynamic decodedResponse = _apiClient.handleResponse(response);
    return Settings.fromJson(decodedResponse as Map<String, dynamic>);
  }

  Future<List<BusinessSector>> getBusinessSectors() async {
    final response = await _apiClient.get(
      'settings-user-profile/business-sectors',
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
