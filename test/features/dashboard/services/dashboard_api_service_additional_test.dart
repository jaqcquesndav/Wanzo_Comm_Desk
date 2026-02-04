import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/features/dashboard/models/dashboard_data.dart';

void main() {
  group('DashboardData Tests', () {
    test('should create DashboardData with expected values', () async {
      // Create dashboard data
      final dashboardData = DashboardData(
        salesTodayCdf: 15000.0,
        salesTodayUsd: 5.0,
        clientsServedToday: 2,
        receivables: 25000.0,
        expenses: 0.0,
      );
      
      // Verify values
      expect(dashboardData.salesTodayCdf, 15000.0);
      expect(dashboardData.salesTodayUsd, 5.0);
      expect(dashboardData.clientsServedToday, 2);
      expect(dashboardData.receivables, 25000.0);
      expect(dashboardData.expenses, 0.0);
    });
    
    test('should create an empty DashboardData object', () {
      final emptyData = DashboardData.empty();
      
      expect(emptyData.salesTodayCdf, 0.0);
      expect(emptyData.salesTodayUsd, 0.0);
      expect(emptyData.clientsServedToday, 0);
      expect(emptyData.receivables, 0.0);
      expect(emptyData.expenses, 0.0);
    });
    
    test('DashboardData objects with same values should be equal', () {
      final data1 = DashboardData(
        salesTodayCdf: 1000.0,
        salesTodayUsd: 10.0,
        clientsServedToday: 5,
        receivables: 2000.0,
        expenses: 500.0,
      );
      
      final data2 = DashboardData(
        salesTodayCdf: 1000.0,
        salesTodayUsd: 10.0,
        clientsServedToday: 5,
        receivables: 2000.0,
        expenses: 500.0,
      );
      
      expect(data1, equals(data2));
    });
  });
  
  group('ApiResponse Tests', () {
    test('ApiResponse should handle success states correctly', () async {
      final dashboardData = DashboardData.empty();
      final response = ApiResponse<DashboardData>(
        success: true,
        data: dashboardData,
        message: 'Success message',
        statusCode: 200,
      );
      
      expect(response.success, true);
      expect(response.data, dashboardData);
      expect(response.message, 'Success message');
      expect(response.statusCode, 200);
    });
    
    test('ApiResponse should handle error states correctly', () async {
      final response = ApiResponse<DashboardData>(
        success: false,
        message: 'Error message',
        error: 'Database error',
        statusCode: 500,
      );
      
      expect(response.success, false);
      expect(response.data, isNull);
      expect(response.message, 'Error message');
      expect(response.error, 'Database error');
      expect(response.statusCode, 500);
    });
    
    test('ApiResponse should work with different data types', () {
      // String data
      final stringResponse = ApiResponse<String>(
        success: true,
        data: 'Test data',
        message: 'Success',
        statusCode: 200,
      );
      expect(stringResponse.data, 'Test data');
      
      // int data
      final intResponse = ApiResponse<int>(
        success: true,
        data: 42,
        message: 'Success',
        statusCode: 200,
      );
      expect(intResponse.data, 42);
      
      // Map data
      final mapResponse = ApiResponse<Map<String, dynamic>>(
        success: true,
        data: {'key': 'value'},
        message: 'Success',
        statusCode: 200,
      );
      expect(mapResponse.data?['key'], 'value');
    });
  });
}
