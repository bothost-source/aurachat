import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../themes/app_theme.dart';
import '../../providers/bot_provider.dart';

// ============================================
// BOT TOKEN SERVICE (Built-in, no separate file needed)
// ============================================
class BotTokenService {
  static String generateToken(String botUsername) {
    final random = Random.secure();
    final numbers = List.generate(10, (_) => random.nextInt(10)).join();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
    final secret = List.generate(35, (_) => chars[random.nextInt(chars.length)]).join();
    return '$numbers:$secret';
  }

  static Future<void> saveToken(String botId, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bot_token_$botId', token);
    final allTokens = prefs.getStringList('all_bot_tokens') ?? [];
    if (!allTokens.contains(botId)) {
      allTokens.add(botId);
      await prefs.setStringList('all_bot_tokens', allTokens);
    }
  }
}

// ============================================
// AI SERVICE (Built-in, no separate file needed)
// ============================================
class AIService {
  static String? _apiKey;
  static void setApiKey(String key) => _apiKey = key;
  static bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  static Future<String> sendMessage(String message) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return '⚠️ Please add your API key in Settings > AI Studio or below';
    }
    try {
      return await _sendToGemini(message);
    } catch (e) {
      return 'Error: $e';
    }
  }

  static Future<String> _sendToGemini(String message) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_apiKey'
    );
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{'parts': [{'text': message}]}]
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'];
    } else {
      return 'Error ${response.statusCode}: ${response.body}';
    }
  }
}

// ============================================
// BOT COMMAND MODEL (Built-in, no separate file needed)
// ============================================
class BotCommand {
  final String command;
  final String description;
  final String? response;
  BotCommand({required this.command, required this.description, this.response});
}

final List<BotCommand> defaultBotCommands = [
  BotCommand(command: '/start', description: 'Start using the bot', response: 'Welcome! I am your AI assistant. How can I help you today?'),
  BotCommand(command: '/help', description: 'Get help and instructions', response: 'Available commands:\n/start - Start bot\n/help - Show help\n/settings - Bot settings'),
  BotCommand(command: '/settings', description: 'Configure bot settings', response: 'Bot settings:\n- AI Model: GPT-4o\n- Language: English\n- Response style: Friendly'),
];

// ============================================
// MAIN BOT CREATOR SCREEN
// ============================================
class BotCreatorScreen extends StatefulWidget {
  const BotCreatorScreen({super.key});

  @override
  State<BotCreatorScreen> createState() => _BotCreatorScreenState();
}

class _BotCreatorScreenState extends State<BotCreatorScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _aboutController = TextEditingController();
  
  // ============================================
  // API KEY CONTROLLER - THIS IS WHERE THE API KEY GOES
  // Users paste their key here, or you can hardcode it for testing
  // ============================================
  final _apiKeyController = TextEditingController(text: 'AQ.Ab8RN6JBqWi1X3W9UsCpBBdL-0aTW7v3ZPfylD-wHqgaNzKz0Q');
  
  bool _aiPowered = false;
  String _selectedModel = 'Gemini Pro';
  bool _isLoading = false;
  bool _showApiKey = false;

  final List<Map<String, String>> _aiModels = [
    {'name': 'Gemini Pro', 'provider': 'Google', 'free': 'true'},
    {'name': 'GPT-4o', 'provider': 'OpenAI', 'free': 'false'},
    {'name': 'GPT-4o Mini', 'provider': 'OpenAI', 'free': 'false'},
    {'name': 'Claude 3.5', 'provider': 'Anthropic', 'free': 'false'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedApiKey();
  }

  // Load saved API key from device storage
  Future<void> _loadSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('ai_api_key');
    if (savedKey != null) {
      _apiKeyController.text = savedKey;
      AIService.setApiKey(savedKey);
    }
  }

  // Save API key to device storage
  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_api_key', key);
    AIService.setApiKey(key);
  }

  // ============================================
  // CREATE BOT - GENERATES TOKEN LIKE BOTFATHER
  // ============================================
  void _createBot() async {
    if (_nameController.text.isEmpty || _usernameController.text.isEmpty) return;

    // Save API key if provided
    if (_apiKeyController.text.isNotEmpty) {
      await _saveApiKey(_apiKeyController.text);
    }

    setState(() => _isLoading = true);

    final botId = DateTime.now().millisecondsSinceEpoch.toString();

    await context.read<BotProvider>().createBot(
      name: _nameController.text,
      username: _usernameController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      about: _aboutController.text.isEmpty ? null : _aboutController.text,
      aiPowered: _aiPowered,
      aiModel: _aiPowered ? _selectedModel : null,
      apiKey: _apiKeyController.text.isEmpty ? null : _apiKeyController.text,
    );

    // GENERATE BOT TOKEN (Like BotFather!)
    final token = BotTokenService.generateToken(_usernameController.text);
    await BotTokenService.saveToken(botId, token);

    setState(() => _isLoading = false);

    if (mounted) {
      _showBotTokenDialog(token, _usernameController.text);
    }
  }

  // Show token dialog like BotFather
  void _showBotTokenDialog(String token, String username) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgModal,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.primaryGreen),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Bot Created!', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Done! Congratulations on your new bot. You will find it at @$username.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Use this token to access the HTTP API:',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      token,
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppTheme.primaryGreen, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: token));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Token copied to clipboard!'), backgroundColor: AppTheme.success),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: AppTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keep your token secure! Anyone with this token can control your bot!',
                      style: TextStyle(color: AppTheme.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: const Text('Create Bot'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.smart_toy, size: 48, color: Colors.white),
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField('Bot Name', _nameController, 'What users will see'),
            const SizedBox(height: 16),
            _buildTextField('Username', _usernameController, 'Unique @username for your bot', prefix: const Text('@', style: TextStyle(color: AppTheme.textTertiary, fontSize: 16))),
            const SizedBox(height: 16),
            _buildTextField('Description', _descriptionController, 'Short description (max 120 chars)', maxLines: 2),
            const SizedBox(height: 16),
            _buildTextField('About', _aboutController, 'Detailed information about your bot', maxLines: 4),
            const SizedBox(height: 24),

            // ============================================
            // AI SECTION WITH API KEY INPUT
            // ============================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _aiPowered ? AppTheme.primaryGreen : AppTheme.divider),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('AI-Powered Bot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    subtitle: const Text('Enable AI intelligence for your bot', style: TextStyle(fontSize: 13, color: AppTheme.textTertiary)),
                    value: _aiPowered,
                    onChanged: (v) => setState(() => _aiPowered = v),
                    activeColor: AppTheme.primaryGreen,
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    ),
                  ),
                  if (_aiPowered) ...[
                    const Divider(color: AppTheme.divider),
                    const SizedBox(height: 8),
                    const Text('Select AI Model', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: _aiModels.map((model) {
                        final isSelected = _selectedModel == model['name'];
                        final isFree = model['free'] == 'true';
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(model['name']!),
                              if (isFree) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('FREE', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedModel = model['name']!);
                          },
                          selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),

                    // ============================================
                    // API KEY INPUT FIELD - PUT YOUR KEY HERE!
                    // ============================================
                    const SizedBox(height: 16),
                    const Divider(color: AppTheme.divider),
                    const SizedBox(height: 16),
                    
                    // Label
                    Row(
                      children: [
                        Icon(Icons.key, color: AppTheme.primaryGreen, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'AI API Key',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Description
                    Text(
                      'Enter your API key to enable AI responses. Get a FREE key from Google AI Studio.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    
                    // ============================================
                    // THIS IS THE API KEY INPUT FIELD
                    // Users paste their API key here
                    // ============================================
                    TextField(
                      controller: _apiKeyController,
                      obscureText: !_showApiKey,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        // Hint text shows where to put the key
                        hintText: 'Paste your API key here (e.g., AIzaSyC...)',
                        hintStyle: TextStyle(color: AppTheme.textTertiary),
                        filled: true,
                        fillColor: AppTheme.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                        ),
                        // Eye icon to show/hide key
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showApiKey ? Icons.visibility_off : Icons.visibility,
                            color: AppTheme.textTertiary,
                          ),
                          onPressed: () => setState(() => _showApiKey = !_showApiKey),
                        ),
                        // Key icon at start
                        prefixIcon: const Icon(Icons.vpn_key, color: AppTheme.textTertiary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Help link
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppTheme.bgModal,
                            title: const Text('How to Get API Key', style: TextStyle(color: AppTheme.textPrimary)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStep('1', 'Go to aistudio.google.com'),
                                _buildStep('2', 'Sign in with Google'),
                                _buildStep('3', 'Click "Get API Key"'),
                                _buildStep('4', 'Copy and paste it above'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Got it', style: TextStyle(color: AppTheme.primaryGreen)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text(
                        'Where do I get an API key?',
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createBot,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.bgElevated,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Bot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
            child: Center(
              child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {int maxLines = 1, Widget? prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textTertiary),
            prefixIcon: prefix,
            filled: true,
            fillColor: AppTheme.bgInput,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _descriptionController.dispose();
    _aboutController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }
}
