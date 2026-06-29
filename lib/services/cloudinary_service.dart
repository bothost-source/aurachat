import 'dart:io';
import 'package:cloudinary/cloudinary.dart';
import 'cloudinary_config.dart';

class CloudinaryService {
  static final Cloudinary _cloudinary = Cloudinary.unsignedConfig(
    cloudName: CloudinaryConfig.cloudName,
  );

  static Future<String?> uploadImage(File imageFile, String folder) async {
    try {
      // Read file bytes - REQUIRED by the cloudinary package
      final fileBytes = await imageFile.readAsBytes();

      final response = await _cloudinary.unsignedUpload(
        file: imageFile.path,
        fileBytes: fileBytes, // <-- THIS WAS MISSING!
        uploadPreset: 'aura_chat',
        resourceType: CloudinaryResourceType.image,
        folder: folder,
      );
      
      if (response.isSuccessful) {
        print(' upload successful: ${response.secureUrl}');
        return response.secureUrl;
      } else {
        print(' upload failed: ${response.error}');
        return null;
      }
    } catch (e, stackTrace) {
      print(' error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
}
