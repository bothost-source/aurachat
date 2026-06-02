import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

class CreateStatusScreen extends StatefulWidget {
  const CreateStatusScreen({super.key});

  @override
  State<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends State<CreateStatusScreen> {
  final _textController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _createStatus() async {
    if (_textController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add text or an image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('Not authenticated');
      }

      String? mediaUrl;

      // Upload image if selected
      if (_selectedImage != null) {
        final fileBytes = await _selectedImage!.readAsBytes();
        final fileName = 'statuses/$userId/${const Uuid().v4()}.jpg';

        await supabase.storage.from('statuses').uploadBinary(
          fileName,
          fileBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

        mediaUrl = supabase.storage.from('statuses').getPublicUrl(fileName);
      }

      // Create status (expires in 24 hours)
      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      await supabase.from('statuses').insert({
        'id': const Uuid().v4(),
        'user_id': userId,
        'text': _textController.text.trim().isNotEmpty ? _textController.text.trim() : null,
        'media_url': mediaUrl,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      });

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status added!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _createStatus,
              child: const Text(
                'Share',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _selectedImage != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        _selectedImage!,
                        fit: BoxFit.contain,
                      ),
                      Positioned(
                        bottom: 100,
                        left: 16,
                        right: 16,
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Add a caption...',
                            hintStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                          ),
                          maxLines: null,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Type a status...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(32),
                      ),
                      maxLines: null,
                      textAlign: TextAlign.center,
                      autofocus: true,
                    ),
                  ),
          ),

          // Bottom Actions
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: _pickImage,
                ),
                _buildActionButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: _takePhoto,
                ),
                if (_selectedImage != null)
                  _buildActionButton(
                    icon: Icons.delete,
                    label: 'Remove',
                    onTap: () => setState(() => _selectedImage = null),
                    color: Colors.red,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color ?? Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
