import 'dart:io';

import 'package:dio/dio.dart';

import 'failure.dart';

class ErrorHandler implements Exception {
  late Failure failure;

  ErrorHandler.handle(dynamic error) {
    if (error is DioException) {
      failure = _handleError(error);
    } else if (error is SocketException) {
      failure = const NoInternetConnectionFailure();
    } else if (error is FormatException) {
      failure = const BadRequestFailure();
    } else if (error is FileSystemException) {
      failure = const UnexpectedFailure();
    } else {
      failure = const UnexpectedFailure();
    }
  }
}

Failure _handleError(DioException dioError) {
  switch (dioError.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const ConnectTimeOutFailure();
    case DioExceptionType.badResponse:
      return _handleResponseError(dioError.response);
    case DioExceptionType.cancel:
      return const CancelRequestFailure();
    case DioExceptionType.unknown:
      // Check if it's a network issue or other problem
      if (dioError.error is SocketException) {
        return const NoInternetConnectionFailure();
      }
      return const UnexpectedFailure();
    case DioExceptionType.badCertificate:
      return const BadCertificateFailure();
    case DioExceptionType.connectionError:
      return const ConnectionErrorFailure();
  }
}

Failure _handleResponseError(Response? response) {
  final statusCode = response?.statusCode;
  final errorData = response?.data;

  switch (statusCode) {
    case 400:
      return const BadRequestFailure();
    case 401:
      return const BadRequestFailure();
    case 403:
      // Check if it's API subscription issue
      String message = "Access denied";
      if (errorData is Map && errorData['message'] != null) {
        message = errorData['message'].toString();
      }
      if (message.toLowerCase().contains('not subscribed') ||
          message.toLowerCase().contains('subscription')) {
        return const NotSubscribedFailure(
            message:
                "API subscription required. Please check your API keys in settings.");
      }
      return NotSubscribedFailure(message: message);
    case 404:
      return const NotFoundFailure();
    case 429:
      String message =
          "Rate limit exceeded. Please wait a moment and try again.";
      if (errorData is Map && errorData['message'] != null) {
        message = errorData['message'].toString();
      }
      return TooManyRequestsFailure(message: message);
    case 500:
    case 502:
    case 503:
      return const ServerFailure();
    default:
      return const UnexpectedFailure();
  }
}
