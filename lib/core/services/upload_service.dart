import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class UploadService {
  final ApiClient _client = ApiClient();

  /// Upload an image file to Cloudflare R2 / Server Storage
  /// [file]: Local File object
  /// [folder]: Target folder ('products', 'profiles', 'outlets', 'receipts')
  /// Returns the remote public image URL (or null on failure)
  Future<String?> uploadImage(File file, {String folder = 'products'}) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final response = await _client.post(
        '${ApiEndpoints.uploadImage}?folder=$folder',
        data: formData,
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
      debugPrint('[UploadService] Upload failed: $e');
      return null;
    }
  }
}
