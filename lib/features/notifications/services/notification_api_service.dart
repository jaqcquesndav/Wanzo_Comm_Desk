import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/features/notifications/models/notification_model.dart';
import 'package:wanzo/core/models/api_response.dart';

abstract class NotificationApiService {
  Future<ApiResponse<List<NotificationModel>>> getNotifications({
    int? page,
    int? limit,
    String? status, // 'read', 'unread'
  });

  Future<ApiResponse<NotificationModel>> markNotificationAsRead(
    String notificationId,
  );

  Future<ApiResponse<void>> markAllNotificationsAsRead();

  Future<ApiResponse<void>> deleteNotification(String notificationId);
}

class NotificationApiServiceImpl implements NotificationApiService {
  final ApiClient _apiClient;

  NotificationApiServiceImpl(this._apiClient);

  @override
  Future<ApiResponse<List<NotificationModel>>> getNotifications({
    int? page,
    int? limit,
    String? status,
  }) async {
    try {
      final queryParameters = <String, String>{
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (status != null) 'status': status,
      };

      final response = await _apiClient.get(
        'notifications',
        queryParameters: queryParameters,
        requiresAuth: true,
      );

      if (response != null) {
        if (response is List<dynamic>) {
          // API returns a direct list of notifications
          final notifications =
              response
                  .map(
                    (json) => NotificationModel.fromJson(
                      json as Map<String, dynamic>,
                    ),
                  )
                  .toList();

          return ApiResponse<List<NotificationModel>>(
            success: true,
            data: notifications,
            message: 'Notifications retrieved successfully',
            statusCode: 200,
          );
        } else if (response is Map<String, dynamic> &&
            response['data'] != null) {
          // API returns a wrapped response with data field
          final List<dynamic> data = response['data'] as List<dynamic>;
          final notifications =
              data
                  .map(
                    (json) => NotificationModel.fromJson(
                      json as Map<String, dynamic>,
                    ),
                  )
                  .toList();

          return ApiResponse<List<NotificationModel>>(
            success: true,
            data: notifications,
            message:
                response['message'] as String? ??
                'Notifications retrieved successfully',
            statusCode: response['statusCode'] as int? ?? 200,
          );
        }
      }

      return ApiResponse<List<NotificationModel>>(
        success: false,
        data: [],
        message: 'Failed to retrieve notifications: Invalid response format',
        statusCode: 500,
      );
    } catch (e) {
      return ApiResponse<List<NotificationModel>>(
        success: false,
        data: [],
        message: 'Failed to retrieve notifications: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<NotificationModel>> markNotificationAsRead(
    String notificationId,
  ) async {
    try {
      final response = await _apiClient.patch(
        'notifications/$notificationId/read',
        requiresAuth: true,
      );

      if (response != null) {
        final Map<String, dynamic> data;
        if (response is Map<String, dynamic> && response['data'] != null) {
          // API returns a wrapped response
          data = response['data'] as Map<String, dynamic>;
        } else {
          // API returns direct data
          data = response as Map<String, dynamic>;
        }

        final notification = NotificationModel.fromJson(data);

        return ApiResponse<NotificationModel>(
          success: true,
          data: notification,
          message: 'Notification marked as read',
          statusCode: 200,
        );
      }

      return ApiResponse<NotificationModel>(
        success: false,
        data: null,
        message: 'Failed to mark notification as read: Invalid response',
        statusCode: 500,
      );
    } catch (e) {
      return ApiResponse<NotificationModel>(
        success: false,
        data: null,
        message: 'Failed to mark notification as read: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<void>> markAllNotificationsAsRead() async {
    try {
      await _apiClient.patch('notifications/read-all', requiresAuth: true);

      return ApiResponse<void>(
        success: true,
        data: null,
        message: 'All notifications marked as read',
        statusCode: 200,
      );
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        data: null,
        message: 'Failed to mark all notifications as read: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<void>> deleteNotification(String notificationId) async {
    try {
      await _apiClient.delete(
        'notifications/$notificationId',
        requiresAuth: true,
      );

      return ApiResponse<void>(
        success: true,
        data: null,
        message: 'Notification deleted successfully',
        statusCode: 200,
      );
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        data: null,
        message: 'Failed to delete notification: ${e.toString()}',
        statusCode: 500,
      );
    }
  }
}
