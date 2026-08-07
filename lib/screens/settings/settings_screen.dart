import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../utils/verified_badge.dart';

// ─── YOUR CLOUDINARY CONFIG ────────────────────────────────────────
const String _cloudName = 'dn2mwp1lc';
const String _uploadPreset = 'aura_chat';
// ───────────────────────────────────────────────────────────────────

class AppLocalizations {
  static String currentLanguage = 'en';

  static final Map<String, Map<String, String>> _translations = {
    'en': {
      'settings': 'Settings',
      'account': 'Account',
      'security_change_number': 'Security, change number',
      'privacy': 'Privacy',
      'block_contacts': 'Block contacts, disappearing messages',
      'avatar': 'Avatar',
      'create_edit_photo': 'Create, edit, profile photo',
      'chats': 'Chats',
      'theme_wallpapers': 'Theme, wallpapers, chat history',
      'notifications': 'Notifications',
      'message_group_call_tones': 'Message, group & call tones',
      'storage_and_data': 'Storage and Data',
      'network_usage': 'Network usage, auto-download',
      'app_language': 'App Language',
      'english_default': 'English (device default)',
      'help': 'Help',
      'help_center': 'Help center, contact us, privacy policy',
      'invite_friends': 'Invite Friends',
      'log_out': 'Log Out',
      'version': 'AURA Chat v1.0.0',
      'select_language': 'Select Language',
      'cancel': 'Cancel',
    },
    'es': {
      'settings': 'Configuración',
      'account': 'Cuenta',
      'security_change_number': 'Seguridad, cambiar número',
      'privacy': 'Privacidad',
      'block_contacts': 'Bloquear contactos, mensajes temporales',
      'avatar': 'Avatar',
      'create_edit_photo': 'Crear, editar, foto de perfil',
      'chats': 'Chats',
      'theme_wallpapers': 'Tema, fondos, historial',
      'notifications': 'Notificaciones',
      'message_group_call_tones': 'Tono de mensajes, grupos y llamadas',
      'storage_and_data': 'Almacenamiento y Datos',
      'network_usage': 'Uso de red, descarga automática',
      'app_language': 'Idioma',
      'english_default': 'Español',
      'help': 'Ayuda',
      'help_center': 'Centro de ayuda, contacto, política',
      'invite_friends': 'Invitar Amigos',
      'log_out': 'Cerrar Sesión',
      'version': 'AURA Chat v1.0.0',
      'select_language': 'Seleccionar Idioma',
      'cancel': 'Cancelar',
    },
    'fr': {
      'settings': 'Paramètres',
      'account': 'Compte',
      'security_change_number': 'Sécurité, changer numéro',
      'privacy': 'Confidentialité',
      'block_contacts': 'Bloquer contacts, messages éphémères',
      'avatar': 'Avatar',
      'create_edit_photo': 'Créer, modifier, photo de profil',
      'chats': 'Discussions',
      'theme_wallpapers': 'Thème, fonds, historique',
      'notifications': 'Notifications',
      'message_group_call_tones': 'Sonneries messages, groupes, appels',
      'storage_and_data': 'Stockage et Données',
      'network_usage': 'Usage réseau, téléchargement auto',
      'app_language': 'Langue',
      'english_default': 'Français',
      'help': 'Aide',
      'help_center': 'Centre aide, contact, politique',
      'invite_friends': 'Inviter des Amis',
      'log_out': 'Déconnexion',
      'version': 'AURA Chat v1.0.0',
      'select_language': 'Choisir la Langue',
      'cancel': 'Annuler',
    },
    'ha': {
      'settings': 'Saituna',
      'account': 'Asusu',
      'security_change_number': 'Tsaro, canza lamba',
      'privacy': 'Sirri',
      'block_contacts': 'Toshe lambobi, saƙonnin da suke ɓacewa',
      'avatar': 'Hoton fuska',
      'create_edit_photo': 'Ƙirƙira, gyara, hoton bayani',
      'chats': 'Sadarwa',
      'theme_wallpapers': 'Jigo, fentin fuska, tarihi',
      'notifications': 'Sanarwa',
      'message_group_call_tones': 'Sautin saƙo, ƙungiya & kira',
      'storage_and_data': 'Majiya da Bayanai',
      'network_usage': 'Amfani da hanyar sadarwa, sauke kai tsaye',
      'app_language': 'Yaren App',
      'english_default': 'Hausa',
      'help': 'Taimako',
      'help_center': 'Cibiyar taimako, tuntuɓa, manufofi',
      'invite_friends': 'Gayyato Abokai',
      'log_out': 'Fita',
      'version': 'AURA Chat v1.0.0',
      'select_language': 'Zaɓi Harshe',
      'cancel': 'Soke',
    },
    'yo': {
      'settings': 'Ètò',
      'account': 'Àkáòwò',
      'security_change_number': 'Ààbò, yí nọ́mbà padà',
      'privacy': 'Àṣírí',
      'block_contacts': 'Dínà àwọn olùbáaṣepọ̀, àwọn ìròyìn tó ń lọ',
      'avatar': 'Àwòrán',
      'create_edit_photo': 'Ṣẹ̀dá, ṣàtúnṣe, àwòrán prófáìlì',
      'chats': 'Ìtàkurọ̀sọ̀',
      'theme_wallpapers': 'Àkọlé, àwòrán bàckgráùnd, ìtàn',
      'notifications': 'Àlàrtì',
      'message_group_call_tones': 'Ohùn ìròyìn, ẹgbẹ́ & ìpè',
      'storage_and_data': 'Ibi ipamọ̀ àti Dátà',
      'network_usage': 'Lò nẹ́twọ́kì, ìgbàsílẹ̀ fúnrarẹ̀',
      'app_language': 'Èdè App',
      'english_default': 'Yorùbá',
      'help': 'Ìrànlọ́wọ́',
      'help_center': 'Ilé ìrànlọ́wọ́, àbọ̀, òfin àṣírí',
      'invite_friends': 'Pè Àwọn Ọ̀rẹ́',
      'log_out': 'Jáde',
      'version': 'AURA Chat v1.0.0',
      'select_language': 'Yan Èdè',
      'cancel': 'Fagilé',
    },
    'ig': {
      'settings': 'Ntọala',
      'account': 'Akaụntụ',
      'security_change_number': 'Nchekwa, ịgbanwe nọmba',
      'privacy': 'Nzuzo',
      'block_contacts': 'Gbochie ndị kọntaktị, ozi na-efu',
      'avatar': 'Foto',
      'create_edit_photo': 'Kepụta, dezie, foto profaịlụ',
      'chats': 'Mkparịta ụka',
      'theme_wallpapers': 'Isiokwu, ihe osise, akụkọ',
      'notifications': 'Nziọkwà',
      'message_group_call_tones': 'Ọkwa ozi, òtù & oku',
      'storage_and_data': 'Nchekwa na Data',
      'network_usage': 'Iji netwọk, ibudata onwe',
      'app_language': 'Asụsụ App',
      'english_default': 'Igbo',
      'help': 'Enyemaka',
      'help_center': 'Ụlọ enyemaka, kọntaktị, iwu nzuzo',
      'invite_friends': 'Kpọọ Ndị Enyi',
      'log_out': 'Pụọ',
      'version': 'AURA Chat v1.0.0',
      'select_language': 'Họrọ Asụsụ',
      'cancel': 'Kagbuo',
    },
  };

  static String get(String key) {
    return _translations[currentLanguage]?[key] ??
           _translations['en']?[key] ??
           key;
  }

  static List<Map<String, String>> get supportedLanguages => [
    {'code': 'en', 'name': 'English'},
    {'code': 'es', 'name': 'Español'},
    {'code': 'fr', 'name': 'Français'},
    {'code': 'ha', 'name': 'Hausa'},
    {'code': 'yo', 'name': 'Yorùbá'},
    {'code': 'ig', 'name': 'Igbo'},
  ];
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  File? _newProfileImage;
  bool _isUploading = false;

  Future<void> _pickNewProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (picked == null) return;

    setState(() {
      _newProfileImage = File(picked.path);
      _isUploading = true;
    });

    await _uploadProfileImage();
  }

  /// UPLOAD TO CLOUDINARY
  Future<void> _uploadProfileImage() async {
    if (_newProfileImage == null) return;

    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (userId == null) return;

      final fileBytes = await _newProfileImage!.readAsBytes();
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // ─── Cloudinary Upload ───────────────────────────────────────
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['public_id'] = 'aura_profiles/$userId/$fileName'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName,
          ),
        );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = jsonDecode(responseData);

      if (response.statusCode != 200) {
        throw Exception('Cloudinary error: ${jsonData['error']?['message'] ?? responseData}');
      }

      final publicUrl = jsonData['secure_url'] as String;
      // ─────────────────────────────────────────────────────────────

           // Save to Firestore
      // ✅ FIX: Use .set() with merge instead of .update()
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(userId).set({
        'avatar_url': publicUrl,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update local provider
      await authProvider.updateProfile(photoUrl: publicUrl);

      setState(() => _isUploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.get('avatar')} updated!'),
            backgroundColor: const Color(0xFF8B5CF6),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint('Cloudinary upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.get('select_language'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...AppLocalizations.supportedLanguages.map((lang) {
              final isSelected = AppLocalizations.currentLanguage == lang['code'];
              return ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF8B5CF6).withOpacity(0.3)
                        : Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF8B5CF6), size: 16)
                      : null,
                ),
                title: Text(
                  lang['name']!,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF8B5CF6) : Colors.white,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                onTap: () {
                  setState(() {
                    AppLocalizations.currentLanguage = lang['code']!;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _logOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: Text(
          AppLocalizations.get('log_out'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.get('cancel'),
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(AppLocalizations.get('log_out')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      await authProvider.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuraAuthProvider>(context);
    final username = authProvider.userName ?? 'Unknown';
    final displayName = authProvider.displayName ?? username;
    final phone = authProvider.phoneNumber ?? '';
    final avatar = authProvider.userPhotoUrl;
    final userVerified = isVerified(phone);

    final currentLang = AppLocalizations.supportedLanguages.firstWhere(
      (l) => l['code'] == AppLocalizations.currentLanguage,
      orElse: () => {'code': 'en', 'name': 'English'},
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF0A0A0F),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              AppLocalizations.get('settings'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF8B5CF6).withOpacity(0.2),
                      const Color(0xFF06B6D4).withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 60),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _isUploading ? null : _pickNewProfileImage,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: _buildAvatar(avatar, _newProfileImage),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF0A0A0F),
                                          width: 2,
                                        ),
                                      ),
                                      child: _isUploading
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  VerifiedUsername(
                                    username: displayName,
                                    phoneNumber: phone,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    badgeSize: 16,
                                    spacing: 6,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '@$username',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    phone,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (userVerified)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1DA1F2).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF1DA1F2).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const VerifiedBadge(size: 10, showTooltip: false),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Verified',
                                              style: TextStyle(
                                                fontSize: 10,
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
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: const Icon(
                                Icons.qr_code,
                                color: Color(0xFF8B5CF6),
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionTitle(AppLocalizations.get('account')),
                _buildSettingTile(
                  icon: Icons.key_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: AppLocalizations.get('account'),
                  subtitle: AppLocalizations.get('security_change_number'),
                  onTap: () => Navigator.pushNamed(context, '/account_settings'),
                ),
                _buildSettingTile(
                  icon: Icons.lock_outline,
                  iconColor: const Color(0xFF06B6D4),
                  title: AppLocalizations.get('privacy'),
                  subtitle: AppLocalizations.get('block_contacts'),
                  onTap: () => Navigator.pushNamed(context, '/privacy_settings'),
                ),
                _buildSettingTile(
                  icon: Icons.face,
                  iconColor: const Color(0xFFEC4899),
                  title: AppLocalizations.get('avatar'),
                  subtitle: AppLocalizations.get('create_edit_photo'),
                  onTap: _pickNewProfileImage,
                ),
                _buildSectionTitle(AppLocalizations.get('preferences')),
                _buildSettingTile(
                  icon: Icons.chat_bubble_outline,
                  iconColor: const Color(0xFF8B5CF6),
                  title: AppLocalizations.get('chats'),
                  subtitle: AppLocalizations.get('theme_wallpapers'),
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                ),
                _buildSettingTile(
                  icon: Icons.notifications_none,
                  iconColor: const Color(0xFF06B6D4),
                  title: AppLocalizations.get('notifications'),
                  subtitle: AppLocalizations.get('message_group_call_tones'),
                  onTap: () => Navigator.pushNamed(context, '/notifications_settings'),
                ),
                _buildSettingTile(
                  icon: Icons.storage,
                  iconColor: const Color(0xFFF59E0B),
                  title: AppLocalizations.get('storage_and_data'),
                  subtitle: AppLocalizations.get('network_usage'),
                  onTap: () => Navigator.pushNamed(context, '/data_storage'),
                ),
                _buildSettingTile(
                  icon: Icons.language,
                  iconColor: const Color(0xFF10B981),
                  title: AppLocalizations.get('app_language'),
                  subtitle: currentLang['name']!,
                  onTap: _showLanguagePicker,
                ),
                _buildSectionTitle(AppLocalizations.get('help')),
                _buildSettingTile(
                  icon: Icons.help_outline,
                  iconColor: const Color(0xFF8B5CF6),
                  title: AppLocalizations.get('help'),
                  subtitle: AppLocalizations.get('help_center'),
                  onTap: () => Navigator.pushNamed(context, '/help'),
                ),
                const SizedBox(height: 16),
                _buildSettingTile(
                  icon: Icons.people_outline,
                  iconColor: const Color(0xFF06B6D4),
                  title: AppLocalizations.get('invite_friends'),
                  onTap: () => Navigator.pushNamed(context, '/invite_friends'),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.logout, color: Colors.red, size: 22),
                    ),
                    title: Text(
                      AppLocalizations.get('log_out'),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: _logOut,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    AppLocalizations.get('version'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, File? localFile) {
    if (localFile != null) {
      return ClipOval(
        child: Image.file(
          localFile,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
        ),
      );
    }

    if (avatarUrl == null || avatarUrl.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.person, color: Colors.white70, size: 32),
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFF1a103c),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Settings avatar error: $error');
          return Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
              ),
            ),
            child: const Center(
              child: Icon(Icons.person, color: Colors.white70, size: 32),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8B5CF6).withOpacity(0.8),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 13,
                  ),
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.white.withOpacity(0.15),
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}
