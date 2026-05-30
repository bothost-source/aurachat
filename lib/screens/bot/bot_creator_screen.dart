import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../themes/app_theme.dart';
import '../../providers/bot_provider.dart';
import '../../services/ai_service.dart';

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
  final _apiKeyController = TextEditingController(); // NEW
  bool _aiPowered = false;
  String _selectedModel = 'Gemini Pro'; // Changed default to free option
  bool _isLoading = false;
  bool _showApiKey = false; // NEW

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

  // NEW: Load saved API key
  Future<void> _loadSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('ai_api_key');
    if (savedKey != null) {
      _apiKeyController.text = savedKey;
      AIService.setApiKey(savedKey);
    }
  }

  // NEW: Save API key
  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_api_key', key);
    AIService.setApiKey(key);
  }

  void _createBot() async {
    if (_nameController.text.isEmpty || _usernameController.text.isEmpty) return;
    
    // NEW: Save API key if provided
    if (_apiKeyController.text.isNotEmpty) {
      await _saveApiKey(_apiKeyController.text);
    }
    
    setState(() => _isLoading = true);
    await context.read<BotProvider>().createBot(
      name: _nameController.text,
      username: _usernameController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      about: _aboutController.text.isEmpty ? null : _aboutController.text,
      aiPowered: _aiPowered,
      aiModel: _aiPowered ? _selectedModel : null,
      apiKey: _apiKeyController.text.isEmpty ? null : _apiKeyController.text, // NEW
    );
    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bot created successfully!'), backgroundColor: AppTheme.success),
      );
    }
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

            // AI Toggle
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
                    
                    // NEW: API Key Input
                    const SizedBox(height: 16),
                    const Divider(color: AppTheme.divider),
                    const SizedBox(height: 16),
                    const Text(
                      'API Key (Required for AI)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: !_showApiKey,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Paste your API key here',
                        hintStyle: TextStyle(color: AppTheme.textTertiary),
                        filled: true,
                        fillColor: AppTheme.bgInput,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showApiKey ? Icons.visibility_off : Icons.visibility,
                            color: AppTheme.textTertiary,
                          ),
                          onPressed: () => setState(() => _showApiKey = !_showApiKey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        // Show help dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppTheme.bgModal,
                            title: const Text('How to get API Key', style: TextStyle(color: AppTheme.textPrimary)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildApiHelpItem('1. Gemini (FREE)', 'Go to aistudio.google.com', 'Get API Key'),
                                const SizedBox(height: 12),
                                _buildApiHelpItem('2. OpenAI', 'Go to platform.openai.com', 'Create API Key'),
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

  Widget _buildApiHelpItem(String title, String url, String action) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        Text(url, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Text(action, style: TextStyle(color: AppTheme.primaryGreen, fontSize: 12)),
      ],
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
