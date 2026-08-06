import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static final _cloudinary = CloudinaryPublic(
    'dn2mwp1lc',    // Your cloud name
    'aura_chat',     // Your unsigned upload preset
    cache: false,
  );

  static Future<String?> uploadImage(File imageFile, String folder) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      print('Cloudinary upload successful: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e, stackTrace) {
      print('Cloudinary upload error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
}
