import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ServerErrorHandler {
  static const int _timeoutSeconds = 60;
  static const String _baseUrl = 'http://105.96.12.227:8000';

  /// Handles server communication with comprehensive error handling
  static Future<Map<String, dynamic>> sendRequest({
    required String endpoint,
    required Map<String, String> fields,
    required List<Map<String, dynamic>> files,
    required BuildContext context,
    String? successMessage,
    String? errorMessage,
  }) async {
    try {
      // Show loading indicator
      _showLoadingDialog(context);

      // Create request with timeout
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl$endpoint'),
      );

      // Add fields
      request.fields.addAll(fields);

      // Add files
      for (var file in files) {
        request.files.add(
          await http.MultipartFile.fromPath(
            file['fieldName'],
            file['filePath'],
          ),
        );
      }

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        Duration(seconds: _timeoutSeconds),
        onTimeout: () {
          throw TimeoutException('Request timed out after $_timeoutSeconds seconds');
        },
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Handle response
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = await _handleResponse(response, context);

      // Show success message if provided
      if (successMessage != null) {
        _showSuccessSnackBar(context, successMessage);
      }

      return responseData;

    } on SocketException catch (e) {
      _handleNetworkError(context, e);
      rethrow;
    } on TimeoutException catch (e) {
      _handleTimeoutError(context, e);
      rethrow;
    } on FormatException catch (e) {
      _handleFormatError(context, e);
      rethrow;
    } on HttpException catch (e) {
      _handleHttpError(context, e);
      rethrow;
    } catch (e) {
      _handleGenericError(context, e);
      rethrow;
    }
  }

  /// Handles simple POST requests
  static Future<Map<String, dynamic>> sendSimpleRequest({
    required String endpoint,
    required Map<String, dynamic> data,
    required BuildContext context,
    String? successMessage,
    String? errorMessage,
  }) async {
    try {
      _showLoadingDialog(context);

      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: data,
      ).timeout(
        Duration(seconds: _timeoutSeconds),
        onTimeout: () {
          throw TimeoutException('Request timed out after $_timeoutSeconds seconds');
        },
      );

      Navigator.of(context).pop();
      return await _handleResponse(response, context);

    } on SocketException catch (e) {
      _handleNetworkError(context, e);
      rethrow;
    } on TimeoutException catch (e) {
      _handleTimeoutError(context, e);
      rethrow;
    } catch (e) {
      _handleGenericError(context, e);
      rethrow;
    }
  }

  /// Handles response parsing and error checking
  static Future<Map<String, dynamic>> _handleResponse(
    http.Response response,
    BuildContext context,
  ) async {
    try {
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData;
      } else if (response.statusCode == 401) {
        _showErrorSnackBar(
          context,
          'Authentication failed. Please check your credentials.',
          Icons.lock,
        );
        throw UnauthorizedException('Authentication failed');
      } else if (response.statusCode == 403) {
        _showErrorSnackBar(
          context,
          'Access denied. You don\'t have permission to perform this action.',
          Icons.block,
        );
        throw ForbiddenException('Access denied');
      } else if (response.statusCode == 404) {
        _showErrorSnackBar(
          context,
          'Service not found. Please check the endpoint.',
          Icons.error_outline,
        );
        throw NotFoundException('Service not found');
      } else if (response.statusCode == 500) {
        _showErrorSnackBar(
          context,
          'Server error. Please try again later.',
          Icons.error,
        );
        throw ServerException('Internal server error');
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        _showErrorSnackBar(
          context,
          'Client error. Please check your request.',
          Icons.warning,
        );
        throw ClientException('Client error: ${response.statusCode}');
      } else if (response.statusCode >= 500) {
        _showErrorSnackBar(
          context,
          'Server error. Please try again later.',
          Icons.error,
        );
        throw ServerException('Server error: ${response.statusCode}');
      } else {
        _showErrorSnackBar(
          context,
          'Unexpected response: ${response.statusCode}',
          Icons.error,
        );
        throw UnexpectedResponseException('Unexpected response: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      _showErrorSnackBar(
        context,
        'Invalid response format from server.',
        Icons.error,
      );
      throw FormatException('Invalid JSON response: ${e.message}');
    }
  }

  /// Shows loading dialog
  static void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                ),
                SizedBox(height: 20),
                Text(
                  'Processing your request...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Please wait while we process your data',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows error snackbar with icon
  static void _showErrorSnackBar(
    BuildContext context,
    String message,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Shows success snackbar
  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Handles network errors
  static void _handleNetworkError(BuildContext context, SocketException e) {
    Navigator.of(context).pop(); // Close loading dialog
    _showErrorSnackBar(
      context,
      'No internet connection. Please check your network and try again.',
      Icons.wifi_off,
    );
  }

  /// Handles timeout errors
  static void _handleTimeoutError(BuildContext context, TimeoutException e) {
    Navigator.of(context).pop(); // Close loading dialog
    _showErrorSnackBar(
      context,
      'Request timed out. Please try again.',
      Icons.timer_off,
    );
  }

  /// Handles format errors
  static void _handleFormatError(BuildContext context, FormatException e) {
    Navigator.of(context).pop(); // Close loading dialog
    _showErrorSnackBar(
      context,
      'Invalid data format. Please try again.',
      Icons.error_outline,
    );
  }

  /// Handles HTTP errors
  static void _handleHttpError(BuildContext context, HttpException e) {
    Navigator.of(context).pop(); // Close loading dialog
    _showErrorSnackBar(
      context,
      'HTTP error occurred. Please try again.',
      Icons.error,
    );
  }

  /// Handles generic errors
  static void _handleGenericError(BuildContext context, dynamic e) {
    Navigator.of(context).pop(); // Close loading dialog
    _showErrorSnackBar(
      context,
      'An unexpected error occurred. Please try again.',
      Icons.error,
    );
  }

  /// Shows retry dialog
  static Future<bool> showRetryDialog(BuildContext context, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.refresh, color: Colors.orange),
            SizedBox(width: 10),
            Text('Retry'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Handles server communication with retry mechanism
  static Future<Map<String, dynamic>> sendRequestWithRetry({
    required String endpoint,
    required Map<String, String> fields,
    required List<Map<String, dynamic>> files,
    required BuildContext context,
    String? successMessage,
    String? errorMessage,
    int maxRetries = 3,
  }) async {
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        return await sendRequest(
          endpoint: endpoint,
          fields: fields,
          files: files,
          context: context,
          successMessage: successMessage,
          errorMessage: errorMessage,
        );
      } catch (e) {
        retryCount++;
        
        if (retryCount >= maxRetries) {
          // Show final error and rethrow
          _showErrorSnackBar(
            context,
            'Failed after $maxRetries attempts. Please try again later.',
            Icons.error,
          );
          rethrow;
        }
        
        // Show retry dialog
        final shouldRetry = await showRetryDialog(
          context,
          'Request failed. Would you like to retry? (Attempt $retryCount/$maxRetries)',
        );
        
        if (!shouldRetry) {
          throw Exception('User cancelled retry');
        }
        
        // Wait before retrying
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
    
    throw Exception('Max retries exceeded');
  }
}

// Custom exception classes
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  @override
  String toString() => message;
}

class ForbiddenException implements Exception {
  final String message;
  ForbiddenException(this.message);
  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
  @override
  String toString() => message;
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
  @override
  String toString() => message;
}

class ClientException implements Exception {
  final String message;
  ClientException(this.message);
  @override
  String toString() => message;
}

class UnexpectedResponseException implements Exception {
  final String message;
  UnexpectedResponseException(this.message);
  @override
  String toString() => message;
} 