import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

class AIStudioScreen extends StatefulWidget {
  const AIStudioScreen({super.key});

  @override
  State<<AIStudioScreen> createState() => _AIStudioScreenState();
}

class _AIStudioScreenState extends State<<AIStudioScreen> {
  int _selectedTool = 0;
  final _chatController = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [];
  bool _isTyping = false;

  final List<Map<String, dynamic>> _tools = [
    {'name': 'AI Chatbot', 'icon': Icons.chat_bubble, 'color': AppTheme.primaryGreen, 'desc': 'Conversational AI assistant'},
    {'name': 'AI Writer', 'icon': Icons.edit, 'color': AppTheme.accentBlue, 'desc': 'Generate content & copy'},
    {'name': 'AI Image', 'icon': Icons.image, 'color': AppTheme.accentPurple, 'desc': 'Create AI art & images'},
    {'name': 'AI Voice', 'icon': Icons.mic, 'color': AppTheme.accentPink, 'desc': 'Text-to-speech & voice'},
  ];

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty) return;
    setState(() {
      _chatMessages.add(<String, dynamic>{'role': 'user', 'content': _chatController.text});
      _isTyping = true;
    });
    _chatController.clear();

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isTyping = false;
        _chatMessages.add(<String, dynamic>{
          'role': 'ai',
          'content': "I'm your ${_tools[_selectedTool]['name']}. I can help you with that request. This is a demo response - in production, this would connect to GPT-4o or your chosen AI model.",
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: const Text('AI Studio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppTheme.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Tool Selector
          Container(
            height: 110,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _tools.length,
              itemBuilder: (context, index) {
                final tool = _tools[index];
                final isSelected = _selectedTool == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTool = index),
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? tool['color'].withOpacity(0.15) : AppTheme.bgSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? tool['color'] : AppTheme.divider,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tool['icon'], color: isSelected ? tool['color'] : AppTheme.textTertiary, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          tool['name'],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? tool['color'] : AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Tool Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(_tools[_selectedTool]['icon'], color: _tools[_selectedTool]['color'], size: 18),
                const SizedBox(width: 8),
                Text(
                  _tools[_selectedTool]['desc'],
                  style: TextStyle(fontSize: 13, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),

          // Chat Area
          Expanded(
            child: _chatMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: AppGradients.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _tools[_selectedTool]['name'],
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation with AI',
                          style: TextStyle(fontSize: 14, color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _chatMessages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                          decoration: BoxDecoration(
                            color: isUser ? AppTheme.sentMessage : AppTheme.bgSecondary,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 16),
                            ),
                          ),
                          child: Text(
                            msg['content'],
                            style: TextStyle(fontSize: 15, color: isUser ? AppTheme.textPrimary : AppTheme.textSecondary, height: 1.5),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Typing Indicator
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSecondary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDot(0),
                        _buildDot(1),
                        _buildDot(2),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgSecondary,
              border: Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bgInput,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _chatController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Ask ${_tools[_selectedTool]['name']}...',
                          hintStyle: TextStyle(color: AppTheme.textTertiary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: AppTheme.textTertiary,
        shape: BoxShape.circle,
      ),
    );
  }
}
