import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static final _cloudinary = CloudinaryPublic(
    'dn2mwp1lc',
    'aura_chat',
    cache: false,
  );

  // Backend delete endpoint
  static const String _deleteEndpoint = 'https://aurachat-backend-5utu.onrender.com/delete-cloudinary';

  // Backend API key for delete authentication
  static const String _backendApiKey = 'aura_chat_secret_2026_xyz';

  static Future<String?> uploadImage(File file, String folder) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      print('Cloudinary image upload successful: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e, stackTrace) {
      print('Cloudinary image upload error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  static Future<String?> uploadVideo(File file, String folder) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Video,
        ),
      );
      print('Cloudinary video upload successful: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e, stackTrace) {
      print('Cloudinary video upload error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  static Future<String?> uploadAudio(File file, String folder) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Video,
        ),
      );
      print('Cloudinary audio upload successful: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e, stackTrace) {
      print('Cloudinary audio upload error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  static Future<String?> uploadFile(File file, String folder) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Auto,
        ),
      );
      print('Cloudinary file upload successful: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e, stackTrace) {
      print('Cloudinary file upload error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Extract public_id from Cloudinary URL
  static String? extractPublicId(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final uploadIndex = segments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex + 2 >= segments.length) return null;

      final publicId = segments.sublist(uploadIndex + 2).join('/');
      return publicId.contains('.') 
        ? publicId.substring(0, publicId.lastIndexOf('.')) 
        : publicId;
    } catch (e) {
      print('Extract public_id error: $e');
      return null;
    }
  }

  /// Delete file from Cloudinary via backend
  static Future<bool> deleteFile(String? url) async {
    if (url == null || url.isEmpty) return false;

    final publicId = extractPublicId(url);
    if (publicId == null) {
      print('Could not extract public_id from: $url');
      return false;
    }

    try {
      print('Deleting from Cloudinary: $publicId');
      final response = await http.post(
        Uri.parse(_deleteEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _backendApiKey,
        },
        body: jsonEncode({'public_id': publicId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Delete result: ${data['message'] ?? data['error']}');
        return data['success'] == true;
      }
      print('Delete failed: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      print('Delete request error: $e');
      return false;
    }
  }

  /// Alias for deleteFile - deletes an image from Cloudinary
  static Future<bool> deleteImage(String? url) async {
    return deleteFile(url);
  }

  /// Delete multiple files at once
  static Future<Map<String, bool>> deleteMultiple(List<String> urls) async {
    final results = <String, bool>{};
    for (final url in urls) {
      results[url] = await deleteFile(url);
    }
    return results;
  }
}
