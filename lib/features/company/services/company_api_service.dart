import 'dart:io'; // Added for File type
import 'dart:convert'; // Added for jsonDecode
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/company/models/company_profile.dart'; // Assurez-vous que ce modèle existe

class CompanyApiService {
  final ApiClient _apiClient;

  CompanyApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<ApiResponse<CompanyProfile>> getCompanyProfile() async {
    try {
      final response = await _apiClient.get('company', requiresAuth: true);
      if (response != null && response['data'] != null) {
        final profile = CompanyProfile.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<CompanyProfile>(
          success: true,
          data: profile,
          message:
              response['message'] as String? ??
              'Company profile fetched successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to fetch company profile: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<CompanyProfile>> updateCompanyProfile(
    CompanyProfile profile,
  ) async {
    try {
      final response = await _apiClient.put(
        'company',
        body: profile.toJson(),
        requiresAuth: true,
      );
      if (response != null && response['data'] != null) {
        final updatedProfile = CompanyProfile.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        return ApiResponse<CompanyProfile>(
          success: true,
          data: updatedProfile,
          message:
              response['message'] as String? ??
              'Company profile updated successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to update company profile: An unexpected error occurred. $e',
      );
    }
  }

  // Assurez-vous d'avoir une méthode pour gérer l'upload de fichiers dans ApiClient
  // Exemple: Future<dynamic> postMultipart(String endpoint, {required File file, required String fileField, Map<String, String>? fields, bool requiresAuth = false})
  Future<ApiResponse<String>> uploadCompanyLogo(File logoFile) async {
    try {
      final httpResponse = await _apiClient.postMultipart(
        'company/logo',
        file: logoFile,
        fileField: 'logoFile', // Doit correspondre à ce que le backend attend
        requiresAuth: true,
      );

      // Decode the response body from JSON string to Map
      final Map<String, dynamic>? responseData =
          httpResponse.body.isNotEmpty
              ? jsonDecode(httpResponse.body) as Map<String, dynamic>?
              : null;

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        if (responseData != null &&
            responseData['data'] != null &&
            responseData['data']['logoUrl'] != null) {
          return ApiResponse<String>(
            success: true,
            data: responseData['data']['logoUrl'] as String,
            message:
                responseData['message'] as String? ??
                'Company logo uploaded successfully.',
            statusCode: httpResponse.statusCode,
          );
        } else {
          throw ApiExceptionFactory.fromStatusCode(
            httpResponse.statusCode,
            'Invalid response data format from server for logo upload',
            responseBody: httpResponse.body,
          );
        }
      } else {
        // Handle error responses based on statusCode
        throw ApiExceptionFactory.fromStatusCode(
          httpResponse.statusCode,
          responseData?['message'] as String? ??
              'Failed to upload company logo',
          responseBody: httpResponse.body,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to upload company logo: An unexpected error occurred. $e',
      );
    }
  }

  // Payment Info Endpoints

  Future<ApiResponse<Map<String, dynamic>>> getPaymentInfo(
    String companyId,
  ) async {
    try {
      final response = await _apiClient.get(
        'companies/$companyId/payment-info',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ??
              'Payment info retrieved successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to fetch payment info: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updatePaymentInfo(
    String companyId,
    Map<String, dynamic> paymentInfo,
  ) async {
    try {
      final response = await _apiClient.put(
        'companies/$companyId/payment-info',
        body: paymentInfo,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ??
              'Payment info updated successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to update payment info: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> addBankAccount(
    String companyId,
    Map<String, dynamic> bankAccount,
  ) async {
    try {
      final response = await _apiClient.post(
        'companies/$companyId/payment-info/bank-accounts',
        body: bankAccount,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ??
              'Bank account added successfully.',
          statusCode: response['statusCode'] as int? ?? 201,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to add bank account: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> addMobileMoneyAccount(
    String companyId,
    Map<String, dynamic> mobileMoneyAccount,
  ) async {
    try {
      final response = await _apiClient.post(
        'companies/$companyId/payment-info/mobile-money-accounts',
        body: mobileMoneyAccount,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ??
              'Mobile money account added successfully.',
          statusCode: response['statusCode'] as int? ?? 201,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to add mobile money account: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<void>> verifyMobileMoneyAccount(
    String companyId,
    String phoneNumber,
    String verificationCode,
  ) async {
    try {
      await _apiClient.post(
        'companies/$companyId/payment-info/mobile-money-accounts/verify',
        body: {
          'phoneNumber': phoneNumber,
          'verificationCode': verificationCode,
        },
        requiresAuth: true,
      );

      return ApiResponse<void>(
        success: true,
        message: 'Mobile money account verified successfully.',
        statusCode: 200,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to verify mobile money account: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> deleteBankAccount(
    String companyId,
    String accountNumber,
  ) async {
    try {
      final response = await _apiClient.delete(
        'companies/$companyId/payment-info/bank-accounts/$accountNumber',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ??
              'Bank account removed successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: {},
          message: 'Bank account removed successfully.',
          statusCode: 200,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to delete bank account: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> deleteMobileMoneyAccount(
    String companyId,
    String phoneNumber,
  ) async {
    try {
      final response = await _apiClient.delete(
        'companies/$companyId/payment-info/mobile-money-accounts/$phoneNumber',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ??
              'Mobile money account removed successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: {},
          message: 'Mobile money account removed successfully.',
          statusCode: 200,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to delete mobile money account: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> setDefaultBankAccount(
    String companyId,
    String accountNumber,
  ) async {
    try {
      final response = await _apiClient.put(
        'companies/$companyId/payment-info/bank-accounts/$accountNumber/default',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ??
              'Default bank account set successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to set default bank account: An unexpected error occurred. $e',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> setDefaultMobileMoneyAccount(
    String companyId,
    String phoneNumber,
  ) async {
    try {
      final response = await _apiClient.put(
        'companies/$companyId/payment-info/mobile-money-accounts/$phoneNumber/default',
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response['data'] as Map<String, dynamic>,
          message:
              response['message'] as String? ??
              'Default mobile money account set successfully.',
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(
          response['statusCode'] as int? ?? 500,
          'Invalid response data format from server',
          responseBody: response,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to set default mobile money account: An unexpected error occurred. $e',
      );
    }
  }
}

// Assurez-vous que le modèle CompanyProfile est défini, par exemple:
// c:\\Users\\DevSpace\\Flutter\\wanzo\\lib\\features\\company\\models\\company_profile.dart
/*
class CompanyProfile {
  final String id;
  final String name;
  final String? registrationNumber;
  final String? taxId;
  final String? address;
  final String? city;
  final String? country;
  final String? phoneNumber;
  final String? email;
  final String? website;
  final String? logoUrl;
  final String? industry;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyProfile({
    required this.id,
    required this.name,
    this.registrationNumber,
    this.taxId,
    this.address,
    this.city,
    this.country,
    this.phoneNumber,
    this.email,
    this.website,
    this.logoUrl,
    this.industry,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      registrationNumber: json['registrationNumber'] as String?,
      taxId: json['taxId'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      logoUrl: json['logoUrl'] as String?,
      industry: json['industry'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'registrationNumber': registrationNumber,
      'taxId': taxId,
      'address': address,
      'city': city,
      'country': country,
      'phoneNumber': phoneNumber,
      'email': email,
      'website': website,
      'industry': industry,
      // id, createdAt, updatedAt, logoUrl ne sont généralement pas envoyés lors d'un update de cette manière
    };
  }
}
*/
