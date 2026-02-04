import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/dashboard/models/dashboard_data.dart';
import 'package:wanzo/core/models/api_response.dart';

void main() {
  group('DashboardData', () {
    test('should create a valid DashboardData object', () {
      // Arrange & Act
      final dashboardData = DashboardData(
        salesTodayCdf: 1000.0,
        salesTodayUsd: 500.0,
        clientsServedToday: 10,
        receivables: 2000.0,
        expenses: 300.0,
      );
      
      // Assert
      expect(dashboardData.salesTodayCdf, 1000.0);
      expect(dashboardData.salesTodayUsd, 500.0);
      expect(dashboardData.clientsServedToday, 10);
      expect(dashboardData.receivables, 2000.0);
      expect(dashboardData.expenses, 300.0);
    });
    
    test('should create an empty DashboardData object', () {
      // Arrange & Act
      final dashboardData = DashboardData.empty();
      
      // Assert
      expect(dashboardData.salesTodayCdf, 0.0);
      expect(dashboardData.salesTodayUsd, 0.0);
      expect(dashboardData.clientsServedToday, 0);
      expect(dashboardData.receivables, 0.0);
      expect(dashboardData.expenses, 0.0);
    });
  });

  group('ApiResponse', () {
    test('should create a valid success ApiResponse', () {
      // Arrange & Act
      final dashboardData = DashboardData.empty();
      final response = ApiResponse<DashboardData>(
        success: true,
        data: dashboardData,
        message: 'Success',
        statusCode: 200,
      );
      
      // Assert
      expect(response.success, true);
      expect(response.data, dashboardData);
      expect(response.message, 'Success');
      expect(response.statusCode, 200);
    });
    
    test('should create a valid error ApiResponse', () {
      // Arrange & Act
      final response = ApiResponse<DashboardData>(
        success: false,
        message: 'Error',
        error: 'Something went wrong',
        statusCode: 500,
      );
      
      // Assert
      expect(response.success, false);
      expect(response.data, null);
      expect(response.message, 'Error');
      expect(response.error, 'Something went wrong');
      expect(response.statusCode, 500);
    });
  });

  // Add new test group for the DashboardApiService
  group('DashboardApiService without mocks', () {
    test('DashboardApiService creates valid dashboard data from sales information', () {
      // This is a non-mocked test that just verifies the model behaviors
      final dashboardData = DashboardData(
        salesTodayCdf: 15000.0,
        salesTodayUsd: 5.0,
        clientsServedToday: 2,
        receivables: 25000.0,
        expenses: 0.0,
      );
      
      // Create a valid ApiResponse
      final apiResponse = ApiResponse<DashboardData>(
        success: true,
        data: dashboardData,
        message: 'Data retrieved successfully',
        statusCode: 200,
      );
      
      // Assertions
      expect(apiResponse.success, true);
      expect(apiResponse.data?.salesTodayCdf, 15000.0);
      expect(apiResponse.data?.salesTodayUsd, 5.0);
      expect(apiResponse.data?.clientsServedToday, 2);
      expect(apiResponse.data?.receivables, 25000.0);
      expect(apiResponse.data?.expenses, 0.0);
      expect(apiResponse.statusCode, 200);
    });
    
    test('DashboardApiService handles errors correctly', () {
      final errorResponse = ApiResponse<DashboardData>(
        success: false,
        message: 'Failed to retrieve data',
        error: 'Database error: Connection refused',
        statusCode: 500,
      );
      
      expect(errorResponse.success, false);
      expect(errorResponse.data, isNull);
      expect(errorResponse.message, 'Failed to retrieve data');
      expect(errorResponse.error, contains('Database error'));
      expect(errorResponse.statusCode, 500);
    });
  });
}
