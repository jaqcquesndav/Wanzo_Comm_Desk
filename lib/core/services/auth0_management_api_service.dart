import 'dart:convert';
import 'package:flutter/material.dart'; // For debugPrint
import 'package:http/http.dart' as http;
import 'package:wanzo/core/config/env_config.dart'; // Assuming EnvConfig might hold the base URL

class Auth0ManagementApiService {
  // Use apiGatewayUrl as the base for backend calls
  final String _baseUrl = EnvConfig.apiGatewayUrl;

  Future<String?> getManagementApiToken(String userAccessToken) async {
    // Ensure the endpoint path is correctly appended to the base URL
    final String apiUrl = '$_baseUrl/api/auth/management-token';
    debugPrint(
      "Auth0ManagementApiService: Requesting Management API Token from: $apiUrl",
    );

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer $userAccessToken', // Send the user's access token
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final managementToken = responseBody['managementApiToken'] as String?;
        if (managementToken != null) {
          debugPrint(
            "Auth0ManagementApiService: Management API Token received.",
          );
          return managementToken;
        } else {
          debugPrint(
            "Auth0ManagementApiService: 'managementApiToken' field not found in response or is null.",
          );
          return null;
        }
      } else {
        debugPrint(
          'Auth0ManagementApiService: Failed to get management API token. Status: ${response.statusCode}, Body: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint(
        'Auth0ManagementApiService: Error calling management API token endpoint: $e',
      );
      return null;
    }
  }
}
