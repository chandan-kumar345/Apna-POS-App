import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../utils/image_compress_helper.dart';

class UploadService {
  final ApiClient _client = ApiClient();

  /// Upload an image file to Cloudflare R2 / Server Storage
  /// [file]: Local File object
  /// [folder]: Target folder ('products', 'profiles', 'outlets', 'receipts')
  /// Automatically compresses image before uploading for maximum speed and minimum payload.
  /// Returns the remote public image URL (or null on failure)
  Future<String?> uploadImage(File file, {String folder = 'products'}) async {
    try {
      final fileName = file.path.split(RegExp(r'[\\/]')).last;
      final compressedBytes = await ImageCompressHelper.compressImageFile(file);
      final cleanFileName = fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')
          ? fileName
          : '${fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}.jpg';

      return await uploadImageBytes(
        compressedBytes,
        fileName: cleanFileName,
        folder: folder,
        skipCompression: true, // Already compressed
      );
    } catch (e) {
      debugPrint('[UploadService] Upload failed: $e');
      return null;
    }
  }

  /// Upload image bytes directly to Cloudflare R2 / Server Storage
  /// Automatically compresses image bytes before uploading for 10x-30x faster uploads.
  Future<String?> uploadImageBytes(
    Uint8List bytes, {
    String fileName = 'image.jpg',
    String folder = 'products',
    bool skipCompression = false,
  }) async {
    try {
      final finalBytes = skipCompression
          ? bytes
          : await ImageCompressHelper.compressImageBytes(bytes);

      final cleanFileName = fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')
          ? fileName
          : '${fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}.jpg';

      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          finalBytes,
          filename: cleanFileName,
        ),
      });

      final response = await _client.post(
        '${ApiEndpoints.uploadImage}?folder=$folder',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response != null && response is Map<String, dynamic>) {
        if (response['success'] == true && response['data'] != null) {
          final imageUrl = response['data']['imageUrl']?.toString();
          debugPrint('[UploadService] Image uploaded successfully: $imageUrl');
          return imageUrl;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[UploadService] Upload bytes failed: $e');
      return null;
    }
  }

  /// Upload a video file to Cloudflare R2 / Server Storage
  /// [file]: Local File object
  /// [folder]: Target folder ('products/videos')
  /// Returns the remote public video URL (or null on failure)
  Future<String?> uploadVideo(File file, {String folder = 'products/videos'}) async {
    try {
      final fileName = file.path.split(RegExp(r'[\\/]')).last;
      final formData = FormData.fromMap({
        'video': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final response = await _client.post(
        '${ApiEndpoints.uploadVideo}?folder=$folder',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      if (response != null && response is Map<String, dynamic>) {
        if (response['success'] == true && response['data'] != null) {
          final videoUrl = response['data']['videoUrl']?.toString();
          debugPrint('[UploadService] Video uploaded successfully: $videoUrl');
          return videoUrl;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[UploadService] Video upload failed: $e');
      return null;
    }
  }

  /// Upload video bytes directly to Cloudflare R2 / Server Storage
  Future<String?> uploadVideoBytes(
    Uint8List bytes, {
    String fileName = 'video.mp4',
    String folder = 'products/videos',
  }) async {
    try {
      final formData = FormData.fromMap({
        'video': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
        ),
      });

      final response = await _client.post(
        '${ApiEndpoints.uploadVideo}?folder=$folder',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      if (response != null && response is Map<String, dynamic>) {
        if (response['success'] == true && response['data'] != null) {
          final videoUrl = response['data']['videoUrl']?.toString();
          debugPrint('[UploadService] Video uploaded successfully: $videoUrl');
          return videoUrl;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[UploadService] Video upload bytes failed: $e');
      return null;
    }
  }

  /// Upload an audio ringtone file to Server / Cloudflare R2
  /// [file]: Audio File or bytes
  /// [type]: 'notification' or 'order'
  /// [name]: Custom label / title for the ringtone
  Future<Map<String, dynamic>?> uploadRingtone({
    File? file,
    Uint8List? bytes,
    required String fileName,
    String type = 'order',
    String? name,
  }) async {
    try {
      final multipartFile = file != null
          ? await MultipartFile.fromFile(file.path, filename: fileName)
          : MultipartFile.fromBytes(bytes!, filename: fileName);

      final formData = FormData.fromMap({
        'audio': multipartFile,
        'type': type,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      });

      final response = await _client.post(
        ApiEndpoints.uploadRingtone,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      if (response != null && response is Map<String, dynamic>) {
        if (response['success'] == true && response['data'] != null) {
          final data = Map<String, dynamic>.from(response['data'] as Map);
          debugPrint('[UploadService] Ringtone uploaded successfully: ${data['url']}');
          return data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[UploadService] Ringtone upload failed: $e');
      return null;
    }
  }
}
