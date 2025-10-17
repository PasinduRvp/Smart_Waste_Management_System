import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal() {
    _initializeCloudinary();
  }

  late final CloudinaryPublic cloudinary;
  bool _isConfigured = false;

  void _initializeCloudinary() {
    const cloudName = 'dolnzsbuo'; // Your cloud name from Cloudinary dashboard
    const uploadPreset = 'yuunx9dc'; // Your upload preset from Cloudinary
    
    try {
      cloudinary = CloudinaryPublic(
        cloudName,
        uploadPreset,
        cache: false,
      );
      _isConfigured = true;
      print('✅ Cloudinary configured successfully with cloudName: $cloudName');
    } catch (e) {
      print('❌ Error initializing Cloudinary: $e');
      _isConfigured = false;
    }
  }

  Future<String?> uploadImage(XFile image, String userId) async {
    if (!_isConfigured) {
      print('❌ Cloudinary not configured. Cannot upload image.');
      return null;
    }

    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          folder: 'smart_waste/$userId',
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      print('✅ Image uploaded successfully: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      print('❌ Error uploading image to Cloudinary: $e');
      return null;
    }
  }

  Future<List<String>> uploadMultipleImages(List<XFile> images, String userId) async {
    if (!_isConfigured) {
      print('❌ Cloudinary not configured. Cannot upload images.');
      return [];
    }

    List<String> imageUrls = [];
    
    for (int i = 0; i < images.length; i++) {
      try {
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            images[i].path,
            folder: 'smart_waste/$userId',
            resourceType: CloudinaryResourceType.Image,
          ),
        );
        imageUrls.add(response.secureUrl);
        print('✅ Image ${i + 1} uploaded successfully');
      } catch (e) {
        print('❌ Error uploading image ${i + 1}: $e');
      }
    }
    
    return imageUrls;
  }

  bool get isConfigured => _isConfigured;
}