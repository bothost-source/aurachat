import 'dart:io';
import 'package:cloudinary/cloudinary.dart';
import 'cloudinary_config.dart';

class CloudinaryService {
  static final Cloudinary _cloudinary = Cloudinary.unsignedConfig(
    cloudName: CloudinaryConfig.cloudName,
  );

  static Future<String?> uploadImage(File imageFile, String folder) async {
    try {
      final response = await _cloudinary.unsignedUpload(
        file: imageFile.path,
        uploadPreset: 'aura_chat',
        resourceType: CloudinaryResourceType.image,
        folder: folder,
      );
      
      if (response.isSuccessful) {
        return response.secureUrl;
      } else {
        print('Cloudinary upload failed: ${response.error}');
        return null;
      }
    } catch (e) {
      print('Cloudinary error: $e');
      return null;
    }
  }
}

