import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/api_response.dart';
import '../../features/auth/models/user.dart';
import '../../features/company/models/registration_request.dart';
import './api_client.dart';
import '../exceptions/api_exceptions.dart';
import 'logging_service.dart';

class AuthApiService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LoggingService _logger = LoggingService.instance;

  AuthApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<ApiResponse<User>> login(String email, String password) async {
    final startTime = DateTime.now();

    try {
      _logger.info('Attempting login', context: {'email': email});

      final response = await _apiClient.post(
        'auth/login',
        body: {'email': email, 'password': password},
        requiresAuth: false,
      );

      if (response != null &&
          response['data'] != null &&
          response['data']['user'] != null &&
          response['data']['token'] != null) {
        final user = User.fromJson(
          response['data']['user'] as Map<String, dynamic>,
        );
        final token = response['data']['token'] as String;

        await _secureStorage.write(key: 'auth_token', value: token);

        final duration = DateTime.now().difference(startTime);
        _logger.performance(
          'login',
          duration,
          context: {'email': email, 'success': true},
        );
        _logger.authAttempt(
          'login',
          success: true,
          context: {'email': email, 'userId': user.id},
        );

        return ApiResponse<User>(
          success: true,
          data: user,
          message: response['message'] as String? ?? "Login successful",
          statusCode: response['statusCode'] as int? ?? 200,
        );
      } else {
        _logger.error(
          'Invalid login response format',
          context: {'email': email, 'response': response},
        );
        throw BadRequestException(
          'Invalid login response data format from server',
          endpoint: 'auth/login',
          responseBody: response,
        );
      }
    } on ApiException catch (e) {
      _logger.apiError('auth/login', e, requestData: {'email': email});
      _logger.authAttempt(
        'login',
        success: false,
        reason: e.message,
        context: {'email': email},
      );
      rethrow;
    } catch (e, stackTrace) {
      _logger.error(
        'Login failed with unexpected error',
        error: e,
        stackTrace: stackTrace,
        context: {'email': email},
      );
      _logger.authAttempt(
        'login',
        success: false,
        reason: 'Unexpected error',
        context: {'email': email},
      );
      throw NetworkException(
        'Login failed: An unexpected error occurred. $e',
        endpoint: 'auth/login',
      );
    }
  }

  Future<ApiResponse<User>> register(
    RegistrationRequest registrationRequest,
  ) async {
    final startTime = DateTime.now();

    try {
      _logger.info(
        'Attempting registration',
        context: {
          'email': registrationRequest.email,
          'companyName': registrationRequest.companyName,
        },
      );

      final response = await _apiClient.post(
        'auth/register',
        body: registrationRequest.toJson(),
        requiresAuth: false,
      );

      if (response != null &&
          response['data'] != null &&
          response['data']['user'] != null &&
          response['data']['token'] != null) {
        final user = User.fromJson(
          response['data']['user'] as Map<String, dynamic>,
        );
        final token = response['data']['token'] as String;

        await _secureStorage.write(key: 'auth_token', value: token);

        final duration = DateTime.now().difference(startTime);
        _logger.performance(
          'register',
          duration,
          context: {'email': registrationRequest.email, 'success': true},
        );
        _logger.authAttempt(
          'register',
          success: true,
          context: {
            'email': registrationRequest.email,
            'userId': user.id,
            'companyName': user.companyName,
          },
        );

        return ApiResponse<User>(
          success: true,
          data: user,
          message: response['message'] as String? ?? "Registration successful",
          statusCode: response['statusCode'] as int? ?? 201,
        );
      } else {
        _logger.error(
          'Invalid registration response format',
          context: {'email': registrationRequest.email, 'response': response},
        );
        throw BadRequestException(
          'Invalid registration response data format from server',
          endpoint: 'auth/register',
          responseBody: response,
        );
      }
    } on ApiException catch (e) {
      _logger.apiError(
        'auth/register',
        e,
        requestData: {
          'email': registrationRequest.email,
          'companyName': registrationRequest.companyName,
        },
      );
      _logger.authAttempt(
        'register',
        success: false,
        reason: e.message,
        context: {'email': registrationRequest.email},
      );
      rethrow;
    } catch (e, stackTrace) {
      _logger.error(
        'Registration failed with unexpected error',
        error: e,
        stackTrace: stackTrace,
        context: {'email': registrationRequest.email},
      );
      _logger.authAttempt(
        'register',
        success: false,
        reason: 'Unexpected error',
        context: {'email': registrationRequest.email},
      );
      throw NetworkException(
        'Registration failed: An unexpected error occurred. $e',
        endpoint: 'auth/register',
      );
    }
  }

  Future<void> logout() async {
    try {
      _logger.info('Attempting logout');

      await _secureStorage.delete(key: 'auth_token');
      // Optional: Call a backend logout endpoint if it exists
      // await _apiClient.post('auth/logout', body: {}, requiresAuth: true);

      _logger.authAttempt('logout', success: true);
    } catch (e, stackTrace) {
      _logger.error('Error during logout', error: e, stackTrace: stackTrace);
      _logger.authAttempt('logout', success: false, reason: e.toString());
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      _logger.debug('Fetching current user');

      final token = await _secureStorage.read(key: 'auth_token');
      if (token == null) {
        _logger.debug('No auth token found');
        return null;
      }

      final response = await _apiClient.get('users/me', requiresAuth: true);
      if (response != null &&
          response['data'] != null &&
          response['data']['user'] != null) {
        final user = User.fromJson(
          response['data']['user'] as Map<String, dynamic>,
        );
        _logger.info(
          'Successfully fetched current user',
          context: {'userId': user.id},
        );
        return user;
      }

      _logger.warning(
        'Invalid response format for current user',
        context: {'response': response},
      );
      return null;
    } on AuthenticationException catch (e) {
      _logger.warning(
        'Authentication failed while fetching current user',
        error: e,
      );
      await _secureStorage.delete(key: 'auth_token');
      _logger.info('Deleted invalid auth token');
      return null;
    } catch (e, stackTrace) {
      _logger.error(
        'Error fetching current user',
        error: e,
        stackTrace: stackTrace,
      );

      if (e is ApiException && e.statusCode == 401) {
        await _secureStorage.delete(key: 'auth_token');
        _logger.info('Deleted auth token due to 401 error');
      }
      return null;
    }
  }

  Future<String?> refreshToken() async {
    try {
      _logger.info('Attempting token refresh');

      final currentToken = await _secureStorage.read(key: 'auth_token');
      if (currentToken == null) {
        _logger.warning('No current token to refresh');
        return null;
      }

      // TODO: Implémenter la logique de refresh token avec l'API
      // final response = await _apiClient.post(
      //   'auth/refresh',
      //   body: {'token': currentToken},
      //   requiresAuth: true,
      // );

      // if (response != null && response['data'] != null && response['data']['token'] != null) {
      //   final newToken = response['data']['token'] as String;
      //   await _secureStorage.write(key: 'auth_token', value: newToken);
      //   _logger.authAttempt('refresh_token', success: true);
      //   return newToken;
      // }

      _logger.warning('Token refresh not yet implemented');
      return null;
    } catch (e, stackTrace) {
      _logger.error('Token refresh failed', error: e, stackTrace: stackTrace);
      _logger.authAttempt(
        'refresh_token',
        success: false,
        reason: e.toString(),
      );
      return null;
    }
  }
}
