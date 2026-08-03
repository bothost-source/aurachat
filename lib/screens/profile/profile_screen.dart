import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../utils/verified_badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuraAuthProvider>(context);
    if (!_isEditing && !_isLoading) {
      _nameController.text = authProvider.userName ?? '';
      _bioController.text = authProvider.userBio ?? '';
    }
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    _nameController.text = authProvider.userName ?? '';
    _bioController.text = authProvider.userBio ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isLoading = true);

      try {
        final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
        final storage = FirebaseStorage.instance;
        final userId = authProvider.user?.uid ?? authProvider.mockUserId;

        if (userId == null) return;

        final fileBytes = await pickedFile.readAsBytes();
        final fileName = 'avatars/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

        final ref = storage.ref().child(fileName);
        await ref.putData(fileBytes);

        final imageUrl = await ref.getDownloadURL();

        await authProvider.updateProfile(photoUrl: imageUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated'),
              backgroundColor: Color(0xFF8B5CF6),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final success = await authProvider.updateProfile(
      username: _nameController.text.trim(),
      bio: _bioController.text.trim(),
    );

    setState(() {
      _isLoading = false;
      _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Profile updated' : 'Update failed: ${authProvider.error}',
          ),
          backgroundColor: success ? const Color(0xFF8B5CF6) : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuraAuthProvider>(
      builder: (context, authProvider, child) {
        final phone = authProvider.phoneNumber ?? '';
        final userVerified = isVerified(phone);

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
          body: CustomScrollView(
            slivers: [
              // Gradient app bar with profile
              SliverAppBar(
                expandedHeight: 300,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: const Color(0xFF0A0A0F),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF8B5CF6).withOpacity(0.3),
                          const Color(0xFF06B6D4).withOpacity(0.1),
                          const Color(0xFF0A0A0F),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          // Profile photo with glow — camera icon ALWAYS visible
                          Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.4),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: _buildAvatar(authProvider.userPhotoUrl),
                              ),
                              // Camera icon — always visible, not just in edit mode
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _isLoading ? null : _pickImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF8B5CF6).withOpacity(0.4),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Name with verified badge
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: VerifiedUsername(
                              username: authProvider.userName?.isNotEmpty == true
                                  ? authProvider.userName!
                                  : 'Your Name',
                              phoneNumber: phone,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              badgeSize: 18,
                              spacing: 8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phone,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          if (userVerified)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1DA1F2).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF1DA1F2).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const VerifiedBadge(size: 12, showTooltip: false),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Verified Account',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: const Color(0xFF1DA1F2).withOpacity(0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  if (!_isEditing)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => setState(() => _isEditing = true),
                    )
                  else
                    IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, color: Colors.white),
                      onPressed: _isLoading ? null : _saveProfile,
                    ),
                ],
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info cards
                      _buildGlassCard(
                        child: _isEditing
                            ? TextField(
                                controller: _nameController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Display Name',
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  border: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              )
                            : ListTile(
                                leading: Icon(
                                  Icons.person_outline,
                                  color: const Color(0xFF8B5CF6),
                                ),
                                title: Text(
                                  'Name',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                                subtitle: Text(
                                  authProvider.userName?.isNotEmpty == true
                                      ? authProvider.userName!
                                      : 'Not set',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                      ),

                      const SizedBox(height: 12),

                      _buildGlassCard(
                        child: _isEditing
                            ? TextField(
                                controller: _bioController,
                                maxLines: 3,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Bio',
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  border: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.info_outline,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              )
                            : ListTile(
                                leading: Icon(
                                  Icons.info_outline,
                                  color: const Color(0xFF06B6D4),
                                ),
                                title: Text(
                                  'Bio',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                                subtitle: Text(
                                  authProvider.userBio?.isNotEmpty == true
                                      ? authProvider.userBio!
                                      : 'No bio yet',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                      ),

                      const SizedBox(height: 12),

                      _buildGlassCard(
                        child: ListTile(
                          leading: Icon(
                            Icons.phone,
                            color: const Color(0xFF8B5CF6).withOpacity(0.8),
                          ),
                          title: Text(
                            'Phone',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          subtitle: Text(
                            authProvider.phoneNumber?.isNotEmpty == true
                                ? authProvider.phoneNumber!
                                : 'Not set',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Settings section
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8B5CF6).withOpacity(0.8),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildSettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy',
                        subtitle: 'Control who can see your info',
                        onTap: () => Navigator.pushNamed(context, '/privacy_settings'),
                      ),

                      _buildSettingsTile(
                        icon: Icons.security_outlined,
                        title: 'Security',
                        subtitle: 'Passcode and biometric lock',
                        onTap: () => Navigator.pushNamed(context, '/security'),
                      ),

                      _buildSettingsTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Message tones and alerts',
                        onTap: () => Navigator.pushNamed(context, '/notifications_settings'),
                      ),

                      const SizedBox(height: 32),

                      // Danger zone
                      Text(
                        'Danger Zone',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.withOpacity(0.8),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildDangerTile(
                        icon: Icons.delete_outline,
                        title: 'Delete Account',
                        subtitle: 'Permanently delete your account and all your data',
                        onTap: () => _showDeleteAccountDialog(context),
                      ),

                      _buildDangerTile(
                        icon: Icons.logout,
                        title: 'Sign Out',
                        onTap: () => _showSignOutDialog(context),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// NULL-SAFE avatar builder — no more object-not-found errors
  Widget _buildAvatar(String? photoUrl) {
    // If no photo URL, show default avatar with gradient
    if (photoUrl == null || photoUrl.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.person,
            size: 50,
            color: Colors.white54,
          ),
        ),
      );
    }

    // Try to load the image, fallback to default on error
    return ClipOval(
      child: Image.network(
        photoUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFF1a103c),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // On error (object-not-found, broken URL, etc.), show default
          debugPrint('Avatar load error: $error');
          return Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.person,
                size: 50,
                color: Colors.white54,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: child,
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDangerTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.red, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will need to sign in again.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'This will permanently delete your account and all your data. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
              final success = await authProvider.deleteAccount();
              if (context.mounted) {
                if (success) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(authProvider.error ?? 'Deletion failed')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
