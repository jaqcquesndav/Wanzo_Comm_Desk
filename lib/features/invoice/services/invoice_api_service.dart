import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/features/invoice/models/invoice.dart';
import 'package:wanzo/core/models/api_response.dart';

abstract class InvoiceApiService {
  Future<ApiResponse<List<Invoice>>> getInvoices({
    int? page,
    int? limit,
    String? customerId,
    InvoiceStatus? status,
    String? dateFrom,
    String? dateTo,
    String? sortBy,
    String? sortOrder,
    String? searchQuery, // For invoice number or customer name
  });

  Future<ApiResponse<Invoice>> createInvoice(
    Invoice invoice, {
    File? pdfAttachment,
  }); // PDF could be generated client or server side

  Future<ApiResponse<Invoice>> getInvoiceById(String id);

  Future<ApiResponse<Invoice>> updateInvoice(
    String id,
    Invoice invoice, {
    File? pdfAttachment,
  });

  Future<ApiResponse<void>> deleteInvoice(String id);

  Future<ApiResponse<Invoice>> updateInvoiceStatus(
    String id,
    InvoiceStatus status,
  );

  Future<ApiResponse<void>> sendInvoiceByEmail(String id, String emailAddress);
}

class InvoiceApiServiceImpl implements InvoiceApiService {
  final ApiClient _apiClient;

  InvoiceApiServiceImpl(this._apiClient);

  @override
  Future<ApiResponse<List<Invoice>>> getInvoices({
    int? page,
    int? limit,
    String? customerId,
    InvoiceStatus? status,
    String? dateFrom,
    String? dateTo,
    String? sortBy,
    String? sortOrder,
    String? searchQuery,
  }) async {
    try {
      final queryParameters = <String, String>{
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (customerId != null) 'customerId': customerId,
        if (status != null) 'status': status.name,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (searchQuery != null) 'q': searchQuery,
      };

      final response = await _apiClient.get(
        'invoices',
        queryParameters: queryParameters,
        requiresAuth: true,
      );

      if (response != null) {
        if (response is List<dynamic>) {
          // Direct list response
          final invoices =
              response
                  .map((json) => Invoice.fromJson(json as Map<String, dynamic>))
                  .toList();

          return ApiResponse<List<Invoice>>(
            success: true,
            data: invoices,
            message: 'Invoices retrieved successfully',
            statusCode: 200,
          );
        } else if (response is Map<String, dynamic> &&
            response['data'] != null) {
          // Wrapped response with data field
          final List<dynamic> data = response['data'] as List<dynamic>;
          final invoices =
              data
                  .map((json) => Invoice.fromJson(json as Map<String, dynamic>))
                  .toList();

          return ApiResponse<List<Invoice>>(
            success: true,
            data: invoices,
            message:
                response['message'] as String? ??
                'Invoices retrieved successfully',
            statusCode: response['statusCode'] as int? ?? 200,
          );
        }
      }

      return ApiResponse<List<Invoice>>(
        success: false,
        data: [],
        message: 'Failed to retrieve invoices: Invalid response format',
        statusCode: 500,
      );
    } catch (e) {
      return ApiResponse<List<Invoice>>(
        success: false,
        data: [],
        message: 'Failed to retrieve invoices: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Invoice>> createInvoice(
    Invoice invoice, {
    File? pdfAttachment,
  }) async {
    try {
      // If PDF is attached, it implies a multipart request. Otherwise, JSON.
      if (pdfAttachment != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse(_apiClient.getFullUrl('invoices')),
        );
        request.headers.addAll(await _apiClient.getHeaders(requiresAuth: true));
        request.fields['invoiceData'] =
            invoice.toJson().toString(); // Send invoice data as a JSON string
        request.files.add(
          await http.MultipartFile.fromPath('pdf', pdfAttachment.path),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        final responseData = _apiClient.handleResponse(response);

        final createdInvoice = Invoice.fromJson(
          responseData as Map<String, dynamic>,
        );

        return ApiResponse<Invoice>(
          success: true,
          data: createdInvoice,
          message: 'Invoice created successfully',
          statusCode: 201,
        );
      } else {
        final response = await _apiClient.post(
          'invoices',
          body: invoice.toJson(),
          requiresAuth: true,
        );

        if (response != null) {
          final Map<String, dynamic> data;
          if (response is Map<String, dynamic> && response['data'] != null) {
            data = response['data'] as Map<String, dynamic>;
          } else {
            data = response as Map<String, dynamic>;
          }

          final createdInvoice = Invoice.fromJson(data);

          return ApiResponse<Invoice>(
            success: true,
            data: createdInvoice,
            message: 'Invoice created successfully',
            statusCode: 201,
          );
        }
      }

      return ApiResponse<Invoice>(
        success: false,
        data: null,
        message: 'Failed to create invoice: Invalid response',
        statusCode: 500,
      );
    } catch (e) {
      return ApiResponse<Invoice>(
        success: false,
        data: null,
        message: 'Failed to create invoice: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Invoice>> getInvoiceById(String id) async {
    try {
      final response = await _apiClient.get('invoices/$id', requiresAuth: true);

      if (response != null) {
        final Map<String, dynamic> data;
        if (response is Map<String, dynamic> && response['data'] != null) {
          data = response['data'] as Map<String, dynamic>;
        } else {
          data = response as Map<String, dynamic>;
        }

        final invoice = Invoice.fromJson(data);

        return ApiResponse<Invoice>(
          success: true,
          data: invoice,
          message: 'Invoice retrieved successfully',
          statusCode: 200,
        );
      }

      return ApiResponse<Invoice>(
        success: false,
        data: null,
        message: 'Failed to retrieve invoice: Invalid response',
        statusCode: 500,
      );
    } catch (e) {
      return ApiResponse<Invoice>(
        success: false,
        data: null,
        message: 'Failed to retrieve invoice: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Invoice>> updateInvoice(
    String id,
    Invoice invoice, {
    File? pdfAttachment,
  }) async {
    try {
      if (pdfAttachment != null) {
        final request = http.MultipartRequest(
          'PUT',
          Uri.parse(_apiClient.getFullUrl('invoices/$id')),
        );
        request.headers.addAll(await _apiClient.getHeaders(requiresAuth: true));
        request.fields['invoiceData'] = invoice.toJson().toString();
        request.files.add(
          await http.MultipartFile.fromPath('pdf', pdfAttachment.path),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        final responseData = _apiClient.handleResponse(response);

        final updatedInvoice = Invoice.fromJson(
          responseData as Map<String, dynamic>,
        );

        return ApiResponse<Invoice>(
          success: true,
          data: updatedInvoice,
          message: 'Invoice updated successfully',
          statusCode: 200,
        );
      } else {
        final response = await _apiClient.put(
          'invoices/$id',
          body: invoice.toJson(),
          requiresAuth: true,
        );

        if (response != null) {
          final Map<String, dynamic> data;
          if (response is Map<String, dynamic> && response['data'] != null) {
            data = response['data'] as Map<String, dynamic>;
          } else {
            data = response as Map<String, dynamic>;
          }

          final updatedInvoice = Invoice.fromJson(data);

          return ApiResponse<Invoice>(
            success: true,
            data: updatedInvoice,
            message: 'Invoice updated successfully',
            statusCode: 200,
          );
        }
      }

      return ApiResponse<Invoice>(
        success: false,
        data: null,
        message: 'Failed to update invoice: Invalid response',
        statusCode: 500,
      );
    } catch (e) {
      return ApiResponse<Invoice>(
        success: false,
        data: null,
        message: 'Failed to update invoice: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<void>> deleteInvoice(String id) async {
    try {
      await _apiClient.delete('invoices/$id', requiresAuth: true);

      return ApiResponse<void>(
        success: true,
        data: null,
        message: 'Invoice deleted successfully',
        statusCode: 200,
      );
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        data: null,
        message: 'Failed to delete invoice: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<Invoice>> updateInvoiceStatus(
    String id,
    InvoiceStatus status,
  ) async {
    try {
      final response = await _apiClient.put(
        'invoices/$id/status',
        body: {'status': status.name},
        requiresAuth: true,
      );

      if (response != null) {
        final Map<String, dynamic> data;
        if (response is Map<String, dynamic> && response['data'] != null) {
          data = response['data'] as Map<String, dynamic>;
        } else {
          data = response as Map<String, dynamic>;
        }

        final updatedInvoice = Invoice.fromJson(data);

        return ApiResponse<Invoice>(
          success: true,
          data: updatedInvoice,
          message: 'Invoice status updated successfully',
          statusCode: 200,
        );
      }

      return ApiResponse<Invoice>(
        success: false,
        data: null,
        message: 'Failed to update invoice status: Invalid response',
        statusCode: 500,
      );
    } catch (e) {
      return ApiResponse<Invoice>(
        success: false,
        data: null,
        message: 'Failed to update invoice status: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<ApiResponse<void>> sendInvoiceByEmail(
    String id,
    String emailAddress,
  ) async {
    try {
      await _apiClient.post(
        'invoices/$id/send-email',
        body: {'email': emailAddress},
        requiresAuth: true,
      );

      return ApiResponse<void>(
        success: true,
        data: null,
        message: 'Invoice sent by email successfully',
        statusCode: 200,
      );
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        data: null,
        message: 'Failed to send invoice by email: ${e.toString()}',
        statusCode: 500,
      );
    }
  }
}
