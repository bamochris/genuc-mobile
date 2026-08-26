class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;

  ApiResponse({
    this.success = false,
    this.data,
    this.error,
    this.statusCode,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJson,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      data: fromJson != null && json['data'] != null
          ? fromJson(json['data'])
          : null,
      error: json['error'] as String?,
      statusCode: json['statusCode'] as int?,
    );
  }
}
