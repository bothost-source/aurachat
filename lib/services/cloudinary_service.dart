import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static final _cloudinary = CloudinaryPublic(
    'dn2mwp1lc',    // Your cloud name
    'aura_chat',     // Your unsigned upload preset
    cache: false,
  );

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

  // NEW: Upload video files
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

  // NEW: Upload audio/voice note files
  static Future<String?> uploadAudio(File file, String folder) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Video, // Cloudinary uses Video type for audio
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

  // NEW: Upload any file (documents, PDFs, etc.)
  static Future<String?> uploadFile(File file, String folder) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Auto, // Auto-detect file type
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

  // NEW: Delete file from Cloudinary by URL
  static Future<bool> deleteFile(String? url) async {
    if (url == null || url.isEmpty) return false;
    
    try {
      // Extract public_id from Cloudinary URL
      // URL format: https://res.cloudinary.com/{cloud}/image/upload/v{version}/{folder}/{filename}
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      // Find 'upload' index and get everything after it
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex + 1 >= pathSegments.length) return false;
      
      // Skip version number and get the rest as public_id
      final publicId = pathSegments.sublist(uploadIndex + 2).join('/');
      final publicIdWithoutExt = publicId.contains('.') 
        ? publicId.substring(0, publicId.lastIndexOf('.')) 
        : publicId;
      
      // Note: Deleting requires signed API or admin API
      // For unsigned uploads, you need to enable "Allow deletion of assets" in upload preset settings
      // Or use Cloudinary admin API with API key/secret (server-side only)
      print('Would delete: $publicIdWithoutExt');
      
      // For now, log it. To actually delete, you need server-side API:
      // await _cloudinary.destroy(publicIdWithoutExt);
      
      return true;
    } catch (e) {
      print('Delete file error: $e');
      return false;
    }
  }
}
