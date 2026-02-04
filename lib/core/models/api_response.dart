import 'package:json_annotation/json_annotation.dart';

part 'api_response.g.dart';

@JsonSerializable(genericArgumentFactories: true)
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int? statusCode;
  // Can add a more specific error object if needed, e.g., ApiError
  final dynamic error; // Or String? if error details are simple

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
    this.error,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$ApiResponseFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$ApiResponseToJson(this, toJsonT);
}

// Optional: Define a specific ApiError class if your backend returns structured errors
// @JsonSerializable()
// class ApiError {
//   final String? code;
//   final String? details;
//
//   ApiError({this.code, this.details});
//
//   factory ApiError.fromJson(Map<String, dynamic> json) => _$ApiErrorFromJson(json);
//   Map<String, dynamic> toJson() => _$ApiErrorToJson(this);
// }
