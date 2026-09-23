import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../container_injector.dart';
import 'media_file_utils.dart';
import '../api/interceptors.dart';
import '../utils/app_constants.dart';

class DioHelper {
  final Dio dio;

  DioHelper({required this.dio}) {
    dio.options = BaseOptions(
      baseUrl: AppConstants.cobaltBaseUrl,
      receiveDataWhenStatusError: true,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
    );
    if (kDebugMode) dio.interceptors.add(sl<LogInterceptor>());
    dio.interceptors.add(sl<AppInterceptors>());
  }

  Future<Response> get({
    required String path,
    Map<String, dynamic>? queryParams,
    String? baseUrl,
    Map<String, dynamic>? customHeaders,
  }) async {
    if (baseUrl != null) {
      final tempDio = Dio();
      tempDio.options = BaseOptions(
        baseUrl: baseUrl,
        receiveDataWhenStatusError: true,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: customHeaders ?? dio.options.headers,
      );
      if (kDebugMode) tempDio.interceptors.add(sl<LogInterceptor>());
      return await tempDio.get(path, queryParameters: queryParams);
    }
    return await dio.get(path, queryParameters: queryParams);
  }

  Future<Response> post({
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParams,
    String? baseUrl,
    Map<String, dynamic>? customHeaders,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) async {
    if (baseUrl != null) {
      final tempDio = Dio();
      tempDio.options = BaseOptions(
        baseUrl: baseUrl,
        receiveDataWhenStatusError: true,
        connectTimeout: connectTimeout ?? const Duration(seconds: 15),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
        headers: customHeaders ?? {"Content-Type": "application/json"},
      );
      if (kDebugMode) tempDio.interceptors.add(sl<LogInterceptor>());
      return await tempDio.post(
        path,
        data: data,
        queryParameters: queryParams,
      );
    }

    return await dio.post(
      path,
      data: data,
      queryParameters: queryParams,
    );
  }

  Future<Response> download({
    required String downloadLink,
    required String savePath,
    CancelToken? cancelToken,
    Function(int received, int total)? onReceiveProgress,
  }) async {
    Dio downloadDio = Dio();

    downloadDio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(seconds: 30),
      followRedirects: true,
      maxRedirects: 10,
    );

    RandomAccessFile? raf;

    try {
      // Get estimated size from headers for progress tracking
      int estimatedTotal = -1;

      Response<ResponseBody> response = await downloadDio.get<ResponseBody>(
        downloadLink,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            "Accept": "*/*",
            "User-Agent":
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          },
          responseType: ResponseType.stream,
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception(
            "Download failed with status code: ${response.statusCode}");
      }

      // Use Content-Length or Estimated-Content-Length for progress
      final headers = response.headers;
      final contentLength = headers.value('content-length');
      final estimatedLength = headers.value('estimated-content-length');
      if (contentLength != null) {
        estimatedTotal = int.tryParse(contentLength) ?? -1;
      } else if (estimatedLength != null) {
        estimatedTotal = int.tryParse(estimatedLength) ?? -1;
      }

      final file = File('$savePath.part');

      final directory = file.parent;
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }

      raf = file.openSync(mode: FileMode.write);
      int received = 0;

      await response.data!.stream.listen(
        (data) {
          raf!.writeFromSync(data);
          received += data.length;
          if (onReceiveProgress != null && estimatedTotal > 0) {
            onReceiveProgress(received, estimatedTotal);
          }
        },
        onError: (error) {
          throw Exception("Stream error during download: $error");
        },
        cancelOnError: true,
      ).asFuture();

      // Close file AFTER stream completes (not inside onDone)
      await raf.close();
      raf = null;

      if (!file.existsSync()) {
        throw Exception("Download failed: File was not created");
      }

      final fileSize = file.lengthSync();
      if (fileSize == 0) {
        await file.delete();
        throw Exception("Download failed: File is empty");
      }
      final prefix = file.readAsBytesSync().take(32).toList();
      MediaFileUtils.validate(
        bytes: prefix,
        contentType: headers.value('content-type'),
        received: fileSize,
        expected: estimatedTotal,
      );
      final destination = File(savePath);
      if (destination.existsSync()) await destination.delete();
      await file.rename(savePath);

      return response;
    } catch (e) {
      try {
        await raf?.close();
        final file = File('$savePath.part');
        if (file.existsSync()) await file.delete();
      } catch (_) {}
      rethrow;
    }
  }

  static String? detectMediaFormat(List<int> bytes) {
    if (bytes.length < 8) return null;

    // MP4/MOV: ftyp atom at offset 4
    if (bytes.length >= 8 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      return '.mp4';
    }
    // WebM: 1A 45 DF A3
    if (bytes[0] == 0x1A &&
        bytes[1] == 0x45 &&
        bytes[2] == 0xDF &&
        bytes[3] == 0xA3) {
      return '.webm';
    }
    // MKV shares same magic as WebM
    // FLV: 46 4C 56
    if (bytes[0] == 0x46 && bytes[1] == 0x4C && bytes[2] == 0x56) {
      return '.flv';
    }
    // AVI: RIFF....AVI
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes.length >= 12 &&
        bytes[8] == 0x41 &&
        bytes[9] == 0x56 &&
        bytes[10] == 0x49) {
      return '.avi';
    }
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return '.jpg';
    // PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return '.png';
    }
    // WebP: RIFF....WEBP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes.length >= 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return '.webp';
    }
    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return '.gif';
    }
    // MP3: ID3 or FF FB/FF F3/FF F2
    if ((bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) ||
        (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0)) {
      return '.mp3';
    }

    return null;
  }

  Future<Response> downloadImage({
    required String downloadLink,
    required String savePath,
    CancelToken? cancelToken,
    Function(int received, int total)? onReceiveProgress,
  }) async {
    Dio imageDio = Dio();

    imageDio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(seconds: 20),
      followRedirects: true,
      maxRedirects: 10,
    );

    RandomAccessFile? raf;

    try {
      Response<ResponseBody> response = await imageDio.get<ResponseBody>(
        downloadLink,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            "Accept": "image/*,*/*",
            "User-Agent":
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Cache-Control": "no-cache",
          },
          responseType: ResponseType.stream,
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception(
            "Image download failed with status code: ${response.statusCode}");
      }

      final contentLength = response.headers.value('content-length');
      final total =
          contentLength != null ? int.tryParse(contentLength) ?? -1 : -1;

      final file = File('$savePath.part');

      final directory = file.parent;
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }

      raf = file.openSync(mode: FileMode.write);
      int received = 0;

      await response.data!.stream.listen(
        (data) {
          raf!.writeFromSync(data);
          received += data.length;
          if (onReceiveProgress != null && total > 0) {
            onReceiveProgress(received, total);
          }
        },
        onError: (error) {
          throw Exception("Stream error during image download: $error");
        },
        cancelOnError: true,
      ).asFuture();

      await raf.close();
      raf = null;

      if (!file.existsSync()) {
        throw Exception("Image download failed: File was not created");
      }

      final fileSize = file.lengthSync();
      if (fileSize == 0) {
        await file.delete();
        throw Exception("Image download failed: File is empty");
      }

      final bytes = file.readAsBytesSync().take(32).toList();
      final extension = MediaFileUtils.validate(
        bytes: bytes,
        contentType: response.headers.value('content-type'),
        received: fileSize,
        expected: total,
      );
      if (!const ['.jpg', '.png', '.webp', '.gif'].contains(extension)) {
        await file.delete();
        throw Exception("Downloaded file is not a valid image format");
      }
      final destination = File(savePath);
      if (destination.existsSync()) await destination.delete();
      await file.rename(savePath);

      return response;
    } catch (e) {
      try {
        await raf?.close();
        final file = File('$savePath.part');
        if (file.existsSync()) await file.delete();
      } catch (_) {}
      rethrow;
    }
  }
}
